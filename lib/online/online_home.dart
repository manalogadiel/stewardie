import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dart:async';

import '../app.dart' show GlassDock;
import '../core/clay.dart';
import '../core/invite_links.dart';
import '../core/theme.dart';
import '../core/top_controls.dart';
import '../core/member_avatar.dart';
import '../core/soft_pop_backdrop.dart';
import '../core/stewardie_action_icons.dart';
import 'account_settings_sheet.dart';
import 'activity_inbox_sheet.dart';
import 'account_notification_bell.dart';
import 'safety_sheet.dart';
import 'live_location_pill.dart';
import 'live_location_service.dart';
import 'online_backend.dart';
import 'online_moments.dart';
import 'online_task_detail_sheet.dart';
import 'online_today_extras.dart';
import 'push_service.dart';
import 'qr_invite_sheet.dart';
import 'qr_join_sheet.dart';
import 'routines_sheet.dart';
import 'space_deletion_sheet.dart';
import 'space_map_sheet.dart';
import 'task_completion_prompt_sheet.dart';

import 'package:sembast/sembast.dart';

import '../features/subscription/revenuecat_service.dart';
import '../features/subscription/soft_pop_paywall.dart';
import '../features/onboarding/tutorial/tutorial_coordinator.dart';
import '../features/onboarding/tutorial/tutorial_state.dart';
import '../features/onboarding/tutorial/tutorial_target_registry.dart';
import '../features/onboarding/onboarding_store.dart';

class OnlineHome extends StatefulWidget {
  const OnlineHome({
    super.key,
    required this.backend,
    required this.user,
    this.spaceOnly = false,
    this.spaceId,
    this.onSpaceSelected,
    this.database,
    this.onTabRequested,
  });
  final OnlineBackend backend;
  final User user;
  final bool spaceOnly;
  final String? spaceId;
  final ValueChanged<String?>? onSpaceSelected;
  final Database? database;
  final ValueChanged<int>? onTabRequested;

  @override
  State<OnlineHome> createState() => _OnlineHomeState();
}

class _OnlineHomeState extends State<OnlineHome> {
  late final Future<OnlineMomentsStore> _momentStore =
      OnlineMomentsStore.open();
  String? _spaceId;
  String? _personId;
  int _destination = 0;
  bool _showDone = false;
  bool _creating = false;
  final _busyTasks = <String>{};
  String? _historyKey;
  Future<Map<String, dynamic>>? _historyFuture;
  final _moreDone = <Map<String, dynamic>>[];
  String? _moreCursor;
  bool _loadingMore = false;
  bool _entryPromptsStarted = false;
  bool _hasSpaces = false;
  StreamSubscription<void>? _pushOpens;
  StreamSubscription<void>? _foregroundPush;

  @override
  void initState() {
    super.initState();
    LiveLocationService.instance.init(widget.backend);
    RevenueCatService.instance.addListener(_onRevenueCatUpdate);
    _pushOpens = PushService.instance.inboxOpens.listen((_) {
      unawaited(_openInboxFromPush());
    });
    _foregroundPush = PushService.instance.foregroundUpdates.listen((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You have a Stewardie update.'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => unawaited(_openInboxFromPush()),
          ),
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && PushService.instance.takePendingInboxOpen()) {
        unawaited(_openInboxFromPush());
      }
    });
  }

  Future<void> _openInboxFromPush() async {
    try {
      final refs = await widget.backend.spaces(widget.user.uid).first;
      if (!mounted) return;
      // The inbox owns navigation and verifies the current task/space before
      // opening it; a stale notification is never treated as access.
      _showInbox(refs.docs);
    } catch (_) {
      if (mounted) _message('Could not open activity. Try the bell again.');
    }
  }

  Future<void> _runEntryPrompts() async {
    try {
      await TutorialCoordinator(widget.database).checkAndPromptTour(
        context,
        uid: widget.user.uid,
        hasSpaces: _hasSpaces,
        onTabRequested: (tab) {
          if (mounted && _destination != tab) {
            if (widget.onTabRequested != null) {
              widget.onTabRequested!(tab);
            } else {
              setState(() => _destination = tab);
            }
          }
        },
      );
    } catch (_) {
      // An unavailable tutorial must not prevent the account from entering a space.
    }
    if (!mounted || _hasSpaces) return;
    // Let the invitation or tour overlay finish removing before opening the sheet.
    await Future<void>.delayed(Duration.zero);
    if (mounted && !_hasSpaces) {
      _chooseSpace(const [], null);
    }
  }

  @override
  void dispose() {
    RevenueCatService.instance.removeListener(_onRevenueCatUpdate);
    _pushOpens?.cancel();
    _foregroundPush?.cancel();
    LiveLocationService.instance.stopSharing();
    super.dispose();
  }

  @override
  void didUpdateWidget(OnlineHome old) {
    super.didUpdateWidget(old);
    // When the parent changes the space via the spaceId prop (not via
    // _switchSpace), reset the per-member filter so the old filter cannot
    // bleed into the new space's task list.
    if (old.spaceId != widget.spaceId && widget.spaceId != null) {
      _personId = null;
      _invalidateHistory();
    }
  }

  void _onRevenueCatUpdate() {
    if (mounted) setState(() {});
  }

  void _invalidateHistory() {
    _historyKey = null;
    _historyFuture = null;
    _moreDone.clear();
    _moreCursor = null;
  }

  Future<void> _openTaskDetail(
    String spaceId,
    String taskId,
    Map<String, dynamic> task,
    Map<String, Map<String, dynamic>> members,
  ) async {
    final store = await _momentStore;
    if (!mounted) return;
    OnlineTaskDetailSheet.show(
      context,
      backend: widget.backend,
      spaceId: spaceId,
      task: {...task, 'id': taskId},
      members: members.entries.map((e) => {'uid': e.key, ...e.value}).toList(),
      momentStore: store,
      onChanged: () => setState(() => _invalidateHistory()),
    );
  }

  Future<void> _openCompletionPrompt(
    String spaceId,
    String taskId,
    String taskTitle,
  ) async {
    final store = await _momentStore;
    if (!mounted) return;
    TaskCompletionPromptSheet.show(
      context,
      backend: widget.backend,
      spaceId: spaceId,
      taskId: taskId,
      taskTitle: taskTitle,
      momentStore: store,
      onCompleted: () => setState(() => _invalidateHistory()),
    );
  }

  void _switchSpace(String? id) => setState(() {
    _spaceId = id;
    _personId = null;
    _showDone = false;
    _invalidateHistory();
    widget.onSpaceSelected?.call(id);
  });

  Future<Map<String, dynamic>> _history(String spaceId) {
    final key = '$spaceId/${_personId ?? 'everyone'}';
    if (_historyKey != key) {
      _historyKey = key;
      _moreDone.clear();
      _moreCursor = null;
      _historyFuture = widget.backend.call('listCompletedTasks', {
        'spaceId': spaceId,
        if (_personId != null) 'personUid': _personId,
      });
    }
    return _historyFuture!;
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  String _error(Object error) {
    if (error is StateError) {
      return error.message;
    }
    if (error is FirebaseException) {
      return error.message ?? 'Could not save. Try again.';
    }
    return 'Could not connect. Try again.';
  }

  Future<void> _act(String spaceId, String taskId, String action) async {
    if (!_busyTasks.add(taskId)) return;
    setState(() {});
    try {
      final operationId = widget.backend.firestore
          .collection('operationIds')
          .doc()
          .id;
      await widget.backend.call('actOnTask', {
        'spaceId': spaceId,
        'taskId': taskId,
        'operationId': operationId,
        'action': action,
      });
      if (mounted) setState(_invalidateHistory);
    } catch (error) {
      _message(_error(error));
    } finally {
      _busyTasks.remove(taskId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadMore(String spaceId, String cursor) async {
    if (_loadingMore) return;
    final requestKey = _historyKey;
    final personId = _personId;
    setState(() => _loadingMore = true);
    try {
      final values = <String, dynamic>{'spaceId': spaceId, 'cursorId': cursor};
      if (personId != null) values['personUid'] = personId;
      final result = await widget.backend.call('listCompletedTasks', values);
      if (!mounted || _historyKey != requestKey) return;
      setState(() {
        _moreDone.addAll(
          (result['tasks'] as List).map(
            (value) => Map<String, dynamic>.from(value as Map),
          ),
        );
        _moreCursor = result['nextCursorId'] as String?;
      });
    } catch (error) {
      _message(_error(error));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.backend.spaces(widget.user.uid),
        builder: (context, snapshot) {
          final refs = snapshot.data?.docs ?? [];
          if (snapshot.hasData) {
            _hasSpaces = refs.isNotEmpty;
            if (!widget.spaceOnly && !_entryPromptsStarted) {
              _entryPromptsStarted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _runEntryPrompts();
              });
            }
          }
          final requestedSpace = widget.spaceId ?? _spaceId;
          final selected = refs.any((doc) => doc.id == requestedSpace)
              ? requestedSpace
              : (refs.isEmpty ? null : refs.first.id);
          final space = selected == null
              ? null
              : refs.firstWhere((doc) => doc.id == selected);
          if (widget.spaceOnly) return _space(selected, space);
          return Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                const Positioned.fill(child: SoftPopBackdrop()),
                Positioned.fill(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: switch (_destination) {
                      0 => _today(selected, snapshot),
                      1 => _moments(selected, space),
                      _ => _space(selected, space),
                    },
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: IconButton(
                              key: TutorialTargetRegistry.mapButtonTarget,
                              tooltip: selected == null
                                  ? 'Private map'
                                  : 'Space map',
                              style: IconButton.styleFrom(
                                backgroundColor: SoftPop.surface,
                                shape: const CircleBorder(),
                              ),
                              onPressed: () => SpaceMapSheet.show(
                                context,
                                backend: widget.backend,
                                spaceId: selected,
                                onJoinSpace: selected == null
                                    ? () => _chooseSpace(refs, null)
                                    : null,
                              ),
                              icon: const Icon(
                                Icons.map_outlined,
                                color: SoftPop.ink,
                                size: 22,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: TextButton(
                                key: TutorialTargetRegistry.spaceSelectorTarget,
                                style: TextButton.styleFrom(
                                  backgroundColor: SoftPop.surface,
                                  shape: const StadiumBorder(),
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: () => _chooseSpace(refs, selected),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        space?.data()['name'] as String? ??
                                            'My spaces',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: SoftPop.ink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.expand_more_rounded,
                                      color: SoftPop.ink,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: IconButton(
                              key:
                                  TutorialTargetRegistry.notificationBellTarget,
                              tooltip: 'Notifications',
                              style: IconButton.styleFrom(
                                backgroundColor: SoftPop.surface,
                                shape: const CircleBorder(),
                              ),
                              onPressed: () => _showInbox(refs),
                              icon: _notificationBell(refs),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
                ? null
                : SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Center(
                        heightFactor: 1,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const LiveLocationPill(),
                              GlassDock(
                                index: _destination,
                                onSelected: (index) =>
                                    setState(() => _destination = index),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          );
        },
      );

  Widget _page(List<Widget> children, {double? topPadding}) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          topPadding ?? topControlsClearance(context),
          20,
          148,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );

  Widget _today(
    String? spaceId,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> spaceSnapshot,
  ) {
    if (spaceSnapshot.hasError) {
      return _todayPage(
        summary: [
          const SizedBox(height: 16),
          _emptyPanel(
            'Could not open your spaces',
            'Check your connection and try again.',
          ),
        ],
        tabs: const SizedBox.shrink(),
        tasks: const [],
        showTabs: false,
      );
    }
    if (!spaceSnapshot.hasData) {
      return _todayPage(
        summary: const [
          SizedBox(height: 24),
          Center(child: CircularProgressIndicator()),
        ],
        tabs: const SizedBox.shrink(),
        tasks: const [],
        showTabs: false,
      );
    }
    if (spaceId == null) {
      return _todayPage(
        summary: [
          const SizedBox(height: 16),
          _emptyPanel(
            'Bring your people together',
            'Create a space or join one you have been invited to.',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _createSpace,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create a space'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _joinSpace,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Join with a code'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        tabs: const SizedBox.shrink(),
        tasks: const [],
        showTabs: false,
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.backend.members(spaceId),
      builder: (context, peopleSnapshot) {
        if (peopleSnapshot.hasError) {
          return _todayPage(
            spaceId: spaceId,
            summary: [
              const SizedBox(height: 16),
              _emptyPanel(
                'Could not load this space',
                'Check your connection and try again.',
              ),
            ],
            tabs: const SizedBox.shrink(),
            tasks: const [],
            showTabs: false,
          );
        }
        final members = <String, Map<String, dynamic>>{
          for (final doc in peopleSnapshot.data?.docs ?? [])
            if (doc.data()['status'] == 'active') doc.id: doc.data(),
        };
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.backend.activeTasks(spaceId),
          builder: (context, taskSnapshot) {
            if (taskSnapshot.hasError) {
              return _todayPage(
                spaceId: spaceId,
                summary: [
                  const SizedBox(height: 16),
                  _peopleFilters(members),
                  const SizedBox(height: 16),
                  _emptyPanel(
                    'Could not load tasks',
                    'Check your connection and try again.',
                  ),
                ],
                tabs: const SizedBox.shrink(),
                tasks: const [],
                showTabs: false,
              );
            }
            final all = taskSnapshot.data?.docs ?? [];
            final filtered = all.where((doc) {
              if (_personId == null) return true;
              final task = doc.data();
              return task['ownerUid'] == _personId ||
                  task['requestedUid'] == _personId;
            }).toList();
            filtered.sort((a, b) {
              final left = a.data()['createdAt'];
              final right = b.data()['createdAt'];
              if (left is Timestamp && right is Timestamp) {
                return right.compareTo(left);
              }
              return 0;
            });
            final pending = filtered
                .where((doc) => doc.data()['status'] != 'accepted')
                .toList();
            final covered = filtered
                .where((doc) => doc.data()['status'] == 'accepted')
                .toList();
            return FutureBuilder<Map<String, dynamic>>(
              future: _history(spaceId),
              builder: (context, doneSnapshot) {
                final firstPage =
                    (doneSnapshot.data?['tasks'] as List?)
                        ?.map(
                          (value) => Map<String, dynamic>.from(value as Map),
                        )
                        .toList() ??
                    [];
                final allDone = [...firstPage, ..._moreDone];
                final done = _personId == null
                    ? allDone
                    : allDone
                          .where(
                            (data) =>
                                data['ownerUid'] == _personId ||
                                data['requestedUid'] == _personId ||
                                data['creatorUid'] == _personId,
                          )
                          .toList();
                final count = doneSnapshot.data?['totalCount'] as int?;
                final nextCursor = _moreDone.isEmpty
                    ? (doneSnapshot.data?['nextCursorId'] as String?)
                    : _moreCursor;
                final spaceName =
                    spaceSnapshot.data!.docs
                            .firstWhere((doc) => doc.id == spaceId)
                            .data()['name']
                        as String? ??
                    'Your space';
                return _todayPage(
                  spaceId: spaceId,
                  spaceKind:
                      spaceSnapshot.data!.docs
                              .firstWhere((doc) => doc.id == spaceId)
                              .data()['kind']
                          as String?,
                  summary: [
                    const SizedBox(height: 16),
                    KeyedSubtree(
                      key: TutorialTargetRegistry.dayTogetherTarget,
                      child: _peopleFilters(members),
                    ),
                    const SizedBox(height: 16),
                    OnlineTodayExtras(
                      backend: widget.backend,
                      spaceId: spaceId,
                      spaceName: spaceName,
                      myUid: widget.user.uid,
                      personUid: _personId,
                      members: members,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _countCard('${pending.length}', 'Help', SoftPop.butter),
                        const SizedBox(width: 8),
                        _countCard('${covered.length}', 'Covered', SoftPop.sky),
                        const SizedBox(width: 8),
                        _countCard(
                          count == null ? '–' : '$count',
                          'Done',
                          SoftPop.rose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  tabs: Row(
                    children: [
                      Expanded(
                        child: _taskTab(
                          'Pending',
                          pending.length + covered.length,
                          false,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: _taskTab('Done', count ?? 0, true)),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: TutorialTargetRegistry.tasksTarget,
                        tooltip: 'Add task',
                        onPressed: _creating
                            ? null
                            : () => _createTask(spaceId, members),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  tasks: [
                    if (!_showDone) ...[
                      if (taskSnapshot.connectionState ==
                          ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator()),
                      if (taskSnapshot.hasData && filtered.isEmpty)
                        _emptyPanel(
                          'All clear for now',
                          'Add a task when something comes up.',
                        ),
                      if (pending.isNotEmpty) ...[
                        _sectionTitle('Pending'),
                        for (final doc in pending)
                          _taskCard(spaceId, doc.id, doc.data(), members),
                      ],
                      if (covered.isNotEmpty) ...[
                        _sectionTitle('Covered'),
                        for (final doc in covered)
                          _taskCard(spaceId, doc.id, doc.data(), members),
                      ],
                    ] else ...[
                      if (doneSnapshot.connectionState ==
                          ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator()),
                      if (doneSnapshot.hasError)
                        _emptyPanel(
                          'Could not load Done',
                          'Check your connection and try again.',
                        ),
                      if (doneSnapshot.hasData && done.isEmpty)
                        _emptyPanel(
                          'Nothing done yet',
                          'Finished tasks will appear here.',
                        ),
                      for (final task in done)
                        _taskCard(spaceId, task['id'] as String, task, members),
                      if (nextCursor != null)
                        OutlinedButton(
                          onPressed: _loadingMore
                              ? null
                              : () => _loadMore(spaceId, nextCursor),
                          child: Text(
                            _loadingMore ? 'Loading…' : 'Load older tasks',
                          ),
                        ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _todayPage({
    String? spaceId,
    String? spaceKind,
    required List<Widget> summary,
    required Widget tabs,
    required List<Widget> tasks,
    bool showTabs = true,
  }) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: CustomScrollView(
        // The empty Moments page has the same widget shape. A distinct key
        // prevents its scroll offset from carrying into Today on tab changes.
        key: PageStorageKey<String>('online-today-${spaceId ?? 'none'}'),
        slivers: [
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) {
                final scale = MediaQuery.textScalerOf(context).scale(16);
                final topClearance =
                    MediaQuery.paddingOf(context).top +
                    (scale > 22 ? 116.0 : 68.0);
                return ClayPanel(
                  color: SoftPop.today,
                  padding: EdgeInsets.fromLTRB(20, topClearance, 16, 12),
                  radius: const BorderRadius.vertical(
                    bottom: Radius.circular(28),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(fontSize: 32),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              MaterialLocalizations.of(context)
                                  .formatMediumDate(DateTime.now()),
                            ),
                            const SizedBox(height: 8),
                            const Text('Little things, together.'),
                          ],
                        ),
                      ),
                      if (scale <= 22)
                        spaceId == null
                            ? const ClayArt('greeting', height: 96, width: 132)
                            : SpaceMascotArt(spaceKind, height: 96, width: 132),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (spaceId != null)
                    FutureBuilder<TutorialStatus>(
                      future: TutorialStore(widget.database)
                          .getStatus(widget.user.uid),
                      builder: (context, snapshot) =>
                          snapshot.data == TutorialStatus.awaitingSpace
                          ? Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: FilledButton.icon(
                                icon: const Icon(Icons.explore_outlined),
                                label: const Text('Continue tour'),
                                onPressed: () async {
                                  await TutorialCoordinator(widget.database)
                                      .continueTour(
                                        context,
                                        uid: widget.user.uid,
                                        onTabRequested: (tab) {
                                          if (!mounted) return;
                                          if (widget.onTabRequested != null) {
                                            widget.onTabRequested!(tab);
                                          } else {
                                            setState(() => _destination = tab);
                                          }
                                        },
                                      );
                                  if (mounted) setState(() {});
                                },
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ...summary,
                ],
              ),
            ),
          ),
          if (showTabs)
            SliverPersistentHeader(
              pinned: true,
              delegate: _OnlineTaskTabHeader(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: tabs,
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              140 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.list(children: tasks),
          ),
        ],
      ),
    ),
  );

  Widget _taskTab(String title, int count, bool done) => Semantics(
    selected: _showDone == done,
    child: Material(
      color: _showDone == done ? SoftPop.surface : const Color(0xFFECEBE8),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: InkWell(
        onTap: () => setState(() => _showDone = done),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(
            '$title ($count)',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _showDone == done ? SoftPop.blue : SoftPop.secondary,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _hero(
    String title,
    String subtitle, {
    String? supportingLabel,
    int maxTitleLines = 2,
    String? spaceKind,
  }) => Material(
    color: SoftPop.today,
    borderRadius: const BorderRadius.only(
      bottomLeft: Radius.circular(28),
      bottomRight: Radius.circular(28),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (supportingLabel != null) ...[
                  Text(
                    supportingLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: SoftPop.ink.withValues(alpha: .75),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineLarge,
                  maxLines: maxTitleLines,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SpaceMascotArt(spaceKind, height: 118, width: 124),
        ],
      ),
    ),
  );

  Widget _emptyPanel(String title, String detail) => ClayPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(detail),
      ],
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _countCard(String number, String label, Color color) => Expanded(
    child: Column(
      children: [
        Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(number, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    ),
  );

  Widget _peopleFilters(Map<String, Map<String, dynamic>> members) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _personChip(null, 'Everyone'),
            _personChip(
              widget.user.uid,
              'Me',
              resolvedName: members[widget.user.uid]?['name'] as String?,
            ),
            for (final entry in members.entries)
              if (entry.key != widget.user.uid)
                _personChip(
                  entry.key,
                  entry.value['name'] as String? ?? 'Member',
                ),
          ],
        ),
      );

  Widget _personChip(
    String? id,
    String label, {
    String? resolvedName,
  }) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: ChoiceChip(
        showCheckmark: false,
        avatar: id == null
            ? null
            : MemberAvatar(
                uid: id,
                name:
                    resolvedName ??
                    (id == widget.user.uid
                        ? (widget.user.displayName?.trim().isNotEmpty == true
                              ? widget.user.displayName!
                              : widget.user.email?.split('@').first ?? 'Member')
                        : label),
                radius: 13,
              ),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: _personId == id,
        onSelected: (_) => setState(() {
          _personId = id;
          _invalidateHistory();
        }),
      ),
    ),
  );

  Widget _taskCard(
    String spaceId,
    String taskId,
    Map<String, dynamic> task,
    Map<String, Map<String, dynamic>> members,
  ) {
    final status = task['status'] as String? ?? 'unclaimed';
    final owner = task['ownerUid'] as String?;
    final requested = task['requestedUid'] as String?;
    final offered = task['offeredUid'] as String?;
    final label = switch (status) {
      'requested' => 'Awaiting ${members[requested]?['name'] ?? 'acceptance'}',
      'accepted' => 'Covered by ${members[owner]?['name'] ?? 'a member'}',
      'needsHelp' =>
        offered == null
            ? '${members[owner]?['name'] ?? 'A member'} needs help'
            : 'Handoff offered by ${members[offered]?['name'] ?? 'a member'}',
      'completed' => 'Finished by ${members[owner]?['name'] ?? 'a member'}',
      _ => 'Needs someone',
    };
    final action = switch (status) {
      'unclaimed' => ('accept', "I'll do it"),
      'requested' when requested == widget.user.uid => ('accept', 'Accept'),
      'accepted' when owner == widget.user.uid => ('complete', 'Mark done'),
      'needsHelp' when owner == widget.user.uid && offered != null => (
        'confirmHandoff',
        'Hand over',
      ),
      'needsHelp' when owner == widget.user.uid => ('complete', 'Mark done'),
      'needsHelp' when owner != widget.user.uid && offered == null => (
        'offerHelp',
        'Offer help',
      ),
      _ => null,
    };
    final subtasks = List<Map<String, dynamic>>.from(
      (task['subtasks'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final hasSubtasks = subtasks.isNotEmpty;
    final doneSubtasks = subtasks.where((s) => s['done'] == true).length;
    final isHelpNeeded = task['helpNeeded'] == true || status == 'needsHelp';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _openTaskDetail(spaceId, taskId, task, members),
        child: ClayPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task['title'] as String? ?? 'Task',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: Text(label)),
                  if (hasSubtasks)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$doneSubtasks/${subtasks.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF244BFF),
                        ),
                      ),
                    ),
                  if (isHelpNeeded) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Help needed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (action != null ||
                  (status == 'requested' && requested == widget.user.uid) ||
                  (status == 'accepted' && owner == widget.user.uid)) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (action != null)
                      FilledButton.tonal(
                        onPressed: _busyTasks.contains(taskId)
                            ? null
                            : () {
                                if (action.$1 == 'complete') {
                                  _openCompletionPrompt(
                                    spaceId,
                                    taskId,
                                    task['title'] as String? ?? 'Task',
                                  );
                                } else {
                                  _act(spaceId, taskId, action.$1);
                                }
                              },
                        child: Text(
                          _busyTasks.contains(taskId) ? 'Saving…' : action.$2,
                        ),
                      ),
                    if (status == 'requested' && requested == widget.user.uid)
                      TextButton(
                        onPressed: _busyTasks.contains(taskId)
                            ? null
                            : () => _act(spaceId, taskId, 'decline'),
                        child: const Text('Decline'),
                      ),
                    if (status == 'accepted' && owner == widget.user.uid)
                      TextButton(
                        onPressed: _busyTasks.contains(taskId)
                            ? null
                            : () => _act(spaceId, taskId, 'needHelp'),
                        child: const Text('Need help'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _moments(
    String? spaceId,
    QueryDocumentSnapshot<Map<String, dynamic>>? space,
  ) {
    if (spaceId == null) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: CustomScrollView(
            key: const PageStorageKey<String>('online-moments-empty'),
            slivers: [
              SliverToBoxAdapter(
                child: Builder(
                  builder: (context) {
                    final scale = MediaQuery.textScalerOf(context).scale(16);
                    final topClearance =
                        MediaQuery.paddingOf(context).top +
                        (scale > 22 ? 116.0 : 68.0);
                    return ClayPanel(
                      color: SoftPop.today,
                      padding: EdgeInsets.fromLTRB(20, topClearance, 16, 12),
                      radius: const BorderRadius.vertical(
                        bottom: Radius.circular(28),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Little moments',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(fontSize: 32),
                                ),
                                const SizedBox(height: 4),
                                const Text('A space for the good bits.'),
                              ],
                            ),
                          ),
                          if (scale <= 22)
                            const ClayArt(
                              'moments-selfie-group',
                              height: 96,
                              width: 132,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 148),
                sliver: SliverList.list(
                  children: [
                    _emptyPanel(
                      'Make a space first',
                      'Your moments belong to a space.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _createSpace,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create a space'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _joinSpace,
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('Join with a code'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return FutureBuilder<OnlineMomentsStore>(
      future: _momentStore,
      builder: (context, librarySnapshot) {
        if (librarySnapshot.hasError) {
          return _page([
            _emptyPanel(
              'Could not open photos',
              'Saved photos are still on this device. Try reopening the app.',
            ),
          ]);
        }
        if (!librarySnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.backend.members(spaceId),
          builder: (context, peopleSnapshot) => OnlineMomentsScreen(
            store: librarySnapshot.data!,
            backend: widget.backend,
            spaceId: spaceId,
            spaceName: space?.data()['name'] as String? ?? 'Your space',
            myUid: widget.user.uid,
            personUid: _personId,
            members: {
              for (final doc in peopleSnapshot.data?.docs ?? [])
                if (doc.data()['status'] == 'active') doc.id: doc.data(),
            },
            onPersonSelected: (uid) => setState(() {
              _personId = uid;
              _invalidateHistory();
            }),
          ),
        );
      },
    );
  }

  Future<bool> _confirm(String title, String detail, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _membershipAction(
    String action,
    String spaceId, {
    String? memberUid,
    required String name,
  }) async {
    final label = switch (action) {
      'leaveSpace' => 'Leave space',
      'removeMember' => 'Remove member',
      'offerOwnership' => 'Offer ownership',
      _ => 'Accept ownership',
    };
    final description = action == 'removeMember' || action == 'leaveSpace'
        ? '$name will lose access to this space. Their unfinished tasks will return to Pending. Shared history is kept.'
        : '$name will become responsible for invitations and membership. Ownership changes only after acceptance.';
    if (!await _confirm('$label?', description, label)) return;
    try {
      await widget.backend.call(action, {
        'spaceId': spaceId,
        'memberUid': ?memberUid,
      });
      if (mounted) _message('$label completed.');
    } catch (error) {
      if (mounted) _message(_error(error));
    }
  }

  void _openAccountSettings(String? spaceId, bool plus) {
    AccountSettingsSheet.show(
      context,
      backend: widget.backend,
      tier: plus ? 'Plus' : 'Basic',
      spaceId: spaceId,
      onSignedOut: () => RevenueCatService.instance.logOut(),
      onTakeTour: () async {
        await TutorialCoordinator(widget.database).replayTour(
          context,
          uid: widget.user.uid,
          hasSpaces: _hasSpaces,
          onTabRequested: (tab) {
            if (widget.onTabRequested != null) {
              widget.onTabRequested!(tab);
            } else if (mounted && _destination != tab) {
              setState(() => _destination = tab);
            }
          },
        );
        if (mounted && !_hasSpaces) _chooseSpace(const [], null);
      },
      onAccountDeleted: () async {
        await TutorialCoordinator(widget.database).clear(widget.user.uid);
        await OnboardingStore(widget.database).clearDraft(widget.user.uid);
      },
    );
  }

  Future<void> _renameSpace(String spaceId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final updated = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Rename space'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Space name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == null || updated.isEmpty || updated == currentName) return;
    try {
      await widget.backend.callSpaceAction('rename', spaceId, name: updated);
    } catch (_) {
      _message('Could not rename this space. Please retry.');
    }
  }

  Widget _space(
    String? spaceId,
    QueryDocumentSnapshot<Map<String, dynamic>>? space,
  ) {
    final spaceName = space?.data()['name'] as String? ?? 'Your little corner';
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final isLongName = spaceName.length > 16;
    final heroContentHeight = (isLongName ? 164.0 : 132.0) * textScale;
    final heroHeight = topControlsClearance(context) + heroContentHeight;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: heroHeight,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: SoftPop.today,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.only(top: topControlsClearance(context)),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _hero(
                      spaceName,
                      '',
                      supportingLabel: 'Space',
                      maxTitleLines: 2,
                      spaceKind: space?.data()['kind'] as String?,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _page([
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: widget.backend.account(widget.user.uid),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final rawPlus = data?['tier'] == 'plus';
              final isFounder =
                  data?['founderGrant'] == true ||
                  data?['entitlementSource'] == 'founder';
              final expiry = data?['subscriptionExpiresAt'];
              DateTime? expiryDate;
              if (expiry is Timestamp) {
                expiryDate = expiry.toDate();
              } else if (expiry is String) {
                expiryDate = DateTime.tryParse(expiry);
              }
              final plus =
                  rawPlus &&
                  (isFounder ||
                      (expiryDate != null &&
                          expiryDate.isAfter(DateTime.now())));
              return ClayPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        MemberAvatar(
                          uid: widget.user.uid,
                          name:
                              widget.user.displayName?.trim().isNotEmpty == true
                              ? widget.user.displayName!
                              : widget.user.email?.split('@').first ?? 'Member',
                          radius: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final displayName =
                                      widget.user.displayName
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                      ? widget.user.displayName!
                                      : 'Your account';
                                  final scale = MediaQuery.textScalerOf(context)
                                      .scale(16);
                                  final isLargeText = scale > 20;

                                  final planLabel = Semantics(
                                    label: plus ? 'Personal Plus' : 'Basic',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: plus
                                            ? const Color(0xFFFFF3D6)
                                            : const Color(0xFFF1EFEA),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (plus) ...[
                                            const Icon(
                                              Icons.auto_awesome_rounded,
                                              size: 13,
                                              color: Color(0xFF8A6200),
                                            ),
                                            const SizedBox(width: 3),
                                          ],
                                          Text(
                                            plus ? 'Plus' : 'Basic',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: plus
                                                  ? const Color(0xFF8A6200)
                                                  : SoftPop.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );

                                  if (isLargeText) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        planLabel,
                                      ],
                                    );
                                  }

                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          displayName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () {
                                          if (plus) {
                                            _showSubscriptionDetails(context);
                                          } else {
                                            showSoftPopPaywall(context);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: planLabel,
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.user.email ?? '',
                                style: const TextStyle(
                                  color: SoftPop.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Account settings',
                          onPressed: () => _openAccountSettings(spaceId, plus),
                          icon: const Icon(Icons.settings_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: SoftPop.canvas,
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                      ],
                    ),
                    if (!plus) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => showSoftPopPaywall(context),
                          style: TextButton.styleFrom(
                            foregroundColor: SoftPop.blue,
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            alignment: Alignment.centerLeft,
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                          child: const Text('View Plus benefits'),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _showSubscriptionDetails(context),
                          icon: const Icon(Icons.stars_rounded, size: 18),
                          label: const Text('Subscription details'),
                          style: TextButton.styleFrom(
                            foregroundColor: SoftPop.blue,
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            alignment: Alignment.centerLeft,
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          if (spaceId != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: widget.backend.firestore
                  .doc('spaces/$spaceId')
                  .snapshots(),
              builder: (context, spaceSnapshot) {
                final owner = spaceSnapshot.data?.data()?['ownerUid'];
                final pendingOwner = spaceSnapshot.data
                    ?.data()?['pendingOwnerUid'];
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.backend.members(spaceId),
                  builder: (context, members) => ClayPanel(
                    key: owner != widget.user.uid
                        ? TutorialTargetRegistry.spaceTabTarget
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Your people',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (members.hasError)
                          const Text(
                            'Could not load members. Try again when connected.',
                          ),
                        for (final person
                            in members.data?.docs ??
                                <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                          if (person.data()['status'] == 'active')
                            () {
                              final isDependent =
                                  person.data()['isDependent'] == true;
                              final familyRole =
                                  person.data()['familyRole'] as String?;
                              final subtitleText = isDependent
                                  ? (familyRole != null
                                        ? '$familyRole • Dependent'
                                        : 'Dependent')
                                  : (person.id == owner
                                        ? (familyRole != null
                                              ? '$familyRole • Owner'
                                              : 'Owner')
                                        : (familyRole != null
                                              ? '$familyRole • Member'
                                              : 'Member'));
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: MemberAvatar(
                                  uid: person.id,
                                  name:
                                      person.data()['name'] as String? ??
                                      'Member',
                                ),
                                title: Text(
                                  '${person.data()['name'] ?? 'Member'}${person.id == widget.user.uid ? ' (you)' : ''}',
                                ),
                                subtitle: Text(subtitleText),
                                trailing: person.id != widget.user.uid
                                    ? PopupMenuButton<String>(
                                        tooltip:
                                            'Manage ${person.data()['name']}',
                                        itemBuilder: (_) => [
                                          if (owner == widget.user.uid)
                                            const PopupMenuItem(
                                              value: 'removeMember',
                                              child: Text('Remove from space'),
                                            ),
                                          if (owner == widget.user.uid)
                                            const PopupMenuItem(
                                              value: 'offerOwnership',
                                              child: Text('Offer ownership'),
                                            ),
                                          const PopupMenuItem(
                                            value: 'safety',
                                            child: Text('Report or block'),
                                          ),
                                        ],
                                        onSelected: (action) =>
                                            action == 'safety'
                                            ? SafetySheet.member(
                                                context,
                                                widget.backend,
                                                spaceId: spaceId,
                                                memberUid: person.id,
                                                memberName:
                                                    person.data()['name']
                                                        as String? ??
                                                    'Member',
                                              )
                                            : _membershipAction(
                                                action,
                                                spaceId,
                                                memberUid: person.id,
                                                name:
                                                    person.data()['name']
                                                        as String? ??
                                                    'Member',
                                              ),
                                      )
                                    : null,
                              );
                            }(),
                        if (pendingOwner == widget.user.uid) ...[
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => _membershipAction(
                              'acceptOwnership',
                              spaceId,
                              name: 'You',
                            ),
                            child: const Text('Accept ownership'),
                          ),
                        ],
                        if (owner == widget.user.uid) ...[
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            title: const Text(
                              'Require approval to join',
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Review requests before members join',
                              style: TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 12,
                              ),
                            ),
                            value:
                                spaceSnapshot.data
                                    ?.data()?['requireApproval'] ==
                                true,
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: const Color(0xFF244BFF),
                            onChanged: (val) async {
                              try {
                                await widget.backend.setJoinApprovalPolicy(
                                  spaceId,
                                  val,
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Could not update policy: $e',
                                      ),
                                      backgroundColor: const Color(0xFFD32F2F),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: widget.backend.pendingJoins(spaceId),
                            builder: (context, pendingSnapshot) {
                              final pendingDocs =
                                  (pendingSnapshot.data?.docs ?? [])
                                      .where(
                                        (doc) =>
                                            doc.data()['status'] == 'pending',
                                      )
                                      .toList();
                              if (pendingDocs.isEmpty)
                                return const SizedBox.shrink();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(
                                    'Pending requests (${pendingDocs.length})',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  for (final req in pendingDocs)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFFDE68A),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  req.data()['name']
                                                          as String? ??
                                                      'Member',
                                                  style: const TextStyle(
                                                    fontFamily: 'NunitoSans',
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  req.data()['email']
                                                          as String? ??
                                                      '',
                                                  style: const TextStyle(
                                                    fontFamily: 'NunitoSans',
                                                    fontSize: 11,
                                                    color: Color(0xFF596171),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () => widget.backend
                                                .declineJoinRequest(
                                                  spaceId,
                                                  req.id,
                                                ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xFFD32F2F,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                            ),
                                            child: const Text('Decline'),
                                          ),
                                          FilledButton(
                                            onPressed: () => widget.backend
                                                .approveJoinRequest(
                                                  spaceId,
                                                  req.id,
                                                  req.data()['name']
                                                          as String? ??
                                                      'Member',
                                                ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF244BFF,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                            ),
                                            child: const Text('Approve'),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            key: TutorialTargetRegistry.spaceTabTarget,
                            builder: (context, constraints) {
                              final invite = _spaceActionTile(
                                const StewardieInviteIcon(),
                                'Invite members',
                                SoftPop.butter,
                                () => _invite(spaceId),
                              );
                              final routines = _spaceActionTile(
                                const Icon(
                                  Icons.autorenew_rounded,
                                  color: SoftPop.ink,
                                  size: 30,
                                ),
                                'Routines',
                                SoftPop.sky,
                                () {
                                  final memberList = (members.data?.docs ?? [])
                                      .map((d) => {'uid': d.id, ...d.data()})
                                      .toList();
                                  RoutinesSheet.show(
                                    context,
                                    backend: widget.backend,
                                    spaceId: spaceId,
                                    members: memberList,
                                  );
                                },
                              );
                              if (constraints.maxWidth < 310 ||
                                  MediaQuery.textScalerOf(context).scale(16) >
                                      21) {
                                return Column(
                                  children: [
                                    invite,
                                    const SizedBox(height: 12),
                                    routines,
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: invite),
                                  const SizedBox(width: 12),
                                  Expanded(child: routines),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () => _renameSpace(spaceId, spaceName),
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('Rename space'),
                          ),
                          TextButton(
                            onPressed: () {
                              SpaceDeletionSheet.show(
                                context,
                                backend: widget.backend,
                                spaceId: spaceId,
                                spaceName: spaceName,
                                onDeleted: () {
                                  _switchSpace(null);
                                  setState(() => _destination = 0);
                                },
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFD32F2F),
                            ),
                            child: const Text('Delete space'),
                          ),
                        ] else ...[
                          TextButton(
                            onPressed: () => _membershipAction(
                              'leaveSpace',
                              spaceId,
                              name: 'You',
                            ),
                            child: const Text('Leave space'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ], topPadding: heroHeight + 12),
      ],
    );
  }

  void _chooseSpace(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> refs,
    String? selected,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final ref in refs)
            ListTile(
              title: Text(ref.data()['name'] as String? ?? 'Space'),
              trailing: ref.id == selected
                  ? const Icon(
                      Icons.radio_button_checked_rounded,
                      color: SoftPop.blue,
                    )
                  : null,
              onTap: () {
                Navigator.pop(sheet);
                _switchSpace(ref.id);
                setState(() => _destination = 0);
              },
            ),
          const Divider(),
          ListTile(
            minVerticalPadding: 12,
            leading: const Icon(Icons.add_rounded),
            title: const Text('Create a space'),
            onTap: () {
              Navigator.pop(sheet);
              _createSpace();
            },
          ),
          ListTile(
            minVerticalPadding: 12,
            leading: const Icon(Icons.group_add_outlined),
            title: const Text('Join with a code'),
            onTap: () {
              Navigator.pop(sheet);
              _joinSpace();
            },
          ),
        ],
      ),
    ),
  );

  Widget _spaceActionTile(
    Widget icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => Material(
    color: color,
    elevation: 3,
    shadowColor: SoftPop.ink.withValues(alpha: .16),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 88),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: SoftPop.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _notificationBell(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> refs,
  ) => AccountNotificationBell(
    backend: widget.backend,
    uid: widget.user.uid,
    spaceIds: [for (final ref in refs) ref.id],
  );

  Future<void> _openInboxTask(
    BuildContext sheet,
    String spaceId,
    String taskId,
  ) async {
    try {
      final space = await widget.backend.firestore.doc('spaces/$spaceId').get();
      final members = List<String>.from(
        space.data()?['memberUids'] as List? ?? [],
      );
      if (!members.contains(widget.user.uid))
        throw StateError('Space access ended.');
      final result = await widget.backend.call('getTask', {
        'spaceId': spaceId,
        'taskId': taskId,
      });
      final task = Map<String, dynamic>.from(result['task'] as Map);
      final people = await widget.backend.members(spaceId).first;
      if (!mounted || !sheet.mounted) return;
      Navigator.pop(sheet);
      _switchSpace(spaceId);
      setState(() {
        _destination = 0;
        _showDone = task['status'] == 'completed';
      });
      await _openTaskDetail(spaceId, taskId, task, {
        for (final person in people.docs) person.id: person.data(),
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This task is no longer available to you.'),
          ),
        );
      }
    }
  }

  Future<void> _openInboxSpace(
    BuildContext sheet,
    String spaceId, {
    int destination = 2,
  }) async {
    try {
      final space = await widget.backend.firestore.doc('spaces/$spaceId').get();
      if (!List<String>.from(space.data()?['memberUids'] as List? ?? [])
          .contains(widget.user.uid)) {
        throw StateError('Space access ended.');
      }
      if (!mounted || !sheet.mounted) return;
      Navigator.pop(sheet);
      _switchSpace(spaceId);
      setState(() => _destination = destination);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This space is no longer available to you.'),
          ),
        );
      }
    }
  }

  void _showInbox(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> refs,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ActivityInboxSheet(
        backend: widget.backend,
        spaceNames: {
          for (final ref in refs)
            ref.id: ref.data()['name'] as String? ?? 'Space',
        },
        onOpenSpace: (spaceId) =>
            _openInboxSpace(sheet, spaceId, destination: 0),
        onOpenTask: (spaceId, taskId) => _openInboxTask(sheet, spaceId, taskId),
        onOpenOwnership: (spaceId) => _openInboxSpace(sheet, spaceId),
        onOpenMoments: (spaceId) =>
            _openInboxSpace(sheet, spaceId, destination: 1),
        requests: [
          for (final ref in refs) ...[
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.backend.activeTasks(ref.id),
              builder: (context, snapshot) => Column(
                children: [
                  for (final doc
                      in snapshot.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                    if ((doc.data()['status'] == 'requested' &&
                            doc.data()['requestedUid'] == widget.user.uid) ||
                        (doc.data()['offeredUid'] != null &&
                            doc.data()['ownerUid'] == widget.user.uid))
                      ListTile(
                        title: Text(
                          doc.data()['title'] as String? ?? 'Task request',
                        ),
                        subtitle: Text(
                          '${ref.data()['name'] ?? 'Space'} · Awaiting your answer',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openInboxTask(sheet, ref.id, doc.id),
                      ),
                ],
              ),
            ),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: widget.backend.firestore
                  .doc('spaces/${ref.id}')
                  .snapshots(),
              builder: (context, snapshot) =>
                  snapshot.data?.data()?['pendingOwnerUid'] == widget.user.uid
                  ? ListTile(
                      title: const Text('Ownership offer'),
                      subtitle: Text(ref.data()['name'] as String? ?? 'Space'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openInboxSpace(sheet, ref.id),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _createSpace() async {
    final result =
        await showDialog<({String name, String kind, String timeZone})>(
          context: context,
          builder: (_) => const _CreateSpaceDialog(),
        );
    if (result == null) return;
    try {
      await widget.backend.auth.currentUser?.reload();
      await widget.user.getIdToken(true);
      final created = await widget.backend.call('createSpace', {
        'name': result.name,
        'kind': result.kind,
        'timeZone': result.timeZone,
      });
      if (mounted) {
        _switchSpace(created['spaceId'] as String);
        setState(() => _destination = 0);
      }
    } catch (error) {
      _message(_error(error));
    }
  }

  Future<void> _joinSpace() async {
    QrJoinSheet.show(
      context,
      backend: widget.backend,
      onJoined: (newSpaceId) {
        _switchSpace(newSpaceId);
        setState(() => _destination = 0);
        widget.onSpaceSelected?.call(newSpaceId);
      },
    );
  }

  Future<void> _invite(String spaceId) async {
    try {
      final result = await widget.backend.call('createInvite', {
        'spaceId': spaceId,
      });
      final currentCode = result['token'] as String;
      if (!mounted) return;
      QrInviteSheet.show(
        context,
        backend: widget.backend,
        spaceId: spaceId,
        spaceName: 'Space Invite',
        inviteToken: currentCode,
        onRegenerated: (_) {},
      );
    } catch (error) {
      _message(_error(error));
    }
  }

  Future<void> _createTask(
    String spaceId,
    Map<String, Map<String, dynamic>> members,
  ) async {
    final result = await showDialog<({String title, String? requestedUid})>(
      context: context,
      builder: (_) => _CreateTaskDialog(members: members),
    );
    if (result == null) return;
    setState(() => _creating = true);
    try {
      await widget.backend.call('createTask', {
        'spaceId': spaceId,
        'title': result.title,
        if (result.requestedUid != null) 'requestedUid': result.requestedUid,
      });
    } catch (error) {
      _message(_error(error));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _showSubscriptionDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final revenueCat = RevenueCatService.instance;
        final isFounder = revenueCat.isFounder;
        final isSubActive = revenueCat.isSubscriptionActive;
        final store = revenueCat.subscriptionStore;
        final expiry = revenueCat.subscriptionExpiry;
        final productId = revenueCat.subscriptionProductId;
        final isTester =
            isFounder ||
            RevenueCatService.environment == RevenueCatEnvironment.test ||
            const bool.fromEnvironment(
              'ENABLE_TEST_PURCHASES',
              defaultValue: false,
            );

        return Container(
          decoration: const BoxDecoration(
            color: SoftPop.canvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: SoftPop.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: SoftPop.blueSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'STEWARDIE PLUS',
                          style: TextStyle(
                            color: SoftPop.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: SoftPop.secondary,
                        ),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Subscription & Account',
                    style: Theme.of(sheetContext).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isFounder
                        ? 'Founder grant active. Personal Plus benefits are enabled across all your authorized spaces.'
                        : 'Personal Plus is active on your individual account.',
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ClayPanel(
                    color: SoftPop.surface,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _detailRow(
                          'Access tier',
                          isFounder ? 'Founder Plus' : 'Plus Member',
                        ),
                        const Divider(height: 16, color: SoftPop.canvas),
                        _detailRow(
                          'Store subscription',
                          isSubActive
                              ? 'Active'
                              : (expiry != null ? 'Expired' : 'None active'),
                        ),
                        if (store != null) ...[
                          const Divider(height: 16, color: SoftPop.canvas),
                          _detailRow(
                            'Store',
                            store == 'test_store' ? 'Test Store' : store,
                          ),
                        ],
                        if (productId != null) ...[
                          const Divider(height: 16, color: SoftPop.canvas),
                          _detailRow('Product', productId),
                        ],
                        if (expiry != null) ...[
                          const Divider(height: 16, color: SoftPop.canvas),
                          _detailRow(
                            'Renews / Expires',
                            '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Development / Test Store entry for approved testers and founders
                  if (isTester) ...[
                    ClayPanel(
                      color: SoftPop.surface,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.build_circle_outlined,
                                size: 18,
                                color: SoftPop.blue,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Tester Tools (Development)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: SoftPop.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Test purchases and subscription restoration in the development environment.',
                            style: TextStyle(
                              fontSize: 12,
                              color: SoftPop.secondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(sheetContext).pop();
                                    showSoftPopPaywall(context);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: SoftPop.blue,
                                    side: const BorderSide(color: SoftPop.blue),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: const Size(48, 48),
                                  ),
                                  child: const Text('Open Test Store'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    Navigator.of(sheetContext).pop();
                                    final ok = await RevenueCatService.instance
                                        .reconcileWithBackend();
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ok ? 'Subscription synchronized.' : 'Synchronization failed. Try again.',
                                        ),
                                        backgroundColor: SoftPop.blue,
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: SoftPop.ink,
                                    side: const BorderSide(
                                      color: SoftPop.border,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: const Size(48, 48),
                                  ),
                                  child: const Text('Sync with Server'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: SoftPop.secondary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: SoftPop.secondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: SoftPop.ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _OnlineTaskTabHeader extends SliverPersistentHeaderDelegate {
  const _OnlineTaskTabHeader({required this.child, required this.height});
  final Widget child;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: SoftPop.canvas, child: child);
  @override
  bool shouldRebuild(_OnlineTaskTabHeader oldDelegate) => true;
}

class _CreateSpaceDialog extends StatefulWidget {
  const _CreateSpaceDialog();
  @override
  State<_CreateSpaceDialog> createState() => _CreateSpaceDialogState();
}

class _CreateSpaceDialogState extends State<_CreateSpaceDialog> {
  final name = TextEditingController();
  String kind = 'family';
  String timeZone = 'Asia/Manila';
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create a space'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Space name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: kind,
            decoration: const InputDecoration(labelText: 'Space type'),
            items: const [
              DropdownMenuItem(value: 'family', child: Text('Family')),
              DropdownMenuItem(value: 'housemates', child: Text('Housemates')),
              DropdownMenuItem(value: 'friends', child: Text('Friends')),
              DropdownMenuItem(value: 'couple', child: Text('Couple')),
              DropdownMenuItem(
                value: 'organization',
                child: Text('Organization'),
              ),
              DropdownMenuItem(value: 'crew', child: Text('Crew')),
              DropdownMenuItem(value: 'custom', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => kind = value ?? kind),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: timeZone,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Time zone'),
            items: const [
              DropdownMenuItem(value: 'Asia/Manila', child: Text('Manila')),
              DropdownMenuItem(
                value: 'Asia/Singapore',
                child: Text('Singapore'),
              ),
              DropdownMenuItem(value: 'Europe/London', child: Text('London')),
              DropdownMenuItem(
                value: 'America/New_York',
                child: Text('New York'),
              ),
              DropdownMenuItem(
                value: 'America/Los_Angeles',
                child: Text('Los Angeles'),
              ),
              DropdownMenuItem(value: 'UTC', child: Text('UTC')),
            ],
            onChanged: (value) => setState(() => timeZone = value ?? timeZone),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, (
                name: name.text.trim(),
                kind: kind,
                timeZone: timeZone,
              )),
        child: const Text('Create'),
      ),
    ],
  );
}

class _JoinSpaceDialog extends StatefulWidget {
  const _JoinSpaceDialog({required this.backend});
  final OnlineBackend backend;
  @override
  State<_JoinSpaceDialog> createState() => _JoinSpaceDialogState();
}

class _JoinSpaceDialogState extends State<_JoinSpaceDialog> {
  final code = TextEditingController();
  bool checking = false;
  String? preview;
  String? error;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Join a space'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: code,
          onChanged: (_) => setState(() {
            preview = null;
            error = null;
          }),
          decoration: const InputDecoration(
            labelText: 'Invitation code or link',
            hintText: 'e.g. KMXPQR or paste link',
          ),
        ),
        if (checking)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: LinearProgressIndicator(),
          ),
        if (preview != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text('You’re joining $preview.'),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (preview == null)
        FilledButton(
          onPressed: checking || InviteLinks.sanitize(code.text).isEmpty
              ? null
              : () async {
                  final token = InviteLinks.sanitize(code.text);
                  setState(() {
                    checking = true;
                    error = null;
                  });
                  try {
                    final result = await widget.backend.call('previewInvite', {
                      'token': token,
                    });
                    if (mounted) {
                      setState(() => preview = result['spaceName'] as String);
                    }
                  } catch (_) {
                    if (mounted) {
                      setState(() => error = 'That invitation is unavailable.');
                    }
                  } finally {
                    if (mounted) setState(() => checking = false);
                  }
                },
          child: const Text('Preview'),
        )
      else
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, InviteLinks.sanitize(code.text)),
          child: const Text('Join'),
        ),
    ],
  );
}

class _CreateTaskDialog extends StatefulWidget {
  const _CreateTaskDialog({required this.members});
  final Map<String, Map<String, dynamic>> members;
  @override
  State<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<_CreateTaskDialog> {
  final title = TextEditingController();
  String? requestedUid;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a task'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: title,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'What needs doing?'),
        ),
        DropdownButtonFormField<String?>(
          initialValue: requestedUid,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ask someone'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Open to everyone'),
            ),
            for (final entry in widget.members.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(
                  entry.value['name'] as String? ?? 'Member',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => requestedUid = value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: title.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, (
                title: title.text.trim(),
                requestedUid: requestedUid,
              )),
        child: const Text('Add'),
      ),
    ],
  );
}
