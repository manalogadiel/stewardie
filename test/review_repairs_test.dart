import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
// Sembast's real-time cooperative pauses do not advance Flutter's fake clock.
// Disable only those pauses; these tests still use the real in-memory database.
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
  Completer<void>? holdFirstSave;
  final updates = <Map<String, dynamic>>[];
  @override
  FirebaseAuth get auth => _Auth();
  @override
  Future<void> takeOverTask(String spaceId, String taskId) async {}
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> value = const {},
    bool feedback = true,
  ]) async {
    updates.add(Map.from(value));
    if (updates.length == 1 && holdFirstSave != null) {
      await holdFirstSave!.future;
    }
    if (fail) throw StateError('Changes not saved. Tap to retry.');
    return {'ok': true, 'version': (value['expectedVersion'] as int) + 1};
  }
}

void main() {
  setUpAll(disableSembastCooperator);
  tearDownAll(enableSembastCooperator);
  var databaseIndex = 0;
  Future<OnlineMomentsStore> open(
    WidgetTester tester,
    _Backend backend, {
    OnlineMomentsStore? existing,
    int version = 1,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final moments =
        existing ??
        await (() async {
          final db = await databaseFactoryMemory.openDatabase(
            'review-${databaseIndex++}',
          );
          addTearDown(db.close);
          final value = await OnlineMomentsStore.fromDatabase(db);
          addTearDown(value.dispose);
          return value;
        })();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
    });
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
              'version': version,
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
    return moments;
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
    'closing during a save restores newer edits after the older acknowledgement',
    (tester) async {
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final backend = _Backend()..holdFirstSave = release;
      final moments = await open(tester, backend);
      final item = find.widgetWithText(TextField, 'Add an item...');
      await tester.ensureVisible(item);
      await tester.enterText(item, 'Keep this checklist');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(backend.updates, hasLength(1));
      final title = find.widgetWithText(TextField, 'Wash dishes');
      await tester.ensureVisible(title);
      await tester.enterText(title, 'Newer title while saving');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      release.complete();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      final store = stringMapStoreFactory.store('task-detail-drafts');
      final retained = await store.record('me/home/task').get(moments.database);
      expect(retained?['title'], 'Newer title while saving');
      await open(tester, backend, existing: moments, version: 2);
      expect(
        find.widgetWithText(TextField, 'Newer title while saving'),
        findsOneWidget,
      );
      final retry = find.text(
        'Unsaved draft restored. Review your changes and tap to retry.',
      );
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(backend.updates.last['title'], 'Newer title while saving');
      expect(backend.updates.last['expectedVersion'], 2);
      expect(await store.record('me/home/task').get(moments.database), isNull);
      expect(tester.takeException(), isNull);
    },
  );

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
