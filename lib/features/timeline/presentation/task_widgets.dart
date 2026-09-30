import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/demo_state.dart';
import '../../../core/sync_state.dart';
import '../../../core/place_pin.dart';
import '../../../core/theme.dart';
import '../../../core/task_name.dart';
import '../../../core/widgets.dart';
import '../../../online/firebase_repository.dart';
import '../domain/models.dart';
import 'task_detail.dart';

class TaskCard extends ConsumerWidget {
  const TaskCard({super.key, required this.task, required this.space});
  final Task task;
  final Space space;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: SoftPop.surface,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: task.syncState == SyncState.synced
          ? () => context.push('/task/${task.id}')
          : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.syncState != SyncState.synced)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  switch (task.syncState) {
                    SyncState.synced => 'Synced',
                    SyncState.pending => 'Pending sync',
                    SyncState.failed => 'Needs retry',
                  },
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: SoftPop.secondary),
                ),
              ),
            if (task.syncState == SyncState.failed &&
                ref.read(repositoryProvider) is FirebaseTimelineRepository)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () =>
                        (ref.read(repositoryProvider)
                                as FirebaseTimelineRepository)
                            .outbox
                            .flush(retryFailed: true),
                    child: const Text('Retry sync'),
                  ),
                  TextButton(
                    onPressed: () =>
                        (ref.read(repositoryProvider)
                                as FirebaseTimelineRepository)
                            .outbox
                            .acknowledged(task.id),
                    child: const Text('Discard draft'),
                  ),
                ],
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: SoftPop.secondary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (task.isEvent)
              Text(
                task.participants
                    .map((id) => personName(space, id))
                    .join(' · '),
              )
            else
              Row(
                children: [
                  if (task.ownerId ?? task.requestedId
                      case final String id) ...[
                    MemberAvatar(space.member(id), size: 28),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      personName(space, task.ownerId ?? task.requestedId),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            StatusLabel(task),
            if (!task.isDone && task.day.isBefore(dateOnly(DateTime.now())))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Overdue · Still here when you’re ready'),
              ),
            if (task.place != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: SoftPop.secondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(task.place!)),
                  ],
                ),
              ),
            if (task.syncState == SyncState.synced &&
                ((task.ownerId == space.currentUserId && !task.isDone) ||
                    task.requestedId == space.currentUserId)) ...[
              const SizedBox(height: 16),
              TaskActions(task: task, compact: true),
            ],
          ],
        ),
      ),
    ),
  );
}

Future<void> showAddTask(BuildContext context, Space space) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddTask(space),
    );

class _AddTask extends ConsumerStatefulWidget {
  const _AddTask(this.space);
  final Space space;
  @override
  ConsumerState<_AddTask> createState() => _AddTaskState();
}

class _AddTaskState extends ConsumerState<_AddTask> {
  final title = TextEditingController();
  final form = GlobalKey<FormState>();
  String? requestedUid;
  PlacePin? pin;
  late final String operationId =
      'task-${DateTime.now().microsecondsSinceEpoch}';
  @override
  void initState() {
    super.initState();
    requestedUid = ref.read(demoProvider).personId;
  }

  bool saving = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SafeArea(
        top: false,
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'One little thing',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Today in ${widget.space.name}'),
              const SizedBox(height: 20),
              TextFormField(
                controller: title,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Task name',
                  hintText: 'What needs doing?',
                  errorMaxLines: 3,
                ),
                validator: taskNameError,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: requestedUid ?? '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Who is this for?',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Anyone · Leave unclaimed'),
                  ),
                  for (final member in widget.space.members)
                    DropdownMenuItem(
                      value: member.id,
                      child: Text(
                        member.id == widget.space.currentUserId
                            ? 'Me'
                            : member.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(
                        () => requestedUid = value == '' ? null : value,
                      ),
              ),
              const SizedBox(height: 8),
              const Text('A request stays pending until they accept.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final selected = await showPlacePicker(
                          context,
                          initial: pin,
                        );
                        if (selected != null && mounted) {
                          setState(() => pin = selected);
                        }
                      },
                icon: const Icon(Icons.place_outlined),
                label: Text(pin?.label ?? 'Add destination (optional)'),
              ),
              if (pin != null)
                TextButton(
                  onPressed: () => setState(() => pin = null),
                  child: const Text('Remove destination'),
                ),
              const SizedBox(height: 16),
              if (error != null) Text(error!),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) {
                          return;
                        }
                        setState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await ref
                              .read(repositoryProvider)
                              .addTask(
                                widget.space.id,
                                title.text,
                                DateTime.now(),
                                false,
                                requestedUid: requestedUid,
                                operationId: operationId,
                                pin: pin,
                              );
                          if (!context.mounted) return;
                          ref.read(demoProvider.notifier).refresh();
                          Navigator.pop(context);
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              saving = false;
                              error = "Could not save. Try again.";
                            });
                          }
                        }
                      },
                child: const Text('Add task'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
