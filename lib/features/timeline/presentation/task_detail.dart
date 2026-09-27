import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/demo_state.dart';
import '../../../core/backend_provider.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../media/photo_composer.dart';
import '../../media/photo_viewer.dart';
import '../../../online/external_launcher.dart';
import '../../../online/safety_sheet.dart';
import '../domain/models.dart';

class TaskDetail extends ConsumerWidget {
  const TaskDetail({super.key, required this.taskId});
  final String taskId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoProvider);
    final task = state.tasks
        .where(
          (task) =>
              task.id == taskId &&
              task.spaceId == state.spaceId &&
              ref.read(repositoryProvider).canView(task),
        )
        .firstOrNull;
    final space = ref
        .read(repositoryProvider)
        .spaces
        .where((space) => space.id == state.spaceId)
        .firstOrNull;
    if (space == null) {
      return const Scaffold(
        body: Center(child: Text('This space is no longer available.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to Today',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/today'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(space.name),
      ),
      body: task == null
          ? const Center(child: Text('This task is unavailable in this space.'))
          : PageBody(
              children: [
                Text(
                  task.isEvent ? 'Together time' : 'The little things',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  '${MaterialLocalizations.of(context).formatMediumDate(task.day)} · ${taskTime(context, task)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Paper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.isEvent ? 'Who’s coming' : 'Responsibility',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (task.isEvent)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: task.participants
                              .map(
                                (id) => Chip(
                                  avatar: MemberAvatar(space.member(id)),
                                  label: Text(personName(space, id)),
                                ),
                              )
                              .toList(),
                        )
                      else ...[
                        Text(
                          personName(space, task.ownerId ?? task.requestedId),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        StatusLabel(task),
                        if (task.status == Responsibility.requested)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'A request is an invitation. Responsibility starts when it is accepted.',
                            ),
                          ),
                        if (task.offeredId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              '${personName(space, task.offeredId)} offered to help. ${personName(space, task.ownerId)} stays responsible until the handoff is confirmed.',
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (task.notes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'A little context',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task.notes,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                if (task.place != null) ...[
                  const SizedBox(height: 20),
                  Paper(
                    color: SoftPop.warm,
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.place!,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const Text('Destination'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (task.pin != null) ...[
                  const SizedBox(height: 12),
                  Paper(
                    color: SoftPop.warm,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(task.pin!.label, style: Theme.of(context).textTheme.titleMedium),
                        if (task.pin!.note.isNotEmpty) Text(task.pin!.note),
                        const Text('Fixed destination · visible to this space'),
                        TextButton.icon(
                          onPressed: () => ExternalLauncher.openMapDirections(
                            context,
                            query: task.pin!.label,
                            lat: task.pin!.lat,
                            lng: task.pin!.lng,
                          ),
                          icon: const Icon(Icons.directions_outlined),
                          label: const Text('Get directions'),
                        ),
                        if (ref.watch(sharedBackendProvider) case final backend?)
                          StreamBuilder(
                            stream: backend.firestore
                                .doc('spaces/${task.spaceId}/tasks/${task.id}/arrivals/${backend.auth.currentUser!.uid}')
                                .snapshots(),
                            builder: (context, snapshot) => OutlinedButton.icon(
                              onPressed: snapshot.data?.exists == true ? null : () async {
                                try {
                                  await backend.call('checkInArrival', {
                                    'spaceId': task.spaceId,
                                    'taskId': task.id,
                                  });
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not check in. Try again.')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(snapshot.data?.exists == true
                                  ? 'You reported arriving'
                                  : "I'm here · member-reported"),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                TaskPhotos(task),
                const SizedBox(height: 24),
                TaskActions(task: task),
                if (task.creatorId != space.currentUserId && ref.read(sharedBackendProvider) != null)
                  TextButton.icon(
                    onPressed: () => SafetySheet.report(context, ref.read(sharedBackendProvider)!,
                      spaceId: task.spaceId, kind: 'task', contentId: task.id,
                      targetUid: task.creatorId),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Report task'),
                  ),
                if (task.isDone) ...[
                  const SizedBox(height: 12),
                  const Text('One less thing to think about. Nicely done.'),
                ],
                const SizedBox(height: 24),
                Text(
                  'Activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Created by ${personName(space, task.creatorId)}'),
                for (final entry in task.activity)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: SoftPop.secondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(entry)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class TaskActions extends ConsumerWidget {
  const TaskActions({super.key, required this.task, this.compact = false});
  final Task task;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (task.isEvent) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(demoProvider);
    final busy = state.pending.contains(task.id);
    final error = state.errors[task.id];
    final actions = <(TaskAction, String)>[
      if (task.status == Responsibility.unclaimed)
        (TaskAction.accept, 'I’ve got it'),
      if (task.status == Responsibility.requested &&
          task.requestedId == ref.read(repositoryProvider).currentUserId) ...[
        (TaskAction.accept, 'Accept task'),
        if (!compact) (TaskAction.decline, 'Decline'),
      ],
      if (task.ownerId == ref.read(repositoryProvider).currentUserId &&
          !task.isDone) ...[
        if (task.offeredId != null)
          (TaskAction.confirmHandoff, 'Confirm handoff'),
        (TaskAction.complete, 'Mark done'),
        if (!compact && task.status == Responsibility.accepted)
          (TaskAction.needHelp, 'Need help'),
      ],
      if (task.status == Responsibility.needsHelp &&
          task.ownerId != ref.read(repositoryProvider).currentUserId &&
          task.offeredId == null)
        (TaskAction.offerHelp, 'Offer help'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy)
          Semantics(
            liveRegion: true,
            child: const Paper(
              color: SoftPop.blueSoft,
              padding: EdgeInsets.all(12),
              child: Text('Saving…'),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(error, style: const TextStyle(color: SoftPop.ink)),
            ),
          ),
        for (
          var i = 0;
          i < (compact && actions.isNotEmpty ? 1 : actions.length);
          i++
        )
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: i == 0
                ? FilledButton(
                    onPressed: busy
                        ? null
                        : () => actions[i].$1 == TaskAction.complete
                              ? completeWithPhoto(context, ref, task)
                              : ref
                                    .read(demoProvider.notifier)
                                    .act(task, actions[i].$1),
                    child: Text(actions[i].$2),
                  )
                : OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => actions[i].$1 == TaskAction.complete
                              ? completeWithPhoto(context, ref, task)
                              : ref
                                    .read(demoProvider.notifier)
                                    .act(task, actions[i].$1),
                    child: Text(actions[i].$2),
                  ),
          ),
        if (task.offeredId == ref.read(repositoryProvider).currentUserId)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Your offer is waiting for the owner.'),
          ),
      ],
    );
  }
}
