import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/onboarding/onboarding_store.dart';
import 'package:stewardie/features/onboarding/screens/subscription_screen.dart';

void main() {
  test(
    'old All set drafts remain All set after inserting optional Plus',
    () async {
      final db = await databaseFactoryMemory.openDatabase(
        'plus-step-migration',
      );
      final records = stringMapStoreFactory.store('onboarding_v1');
      await records.record('draft_user').put(db, {
        'schemaVersion': 2,
        'stepIndex': 7,
      });
      final store = OnboardingStore(db);
      final draft = await store.loadDraft('user');
      expect(draft!['stepIndex'], OnboardingStep.allSet.index);
      await store.saveDraft(uid: 'user', step: OnboardingStep.subscription);
      expect((await store.loadDraft('user'))!['stepId'], 'subscription');
      await store.markCompleted('user');
      expect(await store.isCompleted('user'), isTrue);
      await db.close();
    },
  );

  testWidgets('Skip works while subscription loading is pending', (
    tester,
  ) async {
    final pending = Completer<void>();
    var skipped = false;
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: SoftPop.theme,
        home: Scaffold(
          body: SubscriptionScreen(
            onExplore: () => pending.future,
            onContinue: () => skipped = true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('View Plus plans'), findsNothing);
    expect(find.text('A little more together'), findsOneWidget);
    expect(
      find.text('Basic is free. Personal Plus is optional.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Skip for now'));
    await tester.tap(find.text('Skip for now'));
    expect(skipped, isTrue);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('plans failure and enlarged text retain a usable Skip', (
    tester,
  ) async {
    var skipped = false;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: SoftPop.theme,
        home: Scaffold(
          body: SubscriptionScreen(
            onExplore: () async => throw StateError('Unavailable'),
            onContinue: () => skipped = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('continue with Basic'), findsOneWidget);
    await tester.ensureVisible(find.text('Skip for now'));
    await tester.tap(find.text('Skip for now'));
    expect(skipped, isTrue);
    expect(tester.takeException(), isNull);
  });
}
