import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/timeline/data/demo_repository.dart';
import '../features/timeline/domain/models.dart';

final repositoryProvider = Provider<TimelineRepository>(
  (ref) => DemoRepository(),
);
final demoProvider = NotifierProvider<DemoController, DemoState>(
  DemoController.new,
);

class DemoState {
  const DemoState({
    required this.tasks,
    this.spaceId = 'home',
    this.personId,
    this.pending = const {},
    this.errors = const {},
    this.revision = 0,
  });
  final List<Task> tasks;
  final String spaceId;
  final String? personId;
  final Set<String> pending;
  final Map<String, String> errors;
  final int revision;
}

class DemoController extends Notifier<DemoState> {
  TimelineRepository get repository => ref.read(repositoryProvider);
  @override
  DemoState build() {
    final timer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
    ref.onDispose(timer.cancel);
    return DemoState(tasks: ref.watch(repositoryProvider).tasks);
  }

  void refresh() => state = DemoState(
    tasks: repository.tasks,
    spaceId: state.spaceId,
    personId: state.personId,
    pending: state.pending,
    errors: state.errors,
    revision: state.revision + 1,
  );
  void selectPerson(String? id) => state = DemoState(
    tasks: state.tasks,
    spaceId: state.spaceId,
    personId: id,
    pending: state.pending,
    errors: state.errors,
  );
  void switchSpace(String id) => state = DemoState(
    tasks: state.tasks,
    spaceId: id,
    pending: state.pending,
    errors: state.errors,
  );
  Future<void> act(Task task, TaskAction action) async {
    if (state.pending.contains(task.id)) {
      return;
    }
    state = DemoState(
      tasks: state.tasks,
      spaceId: state.spaceId,
      personId: state.personId,
      pending: {...state.pending, task.id},
      errors: {...state.errors}..remove(task.id),
    );
    String? error;
    try {
      await repository.act(task.id, action, 'me');
    } on DemoException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Could not save this demo action. Try again.';
    }
    if (!ref.mounted) {
      return;
    }
    state = DemoState(
      tasks: repository.tasks,
      spaceId: state.spaceId,
      personId: state.personId,
      pending: {...state.pending}..remove(task.id),
      errors: {...state.errors, task.id: ?error},
    );
  }
}
