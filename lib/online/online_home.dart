import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart' show GlassDock;
import '../core/clay.dart';
import '../core/theme.dart';
import '../core/top_controls.dart';
import 'online_backend.dart';
import 'online_moments.dart';
import 'online_today_extras.dart';

class OnlineHome extends StatefulWidget {
  const OnlineHome({super.key, required this.backend, required this.user});
  final OnlineBackend backend;
  final User user;

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

  void _invalidateHistory() {
    _historyKey = null;
    _historyFuture = null;
    _moreDone.clear();
    _moreCursor = null;
  }

  void _switchSpace(String? id) => setState(() {
    _spaceId = id;
    _personId = null;
    _showDone = false;
    _invalidateHistory();
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
          final selected = refs.any((doc) => doc.id == _spaceId)
              ? _spaceId
              : (refs.isEmpty ? null : refs.first.id);
          final space = selected == null
              ? null
              : refs.firstWhere((doc) => doc.id == selected);
          return Scaffold(
            extendBody: true,
            body: Stack(
              children: [
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
                          const SizedBox(width: 48),
                          Expanded(
                            child: Center(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: SoftPop.surface,
                                  shape: const StadiumBorder(),
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: refs.isEmpty
                                    ? _showSpaceActions
                                    : () => _chooseSpace(refs, selected),
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
                              tooltip: 'Inbox',
                              style: IconButton.styleFrom(
                                backgroundColor: SoftPop.surface,
                                shape: const CircleBorder(),
                              ),
                              onPressed: selected == null
                                  ? null
                                  : () => _showInbox(selected),
                              icon: const Icon(Icons.inbox_outlined),
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
                          child: GlassDock(
                            index: _destination,
                            onSelected: (index) =>
                                setState(() => _destination = index),
                          ),
                        ),
                      ),
                    ),
                  ),
          );
        },
      );

  Widget _page(List<Widget> children) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 96, 20, 148),
        children: children,
      ),
    ),
  );

  Widget _today(
    String? spaceId,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> spaceSnapshot,
  ) {
    if (spaceSnapshot.hasError) {
      return _page([
        const Text('Could not open your spaces. Check your connection.'),
      ]);
    }
    if (!spaceSnapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (spaceId == null) {
      return _page([
        _hero('Today', 'A shared space starts here.'),
        const SizedBox(height: 22),
        _emptyPanel(
          'Bring your people together',
          'Create a space or join one you have been invited to.',
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _createSpace,
          child: const Text('Create a space'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _joinSpace,
          child: const Text('Join with a code'),
        ),
      ]);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.backend.members(spaceId),
      builder: (context, peopleSnapshot) {
        if (peopleSnapshot.hasError) {
          return _page([
            const Text('Could not load the people in this space.'),
          ]);
        }
        final members = <String, Map<String, dynamic>>{
          for (final doc in peopleSnapshot.data?.docs ?? [])
            if (doc.data()['status'] == 'active') doc.id: doc.data(),
        };
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.backend.activeTasks(spaceId),
          builder: (context, taskSnapshot) {
            if (taskSnapshot.hasError) {
              return _page([
                const Text('Could not load tasks. Try again when connected.'),
              ]);
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
                final done = [...firstPage, ..._moreDone];
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
                  summary: [
                    const SizedBox(height: 16),
                    _peopleFilters(members),
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
    required List<Widget> summary,
    required Widget tabs,
    required List<Widget> tasks,
  }) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ClayPanel(
              color: SoftPop.today,
              padding: EdgeInsets.fromLTRB(
                20,
                topControlsClearance(context),
                16,
                18,
              ),
              radius: const BorderRadius.vertical(bottom: Radius.circular(28)),
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
                  if (MediaQuery.textScalerOf(context).scale(16) <= 22)
                    const ClayArt('greeting', height: 112, width: 154),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: summary,
              ),
            ),
          ),
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

  Widget _hero(String title, String subtitle) => Material(
    color: SoftPop.today,
    borderRadius: const BorderRadius.only(
      bottomLeft: Radius.circular(28),
      bottomRight: Radius.circular(28),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 16, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 6),
                Text(subtitle),
              ],
            ),
          ),
          const ClayArt('greeting', height: 94, width: 104),
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
            _personChip(widget.user.uid, 'Me'),
            for (final entry in members.entries)
              if (entry.key != widget.user.uid)
                _personChip(
                  entry.key,
                  entry.value['name'] as String? ?? 'Member',
                ),
          ],
        ),
      );

  Widget _personChip(String? id, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: ChoiceChip(
        showCheckmark: false,
        avatar: id == null
            ? null
            : CircleAvatar(
                radius: 13,
                backgroundColor: SoftPop.sky,
                child: Text(
                  label.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: SoftPop.ink),
                ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClayPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task['title'] as String? ?? 'Task',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(label),
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
                          : () => _act(spaceId, taskId, action.$1),
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
    );
  }

  Widget _moments(
    String? spaceId,
    QueryDocumentSnapshot<Map<String, dynamic>>? space,
  ) {
    if (spaceId == null) {
      return _page([
        _hero('Little moments', 'A space for the good bits.'),
        const SizedBox(height: 20),
        _emptyPanel('Make a space first', 'Your moments belong to a space.'),
      ]);
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

  Widget _space(
    String? spaceId,
    QueryDocumentSnapshot<Map<String, dynamic>>? space,
  ) => _page([
    _hero('Space', space?.data()['name'] as String? ?? 'Your little corner'),
    const SizedBox(height: 22),
    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.backend.account(widget.user.uid),
      builder: (context, snapshot) {
        final tier = snapshot.data?.data()?['tier'] as String?;
        return ClayPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.user.displayName ?? 'Your account',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Chip(
                    label: Text(
                      tier == null
                          ? 'Loading'
                          : tier == 'plus'
                          ? 'Plus'
                          : 'Basic',
                    ),
                  ),
                ],
              ),
              Text(widget.user.email ?? ''),
              TextButton(
                onPressed: widget.backend.auth.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        );
      },
    ),
    const SizedBox(height: 14),
    if (spaceId != null)
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.backend.members(spaceId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _emptyPanel(
              'Could not load members',
              'Try again when connected.',
            );
          }
          return ClayPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your people',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                for (final member in snapshot.data?.docs ?? [])
                  if (member.data()['status'] == 'active')
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: SoftPop.sky,
                        child: Text(
                          (member.data()['name'] as String? ?? 'M')
                              .substring(0, 1)
                              .toUpperCase(),
                        ),
                      ),
                      title: Text(
                        member.id == widget.user.uid
                            ? '${member.data()['name']} (you)'
                            : member.data()['name'] as String? ?? 'Member',
                      ),
                      subtitle: Text(
                        member.data()['role'] as String? ?? 'member',
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    const SizedBox(height: 18),
    FilledButton.icon(
      onPressed: _createSpace,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Create a space'),
    ),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      onPressed: _joinSpace,
      icon: const Icon(Icons.group_add_outlined),
      label: const Text('Join with a code'),
    ),
    if (spaceId != null) ...[
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _invite(spaceId),
        icon: const Icon(Icons.ios_share_rounded),
        label: const Text('Invite someone'),
      ),
    ],
  ]);

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
                  ? const Icon(Icons.check_rounded, color: SoftPop.blue)
                  : null,
              onTap: () {
                Navigator.pop(sheet);
                _switchSpace(ref.id);
                setState(() => _destination = 0);
              },
            ),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: const Text('Create or join a space'),
            onTap: () {
              Navigator.pop(sheet);
              _showSpaceActions();
            },
          ),
        ],
      ),
    ),
  );

  void _showSpaceActions() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: const Text('Create a space'),
            onTap: () {
              Navigator.pop(sheet);
              _createSpace();
            },
          ),
          ListTile(
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

  void _showInbox(String spaceId) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.backend.activeTasks(spaceId),
        builder: (context, snapshot) {
          final requests = (snapshot.data?.docs ?? [])
              .where(
                (doc) =>
                    doc.data()['status'] == 'requested' &&
                    doc.data()['requestedUid'] == widget.user.uid,
              )
              .toList();
          return ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Inbox')),
              if (requests.isEmpty)
                const ListTile(title: Text('You’re all caught up.')),
              for (final doc in requests)
                ListTile(
                  title: Text(doc.data()['title'] as String? ?? 'Task'),
                  subtitle: const Text('Awaiting your acceptance'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheet);
                    setState(() {
                      _destination = 0;
                      _showDone = false;
                    });
                  },
                ),
            ],
          );
        },
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
    final code = await showDialog<String>(
      context: context,
      builder: (_) => _JoinSpaceDialog(backend: widget.backend),
    );
    if (code == null) return;
    try {
      final result = await widget.backend.call('redeemInvite', {'token': code});
      if (mounted) {
        _switchSpace(result['spaceId'] as String);
        setState(() => _destination = 0);
      }
    } catch (error) {
      _message(_error(error));
    }
  }

  Future<void> _invite(String spaceId) async {
    try {
      final result = await widget.backend.call('createInvite', {
        'spaceId': spaceId,
      });
      final code = result['token'] as String;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Invite someone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share this code with someone you trust. It expires in 7 days.',
              ),
              const SizedBox(height: 14),
              SelectableText(
                code,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (dialog.mounted) Navigator.pop(dialog);
                _message('Code copied.');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy'),
            ),
          ],
        ),
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
          decoration: const InputDecoration(labelText: 'Invitation code'),
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
          onPressed: checking || code.text.trim().isEmpty
              ? null
              : () async {
                  setState(() {
                    checking = true;
                    error = null;
                  });
                  try {
                    final result = await widget.backend.call('previewInvite', {
                      'token': code.text.trim(),
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
          onPressed: () => Navigator.pop(context, code.text.trim()),
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
