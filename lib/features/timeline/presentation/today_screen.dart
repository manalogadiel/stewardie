import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/demo_state.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../moods/mood_sheet.dart';
import '../domain/models.dart';
import 'task_detail.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});
  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool week = false;
  DateTime selectedDay = dateOnly(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoProvider);
    final repo = ref.read(repositoryProvider);
    final space = repo.spaces.firstWhere((space) => space.id == state.spaceId);
    final now = DateTime.now();
    final today = dateOnly(now);
    final day = week ? selectedDay : today;
    final tasks = state.tasks.where((task) => task.spaceId == space.id &&
      visibleToBasic(task, now) && task.matchesPerson(state.personId) &&
      (dateOnly(task.day) == day || (!week && !task.isDone && task.day.isBefore(today)))).toList()
      ..sort((a, b) {
        final hourCompare = (a.hour ?? 25).compareTo(b.hour ?? 25);
        return hourCompare != 0 ? hourCompare : a.minute.compareTo(b.minute);
      });
    final active = tasks.where((task) => !task.isDone).toList();
    final done = tasks.where((task) => task.isDone).toList();
    final help = active.where((task) => task.status == Responsibility.needsHelp).toList();
    final needs = active.where((task) => !task.isEvent &&
      (task.status == Responsibility.unclaimed || task.status == Responsibility.requested)).length;
    final covered = active.where((task) => !task.isEvent && task.ownerId != null).length;
    final mood = repo.checkIn(space.id, 'me');
    return PageBody(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
      const DemoNotice(),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Text(week ? 'This week' : 'Today', style: Theme.of(context).textTheme.headlineLarge)),
        TextButton(onPressed: () => setState(() { week = !week; selectedDay = today; }),
          child: Text(week ? 'Back to today' : 'View week')),
      ]),
      Text(MaterialLocalizations.of(context).formatFullDate(day), style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 20),
      if (week) ...[
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(7, (index) {
          final date = DateTime(today.year, today.month, today.day - today.weekday + 1 + index);
          return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
            label: Text(MaterialLocalizations.of(context).formatShortDate(date)),
            selected: date == selectedDay, onSelected: (_) => setState(() => selectedDay = date)));
        }))), const SizedBox(height: 16),
      ],
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _filter('Everyone', null, state.personId, null),
        for (final member in space.members) _filter(member.id == 'me' ? 'Me' : member.name,
          member.id, state.personId, member),
      ])),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: mood == null ? const Text('A shared day, a little lighter.') : Row(children: [
          MoodFace(mood.mood, size: 24), const SizedBox(width: 8),
          Expanded(child: Text('You · ${mood.mood.label}\n${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(mood.sharedAt))} · Today')),
        ])),
        TextButton.icon(onPressed: () => showMoodSheet(context, space),
          icon: const Icon(Icons.add_reaction_outlined, size: 20), label: Text(mood == null ? 'Check in' : 'Update mood')),
      ]),
      const SizedBox(height: 16),
      Paper(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), child: Wrap(
        spacing: 20, runSpacing: 12, children: [
          _count(needs, 'needs someone', SoftPop.butter),
          _count(covered, 'covered', SoftPop.sky), _count(done.length, 'done', SoftPop.rose),
        ])),
      if (help.isNotEmpty) ...[
        const SizedBox(height: 20),
        Paper(color: SoftPop.blueSoft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.front_hand_outlined, color: SoftPop.blue), const SizedBox(width: 12),
            Expanded(child: Text(help.length > 1 ? 'A little help goes a long way' : '${personName(space, help.first.ownerId)} could use a hand',
              style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 8), Text(help.length > 1 ? '${help.length} tasks could use a hand. Owners stay responsible until a handoff is confirmed.' : help.first.title),
          const SizedBox(height: 8), TextButton(onPressed: () => _showHelp(context, help, space),
            child: Text(help.length > 1 ? 'View help requests' : 'View request')),
        ])),
      ],
      const SizedBox(height: 24),
      Row(children: [Expanded(child: Text(state.personId == null ? 'Our day' : '${personName(space, state.personId)} · Plans',
        style: Theme.of(context).textTheme.titleLarge)), Text('${tasks.length} entries')]),
      const SizedBox(height: 16),
      if (tasks.isEmpty) Paper(color: SoftPop.warm, child: Column(children: [
        const Icon(Icons.wb_sunny_outlined, size: 40, color: SoftPop.blue), const SizedBox(height: 16),
        Text('A little breathing room', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
        Text(state.personId == null ? 'No plans here yet. Add a little thing to get started.' : 'No plans for this person on this day.', textAlign: TextAlign.center),
        if (state.personId != null) TextButton(onPressed: () => ref.read(demoProvider.notifier).selectPerson(null), child: const Text('Show everyone')),
      ])),
      for (var i = 0; i < active.length; i++) ...[
        if (i == 0 || taskTime(context, active[i]) != taskTime(context, active[i - 1]))
          Padding(padding: const EdgeInsets.only(bottom: 10, top: 4), child: Text(taskTime(context, active[i]),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: SoftPop.secondary))),
        TaskCard(task: active[i], space: space), const SizedBox(height: 16),
      ],
      if (done.isNotEmpty) ExpansionTile(initiallyExpanded: done.length <= 2, tilePadding: EdgeInsets.zero,
        title: Text('Done & dusted · ${done.length}', style: Theme.of(context).textTheme.titleMedium),
        children: [for (final task in done) Padding(padding: const EdgeInsets.only(bottom: 12), child: TaskCard(task: task, space: space))]),
    ]);
  }

  Widget _filter(String label, String? id, String? selected, Member? member) => Padding(
    padding: const EdgeInsets.only(right: 8), child: FilterChip(selected: id == selected,
      avatar: member == null ? null : MemberAvatar(member, size: 26),
      label: Text(label), onSelected: (_) => ref.read(demoProvider.notifier).selectPerson(id)));

  Widget _count(int value, String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 8), Text('$value ', style: Theme.of(context).textTheme.titleMedium), Text(label),
  ]);

  Future<void> _showHelp(BuildContext context, List<Task> tasks, Space space) => showModalBottomSheet<void>(
    context: context, useSafeArea: true, isScrollControlled: true,
    builder: (sheetContext) => ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(20), children: [
        Text('A hand for ${space.name}', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
        for (final task in tasks) ListTile(contentPadding: EdgeInsets.zero,
          title: Text(task.title), subtitle: Text('${personName(space, task.ownerId)} · ${task.offeredId == null ? 'Needs help' : 'Handoff pending'}'),
          trailing: const Icon(Icons.chevron_right_rounded), onTap: () {
            Navigator.pop(sheetContext); context.push('/task/${task.id}');
          }),
      ])));
}

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.space});
  final Task task;
  final Space space;
  @override
  Widget build(BuildContext context) => Material(color: SoftPop.surface,
    borderRadius: BorderRadius.circular(20), clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: () => context.push('/task/${task.id}'),
      child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(task.title, style: Theme.of(context).textTheme.titleMedium)),
          const SizedBox(width: 8), const Icon(Icons.chevron_right_rounded, color: SoftPop.secondary),
        ]),
        const SizedBox(height: 12),
        if (task.isEvent) Text(task.participants.map((id) => personName(space, id)).join(' · '))
        else Row(children: [
          if (task.ownerId ?? task.requestedId case final String id) ...[
            MemberAvatar(space.member(id), size: 28), const SizedBox(width: 8),
          ],
          Expanded(child: Text(personName(space, task.ownerId ?? task.requestedId),
            style: Theme.of(context).textTheme.bodyLarge)),
        ]),
        const SizedBox(height: 8), StatusLabel(task),
        if (!task.isDone && task.day.isBefore(dateOnly(DateTime.now()))) const Padding(
          padding: EdgeInsets.only(top: 8), child: Text('Overdue · Still here when you’re ready')),
        if (task.place != null) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
          const Icon(Icons.place_outlined, size: 16, color: SoftPop.secondary), const SizedBox(width: 6),
          Expanded(child: Text(task.place!)),
        ])),
        if ((task.ownerId == 'me' && !task.isDone) || task.requestedId == 'me') ...[
          const SizedBox(height: 16), TaskActions(task: task, compact: true),
        ],
      ]))));
}

Future<void> showAddTask(BuildContext context, Space space) => showModalBottomSheet<void>(
  context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _AddTask(space));

class _AddTask extends ConsumerStatefulWidget {
  const _AddTask(this.space);
  final Space space;
  @override
  ConsumerState<_AddTask> createState() => _AddTaskState();
}

class _AddTaskState extends ConsumerState<_AddTask> {
  final title = TextEditingController();
  final form = GlobalKey<FormState>();
  bool mine = false;
  @override
  void dispose() { title.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: SafeArea(top: false,
      child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('One little thing', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8), Text('Today in ${widget.space.name} · Local demo'), const SizedBox(height: 20),
        TextFormField(controller: title, maxLength: 100, textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Task name', hintText: 'What needs doing?'),
          validator: (value) => value == null || value.trim().isEmpty ? 'Give your task a name.' : null),
        CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('I’ve got this one'),
          subtitle: const Text('Otherwise, leave it for someone to claim.'), value: mine,
          onChanged: (value) => setState(() => mine = value!)), const SizedBox(height: 16),
        FilledButton(onPressed: () {
          if (!form.currentState!.validate()) { return; }
          ref.read(repositoryProvider).addTask(widget.space.id, title.text, DateTime.now(), mine);
          ref.read(demoProvider.notifier).selectPerson(null);
          ref.read(demoProvider.notifier).refresh(); Navigator.pop(context);
        }, child: const Text('Add task')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ])))));
}
