import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/place_pin.dart';
import '../core/sync_state.dart';

import '../features/calendar/calendar_state.dart';
import '../features/timeline/data/demo_repository.dart';
import '../features/timeline/domain/models.dart';
import 'online_backend.dart';
import 'edit_outbox.dart';

DateTime? firebaseDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  if (value is Map) {
    final seconds = value['_seconds'] ?? value['seconds'];
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).round(),
        isUtc: true,
      );
    }
  }
  return null;
}

Task firebaseTask(String spaceId, String id, Map<String, dynamic> data) => Task(
  id: id,
  spaceId: spaceId,
  title: data['title'] as String? ?? 'Task',
  day:
      DateTime.tryParse(data['scheduledLocalDate'] as String? ?? '') ??
      dateOnly(firebaseDate(data['createdAt'])?.toLocal() ?? DateTime.now()),
  creatorId: data['creatorUid'] as String? ?? '',
  ownerId: data['ownerUid'] as String?,
  requestedId: data['requestedUid'] as String?,
  offeredId: data['offeredUid'] as String?,
  status: Responsibility.values.firstWhere(
    (v) => v.name == data['status'],
    orElse: () => Responsibility.unclaimed,
  ),
  notes: data['notes'] as String? ?? '',
  place: data['place'] as String?,
  pin: PlacePin.fromMap(data['pin']),
  activity: List<String>.from(data['activity'] as List? ?? []),
  completedAt: firebaseDate(data['completedAt'])?.toLocal(),
  completedLocalDay: DateTime.tryParse(
    data['completedLocalDate'] as String? ?? '',
  ),
);

/// Adapts authenticated Firestore data to the original Soft Pop screen models.
/// Spark rules enforce membership, ownership, and allowed transitions.
class FirebaseTimelineRepository extends TimelineRepository {
  FirebaseTimelineRepository(this.backend, this.currentUserId, this.outbox) {
    outbox.addListener(_notify);
  }
  final OnlineBackend backend;
  final EditOutbox outbox;
  @override
  final String currentUserId;
  final _updates = StreamController<void>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _spaceSubscriptions = <String, List<StreamSubscription<dynamic>>>{};
  final _refs = <String, Map<String, dynamic>>{};
  final _members = <String, List<Member>>{};
  final _active = <String, List<Task>>{};
  final _done = <String, List<Task>>{};
  final _moods = <String, Map<String, CheckIn>>{};
  final _plans = <String, List<CalendarPlan>>{};
  final _today = <String, DateTime>{};
  final _historyEpoch = <String, int>{};
  final _operationIds = <String, String>{};
  final _acknowledgedActions = <String, Map<String, dynamic>>{};
  final _lastHistoryRefresh = <String, DateTime>{};
  bool loading = true;
  String? error;
  @override
  String? get syncError => error;
  bool _plus = false, _closed = false;
  bool _rawPlus = false, _isFounder = false;
  DateTime? _subscriptionExpiry;
  Timer? _timer;
  DateTime _historyDay = dateOnly(DateTime.now().toUtc());
  @override
  bool get isShared => true;
  @override
  bool get isPlus => _plus;
  @override
  Stream<void> get changes => _updates.stream;
  void _notify() {
    if (!_closed) _updates.add(null);
  }

  @override
  List<Space> get spaces => [
    for (final entry in _refs.entries)
      if (_members[entry.key]?.any((m) => m.id == currentUserId) ?? false)
        Space(
          entry.key,
          entry.value['name'] as String? ?? 'Your space',
          entry.value['kind'] as String? ?? 'Space',
          _members[entry.key]!,
          currentUserId: currentUserId,
        ),
  ];
  @override
  List<Task> get tasks => [
    for (final space in spaces) ...[
      for (final task in _active[space.id] ?? <Task>[])
        _withActiveAssignment(task, space),
      for (final item in outbox.items.where(
        (i) => i['spaceId'] == space.id && i['kind'] == 'taskCreate',
      ))
        if (!(_active[space.id] ?? []).any((t) => t.id == item['id']))
          _draftTask(item),
      ..._done[space.id] ?? [],
    ],
  ];
  Task _draftTask(Map<String, Object?> item) {
    final payload = Map<String, dynamic>.from(item['payload'] as Map);
    return Task(
      id: item['id'] as String,
      spaceId: item['spaceId'] as String,
      title: payload['title'] as String,
      day:
          DateTime.tryParse(payload['scheduledLocalDate'] as String? ?? '') ??
          dateOnly(DateTime.now()),
      creatorId: currentUserId,
      requestedId: payload['requestedUid'] as String?,
      status: payload['requestedUid'] == null
          ? Responsibility.unclaimed
          : Responsibility.requested,
      pin: PlacePin.fromMap(payload['pin']),
      syncState: item['status'] == 'failed'
          ? SyncState.failed
          : SyncState.pending,
    );
  }

  // A concurrent assignment may land immediately before a removal commits.
  // Rules permit active members to claim such orphaned tasks; expose that action.
  Task _withActiveAssignment(Task task, Space space) {
    final members = space.members.map((member) => member.id).toSet();
    if ((task.ownerId != null && !members.contains(task.ownerId)) ||
        (task.requestedId != null && !members.contains(task.requestedId))) {
      return task.transition(
        status: Responsibility.unclaimed,
        entry: 'Assignment released: member has left this space.',
      );
    }
    return task;
  }

  List<CalendarPlan> get plans => [
    for (final s in spaces) ...[
      for (final plan in _plans[s.id] ?? <CalendarPlan>[]) _draftPlanFor(plan),
      for (final item in outbox.items.where(
        (i) => i['spaceId'] == s.id && i['kind'] == 'planSave',
      ))
        if (!(_plans[s.id] ?? []).any(
          (p) => p.id == (item['payload'] as Map)['planId'],
        ))
          _draftPlan(item),
    ],
  ];
  CalendarPlan _draftPlanFor(CalendarPlan remote) {
    for (final item in outbox.items) {
      if (item['kind'] == 'planSave' &&
          item['spaceId'] == remote.spaceId &&
          (item['payload'] as Map)['planId'] == remote.id) {
        return _draftPlan(item);
      }
      if (item['kind'] == 'planRemove' &&
          item['spaceId'] == remote.spaceId &&
          (item['payload'] as Map)['planId'] == remote.id) {
        return CalendarPlan(
          id: remote.id,
          spaceId: remote.spaceId,
          ownerId: remote.ownerId,
          title: remote.title,
          start: remote.start,
          end: remote.end,
          allDay: remote.allDay,
          note: remote.note,
          participants: remote.participants,
          pin: remote.pin,
          reminder: remote.reminder,
          revision: remote.revision,
          syncState: item['status'] == 'failed'
              ? SyncState.failed
              : SyncState.pending,
          pendingRemoval: true,
        );
      }
    }
    return remote;
  }

  CalendarPlan _draftPlan(Map<String, Object?> item) {
    final p = Map<String, dynamic>.from(item['payload'] as Map);
    final allDay = p['allDay'] == true;
    DateTime date(int millis) {
      final d = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      return allDay ? DateTime(d.year, d.month, d.day) : d;
    }

    return CalendarPlan(
      id: p['planId'] as String,
      spaceId: p['spaceId'] as String,
      ownerId: currentUserId,
      title: p['title'] as String,
      start: date(p['startMillis'] as int),
      end: date(p['endMillis'] as int),
      allDay: allDay,
      note: p['note'] as String? ?? '',
      participants: List<String>.from(p['participants'] as List? ?? []),
      pin: PlacePin.fromMap(p['pin']),
      reminder: PlanReminder.values.firstWhere(
        (r) => r.name == p['reminder'],
        orElse: () => PlanReminder.none,
      ),
      syncState: item['status'] == 'failed'
          ? SyncState.failed
          : SyncState.pending,
      revision: p['expectedRevision'] as int? ?? 0,
    );
  }

  @override
  bool canView(Task task) =>
      tasks.any((t) => t.id == task.id && t.spaceId == task.spaceId);
  @override
  DateTime todayInSpace(String spaceId) =>
      _today[spaceId] ?? super.todayInSpace(spaceId);

  void start() {
    _subscriptions.add(
      backend.account(currentUserId).listen((doc) {
        final data = doc.data();
        _rawPlus = data?['tier'] == 'plus';
        _isFounder =
            data?['founderGrant'] == true ||
            data?['entitlementSource'] == 'founder';
        final expiry = data?['subscriptionExpiresAt'];
        DateTime? expiryDate;
        if (expiry is Timestamp) {
          expiryDate = expiry.toDate();
        } else if (expiry is String) {
          expiryDate = DateTime.tryParse(expiry);
        }
        _subscriptionExpiry = expiryDate;
        final notExpired =
            expiryDate != null && expiryDate.isAfter(DateTime.now());
        final next = _rawPlus && (_isFounder || notExpired);
        if (_plus != next) {
          _plus = next;
          _done.clear();
          for (final id in _refs.keys) {
            unawaited(refreshHistory(id));
          }
        }
        _notify();
      }, onError: _failed),
    );
    _subscriptions.add(
      backend.spaces(currentUserId).listen((snapshot) {
        final ids = snapshot.docs.map((d) => d.id).toSet();
        for (final id in _refs.keys.toList()) {
          if (!ids.contains(id)) {
            _removeSpace(id, discardDrafts: !snapshot.metadata.isFromCache);
          }
        }
        for (final doc in snapshot.docs) {
          _refs[doc.id] = doc.data();
          if (!_spaceSubscriptions.containsKey(doc.id)) _watchSpace(doc.id);
        }
        loading = ids.any((id) => !_members.containsKey(id));
        error = null;
        _notify();
      }, onError: _failed),
    );
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final today = dateOnly(DateTime.now().toUtc());
      if (today != _historyDay) {
        _historyDay = today;
        for (final id in _refs.keys) {
          unawaited(refreshHistory(id));
        }
      }
      if (_rawPlus && !_isFounder && _subscriptionExpiry != null) {
        final notExpired = _subscriptionExpiry!.isAfter(DateTime.now());
        if (_plus != notExpired) {
          _plus = notExpired;
          _done.clear();
          for (final id in _refs.keys) {
            unawaited(refreshHistory(id));
          }
        }
      }
      _notify();
    });
  }

  void _failed(Object failure) {
    error = 'Could not load your shared space. Check your connection.';
    loading = false;
    _notify();
  }

  void _removeSpace(String id, {bool discardDrafts = false}) {
    if (discardDrafts) unawaited(outbox.discardSpace(id));
    for (final sub in _spaceSubscriptions.remove(id) ?? []) {
      unawaited(sub.cancel());
    }
    _refs.remove(id);
    _members.remove(id);
    _active.remove(id);
    _done.remove(id);
    _moods.remove(id);
    _plans.remove(id);
    _today.remove(id);
    _historyEpoch[id] = (_historyEpoch[id] ?? 0) + 1;
  }

  void _watchSpace(String id) {
    void denied(Object e) {
      // Fail closed on revoked membership, including any locally cached view.
      _members.remove(id);
      _active.remove(id);
      _done.remove(id);
      _moods.remove(id);
      _plans.remove(id);
      _failed(e);
    }

    _spaceSubscriptions[id] = [
      backend.members(id).listen((snapshot) {
        final people = snapshot.docs
            .where((d) => d.data()['status'] == 'active')
            .toList();
        people.sort(
          (a, b) => a.id == currentUserId
              ? -1
              : b.id == currentUserId
              ? 1
              : a.id.compareTo(b.id),
        );
        _members[id] = [
          for (var i = 0; i < people.length; i++)
            Member(
              people[i].id,
              people[i].data()['name'] as String? ?? 'Member',
              _initials(people[i].data()['name'] as String? ?? 'Member'),
              i % 3,
            ),
        ];
        loading = _refs.keys.any((key) => !_members.containsKey(key));
        _notify();
      }, onError: denied),
      backend.activeTasks(id).listen((snapshot) {
        error = null;
        _active[id] = [
          for (final d in snapshot.docs) firebaseTask(id, d.id, d.data()),
        ];
        for (final d in snapshot.docs) {
          if (outbox.items.any(
            (i) => i['id'] == d.id && i['kind'] == 'taskCreate',
          )) {
            unawaited(outbox.acknowledged(d.id));
          }
        }
        _notify();
        final last = _lastHistoryRefresh[id];
        final now = DateTime.now();
        if (last == null || now.difference(last) >= const Duration(seconds: 10)) {
          _lastHistoryRefresh[id] = now;
          unawaited(refreshHistory(id));
        }
      }, onError: denied),
      backend.firestore
          .collection('spaces')
          .doc(id)
          .collection('checkIns')
          .snapshots()
          .listen((snapshot) {
            _moods[id] = {
              for (final d in snapshot.docs)
                d.id: CheckIn(
                  Mood.values.firstWhere(
                    (v) => v.name == d.data()['mood'],
                    orElse: () => Mood.calm,
                  ),
                  d.data()['note'] as String? ?? '',
                  firebaseDate(d.data()['updatedAt']) ?? DateTime.now(),
                  firebaseDate(d.data()['expiresAt']) ?? DateTime.now(),
                  color: MoodColor.values.firstWhere(
                    (v) => v.name == d.data()['color'],
                    orElse: () => MoodColor.sky,
                  ),
                ),
            };
            _notify();
          }, onError: denied),
      backend.plans(id).listen((snapshot) {
        _plans[id] = [for (final d in snapshot.docs) _plan(id, d.id, d.data())];
        for (final item in outbox.items.toList()) {
          if (item['spaceId'] != id) continue;
          final payload = item['payload'] as Map;
          final planId = payload['planId'];
          if (item['kind'] == 'planSave' &&
              snapshot.docs.any(
                (d) =>
                    d.id == planId && d.data()['lastMutationId'] == item['id'],
              )) {
            unawaited(outbox.acknowledged(item['id'] as String));
          } else if (item['kind'] == 'planRemove' &&
              item['status'] == 'synced' &&
              !snapshot.docs.any((d) => d.id == planId)) {
            unawaited(outbox.acknowledged(item['id'] as String));
          }
        }
        _notify();
      }, onError: denied),
    ];
  }

  Future<void> refreshHistory(String id) async {
    final epoch = (_historyEpoch[id] ?? 0) + 1;
    _historyEpoch[id] = epoch;
    try {
      final all = <Task>[];
      String? cursor;
      do {
        final page = await backend.call('listCompletedTasks', {
          'spaceId': id,
          'cursorId': ?cursor,
        });
        if (_closed || !_refs.containsKey(id) || epoch != _historyEpoch[id]) {
          return;
        }
        for (final raw in page['tasks'] as List) {
          final data = Map<String, dynamic>.from(raw as Map);
          all.add(firebaseTask(id, data['id'] as String, data));
        }
        cursor = page['nextCursorId'] as String?;
        _today[id] =
            DateTime.tryParse(page['todayLocalDate'] as String? ?? '') ??
            dateOnly(DateTime.now());
      } while (cursor != null);
      _done[id] = all;
      error = null;
      _notify();
    } catch (e) {
      if (!_closed && epoch == _historyEpoch[id]) {
        _done.remove(id);
        _failed(e);
      }
    }
  }

  @override
  Future<Task> act(String taskId, TaskAction action, String actorId) async {
    if (actorId != currentUserId) throw StateError('Use your own account.');
    final task = tasks.firstWhere((t) => t.id == taskId);
    final operationKey = '$taskId/${action.name}';
    final operationId = _operationIds.putIfAbsent(
      operationKey,
      backend.newOperationId,
    );
    final result =
        _acknowledgedActions[operationKey] ??
        await backend.call('actOnTask', {
          'spaceId': task.spaceId,
          'taskId': taskId,
          'action': action.name,
          'operationId': operationId,
        });
    _acknowledgedActions[operationKey] = result;
    _operationIds.remove(operationKey);
    Map<String, dynamic> hydrated = result;
    if (hydrated['task'] == null) {
      try {
        hydrated = await backend.call('getTask', {
          'spaceId': task.spaceId,
          'taskId': taskId,
        });
        if (hydrated['task'] == null) {
          throw StateError('Task unavailable.');
        }
      } catch (_) {
        // The mutation is committed. Retrying this action only repeats its
        // authorized read, never the mutation or its notification/sound.
        throw DemoException(
          'Saved. Waiting for the task to refresh; retry to check.',
        );
      }
    }
    _acknowledgedActions.remove(operationKey);
    final updated = firebaseTask(
      task.spaceId,
      taskId,
      Map<String, dynamic>.from(hydrated['task'] as Map),
    );
    _active[task.spaceId]?.removeWhere((t) => t.id == taskId);
    _done[task.spaceId]?.removeWhere((t) => t.id == taskId);
    (updated.isDone ? _done : _active)
        .putIfAbsent(task.spaceId, () => [])
        .add(updated);
    _notify();
    return updated;
  }

  @override
  Future<Task> addTask(
    String spaceId,
    String title,
    DateTime day,
    bool assignToMe, {
    String? requestedUid,
    String? operationId,
    PlacePin? pin,
  }) async {
    final stableId =
        operationId ?? backend.firestore.collection('operationIds').doc().id;
    final payload = <String, Object?>{
      'spaceId': spaceId,
      'title': title,
      'scheduledLocalDate':
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
      if (requestedUid != null || assignToMe)
        'requestedUid': requestedUid ?? currentUserId,
      'operationId': stableId,
      if (pin != null) 'pin': pin.toMap(),
    };
    await outbox.add(stableId, spaceId, 'taskCreate', payload);
    return _draftTask(outbox.items.firstWhere((i) => i['id'] == stableId));
  }

  @override
  CheckIn? checkIn(String spaceId, String memberId) {
    final mood = _moods[spaceId]?[memberId];
    return mood?.isCurrent(DateTime.now()) == true ? mood : null;
  }

  @override
  Future<void> shareCheckIn(
    String spaceId,
    String memberId,
    Mood mood,
    String note, {
    MoodColor color = MoodColor.sky,
  }) async {
    if (memberId != currentUserId) throw StateError('Use your own account.');
    await backend.call('setCheckIn', {
      'spaceId': spaceId,
      'mood': mood.name,
      'color': color.name,
      'note': note,
    });
  }

  @override
  Future<void> removeCheckIn(String spaceId, String memberId) async {
    if (memberId != currentUserId) throw StateError('Use your own account.');
    await backend.call('removeCheckIn', {'spaceId': spaceId});
  }

  Future<void> dispose() async {
    _closed = true;
    outbox.removeListener(_notify);
    _timer?.cancel();
    for (final sub in [
      ..._subscriptions,
      ..._spaceSubscriptions.values.expand((s) => s),
    ]) {
      await sub.cancel();
    }
    await _updates.close();
  }
}

String _initials(String name) => name.trim().isEmpty
    ? '?'
    : name
          .trim()
          .split(RegExp(r'\s+'))
          .take(2)
          .map((s) => s[0])
          .join()
          .toUpperCase();

CalendarPlan _plan(String spaceId, String id, Map<String, dynamic> data) {
  final allDay = data['allDay'] == true;
  DateTime date(Object? value, Object? millisFallback) {
    final parsed =
        firebaseDate(value) ?? firebaseDate(millisFallback) ?? DateTime.now();
    final time = parsed.toUtc();
    return allDay ? DateTime(time.year, time.month, time.day) : time;
  }

  return CalendarPlan(
    id: id,
    spaceId: spaceId,
    ownerId: data['ownerUid'] as String? ?? '',
    title: data['title'] as String? ?? '',
    start: date(data['startAt'], data['startMillis']),
    end: date(data['endAt'], data['endMillis']),
    allDay: allDay,
    note: data['note'] as String? ?? '',
    participants: List<String>.from(data['participants'] as List? ?? []),
    pin: PlacePin.fromMap(data['pin']),
    googleCalendarId: data['sourceCalendarId'] as String?,
    googleEventId: data['sourceEventId'] as String?,
    googleUpdatedAt: data['sourceUpdatedAt'] as String?,
    reminder: PlanReminder.values.firstWhere(
      (r) => r.name == data['reminder'],
      orElse: () => PlanReminder.none,
    ),
    revision: data['revision'] as int? ?? 0,
  );
}

class FirebaseCalendarRepository extends CalendarDataSource {
  FirebaseCalendarRepository(this.timeline);
  final FirebaseTimelineRepository timeline;
  @override
  List<CalendarPlan> get plans => timeline.plans;
  @override
  Stream<void> get changes => timeline.changes;
  @override
  Future<CalendarPlan> save({
    String? id,
    required String spaceId,
    required String actorId,
    required String title,
    required DateTime start,
    required DateTime end,
    required bool allDay,
    String note = '',
    List<String> participants = const [],
    PlacePin? pin,
    PlanReminder reminder = PlanReminder.none,
  }) async {
    if (actorId != timeline.currentUserId) {
      throw StateError('Use your own account.');
    }
    if (id == null && dateOnly(start).isBefore(dateOnly(DateTime.now()))) {
      throw ArgumentError('Plans cannot be created in the past.');
    }
    final planId =
        id ?? timeline.backend.firestore.collection('planIds').doc().id;
    int time(DateTime d) =>
        (allDay ? DateTime.utc(d.year, d.month, d.day) : d.toUtc())
            .millisecondsSinceEpoch;
    final operationId = timeline.backend.firestore
        .collection('operationIds')
        .doc()
        .id;
    final payload = <String, Object?>{
      'spaceId': spaceId,
      'planId': planId,
      'title': title,
      'note': note,
      'allDay': allDay,
      'startMillis': time(start),
      'endMillis': time(end),
      'participants': participants,
      if (pin != null) 'pin': pin.toMap(),
      'reminder': reminder.name,
      'operationId': operationId,
      if (id != null)
        'expectedRevision': plans.firstWhere((p) => p.id == id).revision,
    };
    await timeline.outbox.add(operationId, spaceId, 'planSave', payload);
    return CalendarPlan(
      id: planId,
      spaceId: spaceId,
      ownerId: actorId,
      title: title,
      start: start,
      end: end,
      allDay: allDay,
      note: note,
      participants: participants,
      pin: pin,
      reminder: reminder,
      syncState: SyncState.pending,
    );
  }

  @override
  Future<void> remove(String id, String actorId) async {
    final plan = plans.firstWhere((p) => p.id == id);
    if (actorId != timeline.currentUserId || plan.ownerId != actorId) {
      throw StateError('Only the author can remove this plan.');
    }
    final operationId = timeline.backend.firestore
        .collection('operationIds')
        .doc()
        .id;
    await timeline.outbox.add(operationId, plan.spaceId, 'planRemove', {
      'spaceId': plan.spaceId,
      'planId': id,
      'expectedRevision': plan.revision,
    });
  }
}
