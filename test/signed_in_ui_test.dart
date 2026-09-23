import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/app.dart';
import 'package:stewardie/core/demo_state.dart';
import 'package:stewardie/core/person_labels.dart';
import 'package:stewardie/core/widgets.dart';
import 'package:stewardie/features/calendar/calendar_state.dart';
import 'package:stewardie/features/media/media_library.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/features/timeline/domain/models.dart';
import 'package:stewardie/online/firebase_repository.dart';

class SignedInRepository extends TimelineRepository {
  SignedInRepository(this.currentUserId, {this.isPlus = false});
  @override
  final String currentUserId;
  @override
  final bool isPlus;
  @override
  bool get isShared => true;
  final updates = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => updates.stream;
  String? savedMoodAuthor;
  @override
  List<Space> get spaces => [
    Space('shared-home', 'Our home', 'Friends', const [
      Member('alice-uid', 'Alice', 'A', 0),
      Member('bob-uid', 'Bob', 'B', 1),
    ], currentUserId: currentUserId),
  ];
  @override
  final List<Task> tasks = [
    Task(
      id: 'shared-task',
      spaceId: 'shared-home',
      title: 'Make lunch',
      day: dateOnly(DateTime.now()),
      creatorId: 'alice-uid',
      ownerId: 'alice-uid',
      status: Responsibility.accepted,
    ),
  ];
  @override
  Future<Task> act(String taskId, TaskAction action, String actorId) async {
    if (actorId != currentUserId) throw StateError('Wrong account');
    final old = tasks.single;
    tasks[0] = old.transition(
      status: Responsibility.completed,
      ownerId: actorId,
      entry: 'Finished',
      completedAt: DateTime.now(),
    );
    updates.add(null);
    return tasks.single;
  }

  @override
  Future<Task> addTask(
    String spaceId,
    String title,
    DateTime day,
    bool assignToMe, {
    String? requestedUid,
    String? operationId,
  }) => throw UnimplementedError();
  @override
  CheckIn? checkIn(String spaceId, String memberId) => null;
  @override
  Future<void> shareCheckIn(
    String spaceId,
    String memberId,
    Mood mood,
    String note, {
    MoodColor color = MoodColor.sky,
  }) async {
    savedMoodAuthor = memberId;
    updates.add(null);
  }

  @override
  Future<void> removeCheckIn(String spaceId, String memberId) async {}
}

void main() {
  test('Firebase task maps server completion date without changing the viewer timezone', () {
    final task = firebaseTask('shared-home', 'task-1234', {
      'title': 'Laundry',
      'creatorUid': 'alice-uid',
      'ownerUid': 'bob-uid',
      'status': 'completed',
      'completedAt': '2026-09-23T17:30:00Z',
      'completedLocalDate': '2026-09-24',
      'scheduledLocalDate': '2026-09-20',
      'createdAt': {'_seconds': 1790000000},
    });
    expect(task.ownerId, 'bob-uid');
    expect(task.completedLocalDay, DateTime(2026, 9, 24));
    expect(task.day, DateTime(2026, 9, 20));
  });

  test('signed-in local photos and completion stay account-scoped', () async {
    final db = await databaseFactoryMemory.openDatabase(
      'signed-in-photos-test',
    );
    addTearDown(db.close);
    final alice = SignedInRepository('alice-uid');
    final bob = SignedInRepository('bob-uid');
    addTearDown(alice.updates.close);
    addTearDown(bob.updates.close);
    final records = stringMapStoreFactory.store('photos-alice');
    final library = MediaLibrary(alice, database: db, records: records);
    final photo = PhotoDraft(
      Uint8List.fromList([1]),
      Uint8List.fromList([2]),
      1,
      1,
      'library',
    );
    await library.add(
      photo,
      'shared-home',
      alice.currentUserId,
      'Lunch',
      taskId: 'shared-task',
    );
    final done = await alice.act(
      'shared-task',
      TaskAction.complete,
      alice.currentUserId,
    );
    await library.publishTask(done);
    expect(library.items.single.heading, 'Make lunch — done!');
    expect(library.items.single.uploaderId, 'alice-uid');
    expect(await photoRecords.find(db), isEmpty);
    expect(await stringMapStoreFactory.store('photos-bob').find(db), isEmpty);
    await expectLater(
      library.remove(library.items.single, 'bob-uid'),
      throwsStateError,
    );
    final restored = MediaLibrary(
      alice,
      database: db,
      records: records,
      initial: (await records.find(db))
          .map((r) => MediaAttachment.fromMap(r.value))
          .toList(),
    );
    expect(restored.items.single.publishedAt, isNotNull);
    library.dispose();
    restored.dispose();
  });

  testWidgets(
    'original Today uses authenticated identity, stream updates, and mood composer',
    (tester) async {
      final repo = SignedInRepository('alice-uid');
      addTearDown(repo.updates.close);
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            calendarRepositoryProvider.overrideWithValue(
              CalendarRepository(repo.spaces, seed: false),
            ),
          ],
          child: const StewardieApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Me'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Jamie (you)'), findsNothing);
      expect(personName(repo.spaces.single, 'alice-uid'), 'You');
      expect(calendarTitle(repo.spaces.single, 'alice-uid'), 'Your calendar');
      expect(calendarTitle(repo.spaces.single, 'bob-uid'), 'Bob’s calendar');
      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calm'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Share check-in'));
      await tester.tap(find.text('Share check-in'));
      await tester.pumpAndSettle();
      expect(repo.savedMoodAuthor, 'alice-uid');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StewardieApp)),
      );
      await container
          .read(demoProvider.notifier)
          .act(repo.tasks.single, TaskAction.complete);
      await tester.pumpAndSettle();
      expect(container.read(demoProvider).tasks.single.isDone, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
