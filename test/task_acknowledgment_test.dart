import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/sync_state.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/timeline/presentation/task_widgets.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/features/timeline/domain/models.dart';
import 'package:stewardie/online/edit_outbox.dart';
import 'package:stewardie/online/firebase_repository.dart';
import 'package:stewardie/online/online_backend.dart';

class _Outbox extends Fake implements EditOutbox {
  @override
  void addListener(void Function() listener) {}
  @override
  void removeListener(void Function() listener) {}
}

class _Backend extends Fake implements OnlineBackend {
  int writes = 0, reads = 0;
  bool failRead = false, failWrite = false;
  String status = 'accepted';
  @override
  String newOperationId() => 'operation';
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> values = const {},
    bool feedback = true,
  ]) async {
    if (name == 'actOnTask') {
      writes++;
      if (failWrite) throw StateError('Denied');
      return {'taskId': 'task', 'ok': true};
    }
    expect(name, 'getTask');
    reads++;
    if (failRead) throw StateError('Offline');
    return {
      'task': {
        'title': 'Laundry',
        'creatorUid': 'alice',
        'ownerUid': 'alice',
        'status': status,
        'scheduledLocalDate': '2026-10-01',
      },
    };
  }
}

class _Repository extends FirebaseTimelineRepository {
  _Repository(OnlineBackend backend) : super(backend, 'alice', _Outbox());
  @override
  List<Task> get tasks => [
    Task(
      id: 'task',
      spaceId: 'space',
      title: 'Laundry',
      day: DateTime(2026, 10, 1),
      creatorId: 'alice',
      status: Responsibility.requested,
    ),
  ];
}

void main() {
  for (final sync in SyncState.values) {
    testWidgets('task card only shows actionable sync state $sync', (
      tester,
    ) async {
      final repository = DemoRepository(delay: Duration.zero);
      final space = repository.spaces.first;
      final task = Task(
        id: 'card',
        spaceId: space.id,
        title: 'Laundry',
        day: DateTime.now(),
        creatorId: space.currentUserId,
        status: Responsibility.unclaimed,
        syncState: sync,
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: SoftPop.theme,
            home: Scaffold(
              body: TaskCard(task: task, space: space),
            ),
          ),
        ),
      );
      expect(find.text('Synced'), findsNothing);
      if (sync == SyncState.pending) {
        expect(find.text('Pending sync'), findsOneWidget);
      }
      if (sync == SyncState.failed) {
        expect(find.text('Needs retry'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
  for (final action in [TaskAction.accept, TaskAction.complete]) {
    test('${action.name} hydrates an acknowledged Spark action', () async {
      final backend = _Backend()
        ..status = action == TaskAction.complete ? 'completed' : 'accepted';
      final repository = _Repository(backend);
      final task = await repository.act('task', action, 'alice');
      expect(task.status.name, backend.status);
      expect(backend.writes, 1);
      expect(backend.reads, 1);
      await repository.dispose();
    });
  }
  test('read retry after commitment cannot mutate twice', () async {
    final backend = _Backend()..failRead = true;
    final repository = _Repository(backend);
    await expectLater(
      repository.act('task', TaskAction.accept, 'alice'),
      throwsA(
        isA<DemoException>().having(
          (e) => e.message,
          'message',
          startsWith('Saved.'),
        ),
      ),
    );
    backend.failRead = false;
    await repository.act('task', TaskAction.accept, 'alice');
    expect(backend.writes, 1);
    expect(backend.reads, 2);
    await repository.dispose();
  });
  test('rejected writes do not fetch or report success', () async {
    final backend = _Backend()..failWrite = true;
    final repository = _Repository(backend);
    await expectLater(
      repository.act('task', TaskAction.complete, 'alice'),
      throwsStateError,
    );
    expect(backend.reads, 0);
    await repository.dispose();
  });
}
