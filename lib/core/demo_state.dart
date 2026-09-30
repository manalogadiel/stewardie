import 'dart:async';

import 'sound_feedback.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import 'backend_provider.dart';

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
  String? _awaitingMembership;
  int _selectionRevision = 0;
  static final _selectionStore = StoreRef<String, String>('active-space');
  TimelineRepository get repository => ref.read(repositoryProvider);
  @override
  DemoState build() {
    final repository = ref.watch(repositoryProvider);
    _awaitingMembership = null;
    final revision = ++_selectionRevision;
    final db = ref.read(tutorialDatabaseProvider);
    final uid = repository.currentUserId;
    if (db != null) {
      unawaited(
        _selectionStore.record(uid).get(db).then((id) {
          if (ref.mounted &&
              revision == _selectionRevision &&
              id != null &&
              repository.spaces.any((s) => s.id == id)) {
            switchSpace(id);
          }
        }),
      );
    }
    final updates = repository.changes.listen((_) => refresh());
    ref.onDispose(updates.cancel);
    final timer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
    ref.onDispose(timer.cancel);
    return DemoState(
      tasks: repository.tasks,
      spaceId: repository.spaces.firstOrNull?.id ?? '',
    );
  }

  void refresh() {
    if (repository.spaces.any((s) => s.id == _awaitingMembership)) {
      _awaitingMembership = null;
    }
    state = DemoState(
      tasks: repository.tasks,
      spaceId:
          _awaitingMembership == state.spaceId ||
              repository.spaces.any((s) => s.id == state.spaceId)
          ? state.spaceId
          : repository.spaces.firstOrNull?.id ?? '',
      personId:
          repository.spaces.any(
            (s) =>
                s.id == state.spaceId &&
                s.members.any((m) => m.id == state.personId),
          )
          ? state.personId
          : null,
      pending: state.pending,
      errors: state.errors,
      revision: state.revision + 1,
    );
  }

  void selectPerson(String? id) => state = DemoState(
    tasks: state.tasks,
    spaceId: state.spaceId,
    personId: id,
    pending: state.pending,
    errors: state.errors,
  );
  void switchSpace(String id) {
    ++_selectionRevision;
    _awaitingMembership = repository.spaces.any((s) => s.id == id) ? null : id;
    final db = ref.read(tutorialDatabaseProvider);
    if (db != null)
      unawaited(_selectionStore.record(repository.currentUserId).put(db, id));
    state = DemoState(
      tasks: state.tasks,
      spaceId: id,
      pending: state.pending,
      errors: state.errors,
    );
  }

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
      await repository.act(task.id, action, repository.currentUserId);
      if (action == TaskAction.complete && !repository.isShared)
        unawaited(SoundFeedback.play('success'));
    } on DemoException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Could not save. Try again.';
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
