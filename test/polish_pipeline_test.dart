import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/features/media/media_library.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_state.dart';
import 'package:stewardie/online/live_location_pill.dart';
import 'package:stewardie/online/live_location_service.dart';

void main() {
  test('a queued attachment ID survives retries without spending quota twice', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('stable-media');
    final library = MediaLibrary(DemoRepository(delay: Duration.zero), database: db, dailyLimit: 1);
    final draft = PhotoDraft(Uint8List.fromList([1]), Uint8List.fromList([2]), 1, 1, 'library');
    final first = await library.add(draft, 'home', 'me', 'First', attachmentId: 'stable-photo');
    final retry = await library.add(draft, 'home', 'me', 'First', attachmentId: 'stable-photo');
    expect(retry.id, first.id);
    expect(library.items, hasLength(1));
    expect(await photoRecords.count(db), 1);
    await expectLater(library.add(draft, 'home', 'me', 'Second', attachmentId: 'another-photo'), throwsStateError);
    library.dispose();
    await db.close();
  });
  test('capture ratio processing preserves landscape pixels and bakes crop once', () {
    final raw = Uint8List.fromList(img.encodeJpg(img.Image(width: 320, height: 180)));
    final draft = processPhoto({'bytes': raw, 'source': 'camera', 'cropRatio': '4:3'});
    expect(draft.width, greaterThan(draft.height));
    expect(draft.width / draft.height, closeTo(4 / 3, .02));
    expect(draft.framing.isFull, isTrue);
    final thumb = img.decodeImage(draft.thumbnail)!;
    expect(thumb.width / thumb.height, closeTo(4 / 3, .02));
  });
  test('seven-stop progress migrates by identity and completed users stay completed', () async {
    final db = await newDatabaseFactoryMemory().openDatabase('tour-migration');
    final records = stringMapStoreFactory.store('tutorial_state_v1');
    await records.record('tutorial_old').put(db, {'status': 'inProgress', 'stopIndex': 3});
    final store = TutorialStore(db);
    expect(TutorialStops.all[await store.getCurrentStopIndex('old')].id, TutorialStopId.keepMoment);
    await store.setCurrentStopIndex('old', 3);
    expect(TutorialStops.all[await store.getCurrentStopIndex('old')].id, TutorialStopId.calendar);
    await store.setStatus('old', TutorialStatus.completed);
    expect(await store.getStatus('old'), TutorialStatus.completed);
    expect(await store.getStatus('different-account'), TutorialStatus.notStarted);
    await db.close();
  });
  testWidgets('minimizing sharing retains timer and End without ending the session', (tester) async {
    final service = LiveLocationService.instance;
    service.isSharing.value = true;
    service.remainingMinutes.value = 15;
    addTearDown(() => service.isSharing.value = false);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LiveLocationPill())));
    await tester.tap(find.byTooltip('Minimize sharing status'));
    await tester.pumpAndSettle();
    expect(find.text('15m left'), findsOneWidget);
    expect(find.text('End'), findsOneWidget);
    expect(service.isSharing.value, isTrue);
    await tester.tap(find.byTooltip('Expand sharing status'));
    await tester.pumpAndSettle();
    expect(find.text('Sharing location · 15m left'), findsOneWidget);
  });
}
