import '../../core/month_year_picker.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/place_pin.dart';
import '../../core/sync_state.dart';

import '../../core/demo_state.dart';
import '../timeline/domain/models.dart';

enum PlanReminder {
  none,
  atStart,
  tenMinutes,
  oneHour,
  oneDay,
  morningOf,
  morningBefore,
}

extension PlanReminderLabel on PlanReminder {
  String get label => switch (this) {
    PlanReminder.none => 'Off',
    PlanReminder.atStart => 'At start',
    PlanReminder.tenMinutes => '10 minutes before',
    PlanReminder.oneHour => '1 hour before',
    PlanReminder.oneDay => '1 day before',
    PlanReminder.morningOf => '9 a.m. that day',
    PlanReminder.morningBefore => '9 a.m. the day before',
  };
}

class CalendarPlan {
  const CalendarPlan({
    required this.id,
    required this.spaceId,
    required this.ownerId,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.note = '',
    this.participants = const [],
    this.pin,
    this.googleCalendarId,
    this.googleEventId,
    this.googleUpdatedAt,
    this.reminder = PlanReminder.none,
    this.syncState = SyncState.synced,
    this.revision = 0,
    this.pendingRemoval = false,
  });
  final String id, spaceId, ownerId, title, note;
  // Timed instants are UTC. All-day values are floating local dates, end exclusive.
  final DateTime start, end;
  final bool allDay;
  final List<String> participants;
  final PlacePin? pin;
  final String? googleCalendarId, googleEventId, googleUpdatedAt;
  final PlanReminder reminder;
  final SyncState syncState;
  final int revision;
  final bool pendingRemoval;
  bool get isImported => googleCalendarId != null && googleEventId != null;
  DateTime get localStart => allDay ? start : start.toLocal();
  DateTime get localEnd => allDay ? end : end.toLocal();
  bool matches(String? person) =>
      person == null || ownerId == person || participants.contains(person);
  bool occursOn(DateTime date) {
    final day = dateOnly(date);
    final next = DateTime(day.year, day.month, day.day + 1);
    return localStart.isBefore(next) && localEnd.isAfter(day);
  }
}

abstract class CalendarDataSource {
  List<CalendarPlan> get plans;
  Stream<void> get changes => const Stream.empty();
  FutureOr<CalendarPlan> save({
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
  });
  FutureOr<void> remove(String id, String actorId);
}

class CalendarRepository extends CalendarDataSource {
  CalendarRepository(
    this.spaces, {
    DateTime Function()? clock,
    bool seed = true,
  }) {
    if (!seed) return;
    final now = (clock ?? DateTime.now)();
    DateTime at(int day, int hour) =>
        DateTime(now.year, now.month, day, hour).toUtc();
    _plans.addAll([
      CalendarPlan(
        id: 'walk',
        spaceId: 'home',
        ownerId: 'me',
        title: 'A little evening walk',
        start: at(now.day, 19),
        end: at(now.day, 20),
        participants: ['alex', 'jo'],
        note: 'Meet by the gate.',
      ),
      CalendarPlan(
        id: 'coffee',
        spaceId: 'home',
        ownerId: 'alex',
        title: 'Coffee with a friend',
        start: at(now.day + 2, 10),
        end: at(now.day + 2, 11),
      ),
      CalendarPlan(
        id: 'study',
        spaceId: 'home',
        ownerId: 'sam',
        title: 'Study afternoon',
        start: at(now.day, 14),
        end: at(now.day, 17),
      ),
      for (final d in [3, 6, 9, 12, 16, 20, 25, 28])
        CalendarPlan(
          id: 'plan-$d',
          spaceId: 'home',
          ownerId: d.isEven ? 'me' : 'jo',
          title: d.isEven ? 'A little time outside' : 'Meet up with friends',
          start: at(d, 17),
          end: at(d, 18),
        ),
    ]);
  }
  final List<Space> spaces;
  @override
  Stream<void> get changes => const Stream.empty();
  final List<CalendarPlan> _plans = [];
  int _serial = 0;
  @override
  List<CalendarPlan> get plans => List.unmodifiable(_plans);
  @override
  CalendarPlan save({
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
  }) {
    final space = spaces.firstWhere((space) => space.id == spaceId);
    if (!space.members.any((m) => m.id == actorId)) {
      throw StateError('You cannot add plans in this space.');
    }
    final existing = id == null
        ? null
        : _plans.where((p) => p.id == id).firstOrNull;
    if (id != null &&
        (existing == null ||
            existing.ownerId != actorId ||
            existing.spaceId != spaceId)) {
      throw StateError('Only the author can edit this plan.');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError('Give your plan a name.');
    }
    final begins = allDay ? dateOnly(start) : start.toUtc();
    final ends = allDay ? dateOnly(end) : end.toUtc();
    if (!ends.isAfter(begins)) {
      throw ArgumentError('The end must be after the start.');
    }
    if (participants.any((id) => !space.members.any((m) => m.id == id))) {
      throw ArgumentError('Participants must belong to this space.');
    }
    final plan = CalendarPlan(
      id: id ?? 'calendar-${_serial++}',
      spaceId: spaceId,
      ownerId: actorId,
      title: title.trim(),
      start: begins,
      end: ends,
      allDay: allDay,
      note: note.trim(),
      participants: participants.toSet().toList(),
      pin: pin,
      reminder: reminder,
    );
    _plans.removeWhere((p) => p.id == id);
    _plans.add(plan);
    return plan;
  }

  @override
  void remove(String id, String actorId) {
    final plan = _plans.firstWhere((p) => p.id == id);
    if (plan.ownerId != actorId) {
      throw StateError('Only the author can remove this plan.');
    }
    _plans.remove(plan);
  }
}

final calendarRepositoryProvider = Provider<CalendarDataSource>(
  (ref) => CalendarRepository(ref.read(repositoryProvider).spaces),
);
final calendarProvider = NotifierProvider<CalendarController, CalendarState>(
  CalendarController.new,
);

class CalendarState {
  const CalendarState(this.plans, this.month, this.selectedDay);
  final List<CalendarPlan> plans;
  final DateTime month, selectedDay;
  List<CalendarPlan> forDay(String spaceId, String? person, DateTime day) =>
      plans
          .where(
            (p) => p.spaceId == spaceId && p.matches(person) && p.occursOn(day),
          )
          .toList()
        ..sort((a, b) => a.localStart.compareTo(b.localStart));
}

class CalendarController extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    ref.watch(demoProvider.select((state) => state.spaceId));
    final today = dateOnly(DateTime.now());
    final repository = ref.watch(calendarRepositoryProvider);
    final updates = repository.changes.listen((_) => refresh());
    ref.onDispose(updates.cancel);
    return CalendarState(
      ref.watch(calendarRepositoryProvider).plans,
      DateTime(today.year, today.month),
      today,
    );
  }

  void refresh() => state = CalendarState(
    ref.read(calendarRepositoryProvider).plans,
    state.month,
    state.selectedDay,
  );
  void selectDay(DateTime day) => state = CalendarState(
    state.plans,
    DateTime(day.year, day.month),
    dateOnly(day),
  );
  void changeMonth(int delta) {
    final month = clampCalendarMonth(
      DateTime(state.month.year, state.month.month + delta),
    );
    state = CalendarState(
      state.plans,
      month,
      calendarDayInMonth(month, state.selectedDay.day),
    );
  }
}
