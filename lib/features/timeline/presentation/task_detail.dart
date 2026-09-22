import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/demo_state.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../domain/models.dart';

class TaskDetail extends ConsumerWidget {
  const TaskDetail({super.key, required this.taskId});
  final String taskId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoProvider);
    final task = state.tasks.where((task) => task.id == taskId && task.spaceId == state.spaceId).firstOrNull;
    final space = ref.read(repositoryProvider).spaces.firstWhere((space) => space.id == state.spaceId);
    return Scaffold(appBar: AppBar(leading: IconButton(tooltip: 'Back to Today',
      onPressed: () => context.canPop() ? context.pop() : context.go('/today'),
      icon: const Icon(Icons.arrow_back_rounded)), title: Text(space.name)),
      body: task == null ? const Center(child: Text('This task is unavailable in this space.')) : PageBody(children: [
        const DemoNotice(),
        Text(task.isEvent ? 'TOGETHER TIME' : 'THE LITTLE THINGS', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8), Text(task.title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 16),
        Text('${MaterialLocalizations.of(context).formatMediumDate(task.day)} · ${taskTime(context, task)}',
          style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        Paper(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.isEvent ? 'Who’s coming' : 'Responsibility', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (task.isEvent) Wrap(spacing: 12, runSpacing: 12, children: task.participants.map((id) =>
            Chip(avatar: MemberAvatar(space.member(id)), label: Text(personName(space, id)))).toList())
          else ...[
            Text(personName(space, task.ownerId ?? task.requestedId), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8), StatusLabel(task),
            if (task.status == Responsibility.requested) const Padding(padding: EdgeInsets.only(top: 12),
              child: Text('A request is an invitation. Responsibility starts when it is accepted.')),
            if (task.offeredId != null) Padding(padding: const EdgeInsets.only(top: 12),
              child: Text('${personName(space, task.offeredId)} offered to help. ${personName(space, task.ownerId)} stays responsible until the handoff is confirmed.')),
          ],
        ])),
        if (task.notes.isNotEmpty) ...[
          const SizedBox(height: 24), Text('A little context', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8), Text(task.notes, style: Theme.of(context).textTheme.bodyLarge),
        ],
        if (task.place != null) ...[
          const SizedBox(height: 20), Paper(color: SoftPop.warm, child: Row(children: [
            const Icon(Icons.place_outlined), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.place!, style: Theme.of(context).textTheme.labelLarge),
              const Text('Demo destination · Maps are not connected'),
            ])),
          ])),
        ],
        const SizedBox(height: 24), TaskActions(task: task),
        if (task.isDone) ...[
          const SizedBox(height: 12),
          const Text('Done in this demo. A photo is always optional.'),
          OutlinedButton.icon(onPressed: () => showFeatureNote(context, 'Photos come later',
            'This slice has no camera, gallery, or uploads. Your task is already done in the local demo.'),
            icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Add a photo')),
        ],
        const SizedBox(height: 24), Text('Activity', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Created by ${personName(space, task.creatorId)} · Demo history'),
        for (final entry in task.activity) Padding(padding: const EdgeInsets.only(top: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.history_rounded, size: 18, color: SoftPop.secondary),
            const SizedBox(width: 10), Expanded(child: Text(entry)),
          ])),
      ]));
  }
}

class TaskActions extends ConsumerWidget {
  const TaskActions({super.key, required this.task, this.compact = false});
  final Task task;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (task.isEvent) { return const SizedBox.shrink(); }
    final state = ref.watch(demoProvider);
    final busy = state.pending.contains(task.id);
    final error = state.errors[task.id];
    final actions = <(TaskAction, String)>[
      if (task.status == Responsibility.unclaimed) (TaskAction.accept, 'I’ve got it'),
      if (task.status == Responsibility.requested && task.requestedId == 'me') ...[
        (TaskAction.accept, 'Accept task'), if (!compact) (TaskAction.decline, 'Decline'),
      ],
      if (task.ownerId == 'me' && !task.isDone) ...[
        if (task.offeredId != null) (TaskAction.confirmHandoff, 'Confirm handoff'),
        (TaskAction.complete, 'Mark done'),
        if (!compact && task.status == Responsibility.accepted) (TaskAction.needHelp, 'Need help'),
      ],
      if (task.status == Responsibility.needsHelp && task.ownerId != 'me' && task.offeredId == null)
        (TaskAction.offerHelp, 'Offer help'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (busy) const Semantics(liveRegion: true, child: Paper(color: SoftPop.blueSoft,
        padding: EdgeInsets.all(12), child: Text('Pending demo action… Nothing has synced to anyone.'))),
      if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(liveRegion: true, child: Text(error, style: const TextStyle(color: SoftPop.ink)))),
      for (var i = 0; i < (compact && actions.isNotEmpty ? 1 : actions.length); i++)
        Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 8), child: i == 0 ? FilledButton(
          onPressed: busy ? null : () => ref.read(demoProvider.notifier).act(task, actions[i].$1),
          child: Text(actions[i].$2)) : OutlinedButton(
          onPressed: busy ? null : () => ref.read(demoProvider.notifier).act(task, actions[i].$1),
          child: Text(actions[i].$2))),
      if (task.offeredId == 'me') const Padding(padding: EdgeInsets.only(top: 8),
        child: Text('Your offer is waiting for the owner. No other member is online in this demo.')),
    ]);
  }
}
