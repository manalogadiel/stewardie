import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/demo_state.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../domain/models.dart';
import 'task_detail.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.space});
  final Task task;
  final Space space;
  @override
  Widget build(BuildContext context) => Material(
    color: SoftPop.surface,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/task/${task.id}'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            if ((task.ownerId == 'me' && !task.isDone) ||
                task.requestedId == 'me') ...[
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
  bool mine = false;
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
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Give your task a name.'
                    : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Request me'),
                subtitle: const Text(
                  'Accept it when you’re ready, or leave it for someone to claim.',
                ),
                value: mine,
                onChanged: (value) => setState(() => mine = value!),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) {
                    return;
                  }
                  ref
                      .read(repositoryProvider)
                      .addTask(
                        widget.space.id,
                        title.text,
                        DateTime.now(),
                        mine,
                      );
                  ref.read(demoProvider.notifier).selectPerson(null);
                  ref.read(demoProvider.notifier).refresh();
                  Navigator.pop(context);
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
