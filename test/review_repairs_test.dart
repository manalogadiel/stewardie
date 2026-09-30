import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/online/online_backend.dart';
import 'package:stewardie/online/online_moments.dart';
import 'package:stewardie/online/online_task_detail_sheet.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'me';
  @override
  String? get displayName => 'Sam';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => _User();
}

class _Backend extends Fake implements OnlineBackend {
  bool fail = false;
  final updates = <Map<String, dynamic>>[];
  @override
  FirebaseAuth get auth => _Auth();
  @override
  Future<void> takeOverTask(String spaceId, String taskId) async {}
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> value = const {},
  ]) async {
    updates.add(Map.from(value));
    if (fail) throw StateError('Changes not saved. Tap to retry.');
    return {'ok': true, 'version': (value['expectedVersion'] as int) + 1};
  }
}

void main() {
  Future<void> open(WidgetTester tester, _Backend backend) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = await databaseFactoryMemory.openDatabase('review');
    addTearDown(db.close);
    final moments = await OnlineMomentsStore.fromDatabase(db);
    addTearDown(moments.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnlineTaskDetailSheet(
            backend: backend,
            spaceId: 'home',
            task: {
              'id': 'task',
              'title': 'Wash dishes',
              'status': 'accepted',
              'ownerUid': 'other',
              'requestedUid': null,
              'helpNeeded': true,
              'version': 1,
              'subtasks': [],
              'activity': [],
            },
            members: const [
              {'uid': 'me', 'name': 'Sam'},
              {'uid': 'other', 'name': 'Alex'},
            ],
            momentStore: moments,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('takeover updates ownership and later edits omit reassignment', (
    tester,
  ) async {
    final backend = _Backend();
    await open(tester, backend);
    await tester.ensureVisible(find.text('Take over task'));
    await tester.tap(find.text('Take over task'));
    await tester.pumpAndSettle();
    expect(find.text('Take over task'), findsNothing);
    final input = find.widgetWithText(TextField, 'Add an item...');
    await tester.ensureVisible(input);
    await tester.enterText(input, 'Put plates away');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(backend.updates, isNotEmpty);
    expect(backend.updates.last.containsKey('requestedUid'), isFalse);
    expect(
      (backend.updates.last['subtasks'] as List).single['title'],
      'Put plates away',
    );
  });

  testWidgets(
    'failed subtask save keeps draft and retry sends the same checklist',
    (tester) async {
      final backend = _Backend()..fail = true;
      await open(tester, backend);
      final input = find.widgetWithText(TextField, 'Add an item...');
      await tester.ensureVisible(input);
      await tester.enterText(input, 'Put plates away');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Put plates away'), findsOneWidget);
      final retry = find.text('Changes not saved. Tap to retry.');
      expect(retry, findsOneWidget);
      backend.fail = false;
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(retry, findsNothing);
      expect(
        (backend.updates.last['subtasks'] as List).single['title'],
        'Put plates away',
      );
    },
  );
}
