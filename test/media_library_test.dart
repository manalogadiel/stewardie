import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/features/media/media_library.dart';
import 'package:stewardie/features/media/task_storage.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/features/timeline/domain/models.dart';

void main() {
  late Database db;
  late DemoRepository repo;
  late MediaLibrary media;
  var now = DateTime.utc(2026, 9, 23, 12);
  final draft = PhotoDraft(
    Uint8List.fromList([1, 2, 3]),
    Uint8List.fromList([4]),
    1,
    1,
    'library',
  );
  setUp(() async {
    now = DateTime.utc(2026, 9, 23, 12);
    db = await newDatabaseFactoryMemory().openDatabase('media');
    repo = DemoRepository(
      delay: Duration.zero,
      clock: () => now,
      persist: (task) async {
        await taskRecords.record(task.id).put(db, taskToMap(task));
      },
    );
    media = MediaLibrary(repo, database: db, clock: () => now, dailyLimit: 2);
  });
  tearDown(() async {
    media.dispose();
    await db.close();
  });

  test(
    'task photo waits for completion, survives reload and publishes once',
    () async {
      final photo = await media.add(
        draft,
        'home',
        'me',
        'Dinner together',
        taskId: 'dinner',
      );
      expect(photo.publishedAt, isNull);
      final done = await repo.act('dinner', TaskAction.complete, 'me');
      await Future.wait([media.publishTask(done), media.publishTask(done)]);
      final savedTasks = (await taskRecords.find(db))
          .map((r) => taskFromMap(r.value))
          .toList();
      final savedPhotos = (await photoRecords.find(db))
          .map((r) => MediaAttachment.fromMap(r.value))
          .toList();
      final restored = DemoRepository(restored: savedTasks, clock: () => now);
      expect(restored.tasks.firstWhere((t) => t.id == 'dinner').isDone, isTrue);
      expect(savedPhotos, hasLength(1));
      expect(savedPhotos.single.id, photo.id);
      expect(savedPhotos.single.completedBy, 'me');
      expect(savedPhotos.single.heading, contains('done!'));
      expect(savedPhotos.single.photo.bytes, draft.bytes);
      await media.remove(media.items.single, 'me');
      expect(await photoRecords.count(db), 0);
      expect(repo.tasks.firstWhere((t) => t.id == 'dinner').isDone, isTrue);
    },
  );

  test('completion failure preserves attachment; publish and removal cannot resurrect it', () async {
    final photo = await media.add(draft, 'home', 'me', '', taskId: 'dinner');
    repo.nextOutcome = DemoOutcome.failure;
    await expectLater(
      repo.act('dinner', TaskAction.complete, 'me'),
      throwsA(isA<DemoException>()),
    );
    await media.publishTask(repo.tasks.firstWhere((t) => t.id == 'dinner'));
    expect(media.items.single.publishedAt, isNull);
    final done = await repo.act('dinner', TaskAction.complete, 'me');
    await Future.wait([media.publishTask(done), media.remove(photo, 'me')]);
    expect(media.items, isEmpty);
    expect(await photoRecords.count(db), 0);
  });

  test(
    'daily allowance persists after deletion and reload; resets in UTC',
    () async {
      for (var i = 0; i < 2; i++) {
        final photo = await media.add(draft, 'home', 'me', '');
        await media.remove(photo, 'me');
      }
      final reloaded = MediaLibrary(
        repo,
        database: db,
        dailyLimit: 2,
        clock: () => now,
      );
      addTearDown(reloaded.dispose);
      await expectLater(
        reloaded.add(draft, 'weekend', 'me', ''),
        throwsStateError,
      );
      now = now.add(const Duration(days: 1));
      expect(
        (await reloaded.add(draft, 'weekend', 'me', '')).publishedAt,
        isNotNull,
      );
    },
  );

  test(
    'one task attachment, membership, editing rights and storage are enforced',
    () async {
      await media.add(draft, 'home', 'me', '', taskId: 'dinner');
      await expectLater(
        media.add(draft, 'home', 'me', '', taskId: 'dinner'),
        throwsStateError,
      );
      await expectLater(
        media.add(draft, 'missing', 'me', ''),
        throwsStateError,
      );
      await expectLater(media.add(draft, 'home', 'alex', ''), throwsStateError);
      await expectLater(
        media.add(draft, 'weekend', 'me', '', taskId: 'dinner'),
        throwsStateError,
      );
      final small = MediaLibrary(repo, storageLimit: 3);
      addTearDown(small.dispose);
      await expectLater(small.add(draft, 'home', 'me', ''), throwsStateError);
      final other = MediaAttachment(
        id: 'other',
        spaceId: 'home',
        uploaderId: 'alex',
        caption: '',
        createdAt: now,
        photo: draft,
      );
      final readOnly = MediaLibrary(repo, initial: [other]);
      addTearDown(readOnly.dispose);
      await expectLater(readOnly.remove(other, 'me'), throwsStateError);
    },
  );

  test('failed durable task write leaves task unfinished', () async {
    final failing = DemoRepository(
      delay: Duration.zero,
      persist: (_) async => throw StateError('Disk full'),
    );
    await expectLater(
      failing.act('dinner', TaskAction.complete, 'me'),
      throwsStateError,
    );
    expect(failing.tasks.firstWhere((t) => t.id == 'dinner').isDone, isFalse);
  });

  test(
    'processing normalizes orientation, size and removes imported metadata',
    () {
      final input = img.Image(width: 1800, height: 900);
      input.exif.imageIfd.orientation = 6;
      input.exif.imageIfd['Make'] = 'PRIVATE-CAMERA';
      final processed = processPhoto({
        'bytes': img.encodeJpg(input),
        'source': 'camera',
      });
      expect(processed.width, 800);
      expect(processed.height, 1600);
      expect(processed.bytes.length, lessThan(2000000));
      final decoded = img.decodeJpg(processed.bytes)!;
      expect(decoded.exif.imageIfd.orientation, isNull);
      expect(decoded.exif.imageIfd['Make'], isNull);
      expect(img.decodeJpg(processed.thumbnail)!.height, 320);
      expect(
        () => processPhoto({'bytes': Uint8List(10), 'source': 'library'}),
        throwsFormatException,
      );
    },
  );

  test('FramingRect computes correct normalized coordinates for aspect ratios', () {
    // 1600x1200 image (4:3 aspect ratio)
    final square = FramingRect.fromAspectRatio(
      targetRatio: 1.0,
      imageWidth: 1600,
      imageHeight: 1200,
      ratioName: '1:1',
    );
    expect(square.ratioName, '1:1');
    expect(square.isFull, isFalse);
    expect(square.height, 1.0);
    expect(square.y, 0.0);
    expect(square.width, closeTo(1200 / 1600, 0.001));
    expect(square.x, closeTo((1.0 - (1200 / 1600)) / 2.0, 0.001));

    // Matching ratio returns full
    final matching = FramingRect.fromAspectRatio(
      targetRatio: 4.0 / 3.0,
      imageWidth: 1600,
      imageHeight: 1200,
      ratioName: '4:3',
    );
    expect(matching.isFull, isTrue);

    // Serialization and deserialization
    final json = square.toMap();
    final restored = FramingRect.fromMap(json);
    expect(restored.x, square.x);
    expect(restored.y, square.y);
    expect(restored.width, square.width);
    expect(restored.height, square.height);
    expect(restored.ratioName, square.ratioName);
  });

  test('MediaAttachment preserves framing metadata across serialization', () {
    const customFraming = FramingRect(
      x: 0.1,
      y: 0.1,
      width: 0.8,
      height: 0.8,
      ratioName: '1:1',
    );
    final attachment = MediaAttachment(
      id: 'photo-1',
      spaceId: 'home',
      uploaderId: 'me',
      caption: 'Dinner',
      photo: draft,
      createdAt: DateTime.utc(2026, 9, 24),
      framing: customFraming,
    );
    expect(attachment.framing.ratioName, '1:1');
    expect(attachment.framing.width, 0.8);

    final map = attachment.toMap();
    final fromMap = MediaAttachment.fromMap(map);
    expect(fromMap.framing.ratioName, '1:1');
    expect(fromMap.framing.x, 0.1);
    expect(fromMap.framing.width, 0.8);
  });
}
