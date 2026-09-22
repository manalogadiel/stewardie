import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clay.dart';
import '../../../core/equal_height_row.dart';
import '../../../core/demo_state.dart';
import '../../../core/people_filter.dart';
import '../../../core/theme.dart';
import '../../../core/top_controls.dart';
import '../../../core/person_labels.dart';
import '../../calendar/calendar_view.dart';
import '../../moods/mood_sheet.dart';
import '../../moods/mood_presentation.dart';
import '../domain/models.dart';
import 'task_widgets.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});
  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  final scroll = ScrollController();
  final offsets = <String, double>{};
  bool showDone = false;
  int historyDay = 0;
  String scope = '';
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void selectTab(bool done) {
    if (done == showDone) return;
    offsets['$scope/$showDone'] = scroll.offset;
    final target = offsets['$scope/$done'] ?? scroll.offset;
    setState(() => showDone = done);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.jumpTo(target.clamp(0, scroll.position.maxScrollExtent));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoProvider);
    final repo = ref.read(repositoryProvider);
    final space = repo.spaces.firstWhere((s) => s.id == state.spaceId);
    final currentScope = '${space.id}/${state.personId}';
    if (scope != currentScope) {
      scope = currentScope;
      showDone = false;
      historyDay = 0;
    }
    final now = DateTime.now(), today = dateOnly(DateTime.now());
    final tasks = state.tasks
        .where(
          (t) =>
              t.spaceId == space.id &&
              !t.isEvent &&
              t.matchesPerson(state.personId) &&
              visibleToBasic(t, now),
        )
        .toList();
    final active = tasks
        .where((t) => !t.isDone && !dateOnly(t.day).isAfter(today))
        .toList();
    final pending = active
        .where((t) => t.status != Responsibility.accepted)
        .toList()
        .reversed
        .toList();
    final covered =
        active.where((t) => t.status == Responsibility.accepted).toList()
          ..sort((a, b) => (a.hour ?? 25).compareTo(b.hour ?? 25));
    final completionDay = DateTime(
      today.year,
      today.month,
      today.day - historyDay,
    );
    final completed =
        tasks
            .where(
              (t) =>
                  t.isDone && dateOnly(t.completedAt ?? t.day) == completionDay,
            )
            .toList()
          ..sort(
            (a, b) =>
                (b.completedAt ?? b.day).compareTo(a.completedAt ?? a.day),
          );
    final doneToday = tasks
        .where((t) => t.isDone && dateOnly(t.completedAt ?? t.day) == today)
        .length;
    final large = MediaQuery.textScalerOf(context).scale(16) > 22;
    final moodSubject = state.personId == null || state.personId == 'me'
        ? 'me'
        : state.personId!;
    final isMyMood = moodSubject == 'me';
    final mood = repo.checkIn(space.id, moodSubject);
    final moodCard = ClayPanel(
      color: moodSurface(mood?.color ?? MoodColor.sky),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => isMyMood
            ? showMoodSheet(context, space)
            : showMemberMoodSheet(
                context,
                space,
                space.member(moodSubject),
                mood,
              ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CompactPersonTitle(
                space: space,
                personId: isMyMood ? 'me' : moodSubject,
                noun: 'mood',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Center(
                child: mood == null && !isMyMood
                    ? const SizedBox(
                        height: 92,
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 56,
                          color: SoftPop.secondary,
                        ),
                      )
                    : ClayArt(
                        moodArtName(
                          mood?.mood ?? Mood.calm,
                          mood?.color ?? MoodColor.sky,
                        ),
                        height: 92,
                      ),
              ),
              Text(
                mood?.mood.label ??
                    (isMyMood ? 'How are you?' : 'No check-in yet'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isMyMood
                          ? mood == null
                                ? 'Check in'
                                : 'Update mood'
                          : 'View mood',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: SoftPop.blue),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: SoftPop.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: CustomScrollView(
          key: const ValueKey('today-scroll'),
          controller: scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  ClayPanel(
                    color: SoftPop.today,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      topControlsClearance(context),
                      16,
                      18,
                    ),
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
                                    .formatMediumDate(today),
                              ),
                              const SizedBox(height: 8),
                              const Text('Little things, together.'),
                            ],
                          ),
                        ),
                        if (!large)
                          const ClayArt('greeting', height: 112, width: 154),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: PeopleFilter(space),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: large
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              moodCard,
                              const SizedBox(height: 12),
                              CalendarTile(space),
                            ],
                          )
                        : EqualHeightRow(
                            children: [moodCard, CalendarTile(space)],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        _stat(pending.length, 'Help', SoftPop.butter),
                        const SizedBox(width: 10),
                        _stat(covered.length, 'Covered', SoftPop.sky),
                        const SizedBox(width: 10),
                        _stat(doneToday, 'Done', SoftPop.rose),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TaskTabHeader(
                height: large ? 108 : 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _tab('Pending', active.length, false)),
                      const SizedBox(width: 4),
                      Expanded(child: _tab('Done', doneToday, true)),
                      const SizedBox(width: 8),
                      Center(
                        child: IconButton.filled(
                          tooltip: 'Add task',
                          onPressed: () {
                            selectTab(false);
                            showAddTask(context, space);
                          },
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                120 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverList.list(
                children: [
                  if (showDone) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < 4; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(
                                  i == 0
                                      ? 'Today'
                                      : i == 1
                                      ? 'Yesterday'
                                      : MaterialLocalizations.of(context)
                                            .formatShortDate(
                                              DateTime(
                                                today.year,
                                                today.month,
                                                today.day - i,
                                              ),
                                            ),
                                ),
                                selected: historyDay == i,
                                onSelected: (_) =>
                                    setState(() => historyDay = i),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (completed.isEmpty)
                      _empty(
                        'A fresh start',
                        'Finished tasks will find a home here.',
                      ),
                    for (final task in completed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TaskCard(task: task, space: space),
                      ),
                  ] else ...[
                    if (active.isEmpty)
                      _empty(
                        'A little breathing room',
                        'All clear for now. Enjoy a moment for yourself.',
                      ),
                    if (pending.isNotEmpty) ...[
                      _section('Pending', pending.length),
                      for (final task in pending)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TaskCard(task: task, space: space),
                        ),
                    ],
                    if (covered.isNotEmpty) ...[
                      _section('Covered', covered.length),
                      for (final task in covered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TaskCard(task: task, space: space),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(int count, String label, Color color) => Expanded(
    child: Column(
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 42, minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text('$count', style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 6),
        Text(label),
      ],
    ),
  );
  Widget _tab(String title, int count, bool done) => Semantics(
    selected: showDone == done,
    child: Material(
      color: showDone == done ? SoftPop.surface : const Color(0xFFECEBE8),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: InkWell(
        onTap: () => selectTab(done),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(
              '$title ($count)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: showDone == done ? SoftPop.blue : SoftPop.secondary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _section(String name, int count) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 12),
    child: Text(
      '$name · $count',
      style: Theme.of(context).textTheme.titleMedium,
    ),
  );
  Widget _empty(String title, String subtitle) => ClayPanel(
    child: Column(
      children: [
        const ClayArt('celebrate', height: 130),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _TaskTabHeader extends SliverPersistentHeaderDelegate {
  _TaskTabHeader({required this.child, required this.height});
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
  bool shouldRebuild(_TaskTabHeader old) => true;
}
