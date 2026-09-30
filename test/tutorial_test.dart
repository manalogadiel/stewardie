import 'package:stewardie/features/onboarding/onboarding_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_coordinator.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_example_card.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_invitation.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_overlay.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_state.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_target_registry.dart';

void main() {
  test('removing a draft avatar stays removed after resuming', () async {
    final db = await databaseFactoryMemory.openDatabase('avatar-draft.db');
    addTearDown(db.close);
    final store = OnboardingStore(db);
    await store.saveDraft(step: OnboardingStep.name, avatarBase64: 'photo');
    await store.saveDraft(step: OnboardingStep.name, clearAvatar: true);
    expect((await store.loadDraft(null))!.containsKey('avatarBase64'), isFalse);
  });

  testWidgets('tour stays usable on a short screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: SoftPop.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.5)),
          child: child!,
        ),
        home: Scaffold(
          body: TutorialOverlay(
            initialStopIndex: 0,
            onFinished: () {},
            onSkipped: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Your day, together'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Explicit continuation', () {
    late Database db;
    setUp(() async {
      db = await databaseFactoryMemory.openDatabase('continuation.db');
      await TutorialStore(db)
          .setStatus('new-member', TutorialStatus.awaitingSpace);
    });
    tearDown(() async => db.close());
    testWidgets('continuation is explicit and consumed once per account', (
      tester,
    ) async {
      final store = TutorialStore(db);
      final coordinator = TutorialCoordinator(db);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    coordinator.continueTour(context, uid: 'new-member'),
                child: const Text('Continue tour'),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(TutorialOverlay), findsNothing);
      await tester.tap(find.text('Continue tour'));
      await tester.pumpAndSettle();
      expect(find.text('Your day, together'), findsOneWidget);
      await tester.tap(find.text('Skip tour'));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => store.getStatus('new-member')),
        TutorialStatus.skipped,
      );
      await tester.tap(find.text('Continue tour'));
      await tester.pumpAndSettle();
      expect(find.byType(TutorialOverlay), findsNothing);
    });
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  group('TutorialStop definitions and TutorialStore unit tests', () {
    late Database db;
    late TutorialStore store;

    setUp(() async {
      db = await databaseFactoryMemory.openDatabase('test_tutorial.db');
      store = TutorialStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('TutorialStops contains exactly 7 defined stops with correct destinations', () {
      expect(TutorialStops.all.length, 7);

      final ids = TutorialStops.all.map((s) => s.id).toList();
      expect(ids, [
        TutorialStopId.spaces,
        TutorialStopId.dayTogether,
        TutorialStopId.askCoverFinish,
        TutorialStopId.keepMoment,
        TutorialStopId.peopleRoutines,
        TutorialStopId.placesSharing,
        TutorialStopId.updatesInbox,
      ]);

      // Verify destination tabs match expected core navigation
      expect(TutorialStops.all[0].destinationTab, 0); // Spaces -> Today
      expect(TutorialStops.all[1].destinationTab, 0); // Day together -> Today
      expect(TutorialStops.all[2].destinationTab, 0); // Tasks -> Today
      expect(TutorialStops.all[3].destinationTab, 1); // Moments tab
      expect(TutorialStops.all[4].destinationTab, 2); // Space tab
      expect(TutorialStops.all[5].destinationTab, 0); // Places -> Today
      expect(TutorialStops.all[6].destinationTab, 0); // Updates -> Today
    });

    test(
      'TutorialStore tracks status, progress index, and clears properly',
      () async {
        const uid = 'member-tour-1';

        // Initial state
        expect(await store.getStatus(uid), TutorialStatus.notStarted);
        expect(await store.getCurrentStopIndex(uid), 0);

        // Start tour
        await store.setStatus(uid, TutorialStatus.inProgress);
        await store.setCurrentStopIndex(uid, 3);
        expect(await store.getStatus(uid), TutorialStatus.inProgress);
        expect(await store.getCurrentStopIndex(uid), 3);

        // Complete tour
        await store.setStatus(uid, TutorialStatus.completed);
        expect(await store.getStatus(uid), TutorialStatus.completed);

        // Replay or clear
        await store.clear(uid);
        expect(await store.getStatus(uid), TutorialStatus.notStarted);
        expect(await store.getCurrentStopIndex(uid), 0);
      },
    );

    test('TutorialStore tracks skipped status', () async {
      const uid = 'member-skip';
      await store.setStatus(uid, TutorialStatus.skipped);
      expect(await store.getStatus(uid), TutorialStatus.skipped);
    });
  });

  group('TutorialTargetRegistry tests', () {
    test('resolves target keys by id', () {
      expect(
        TutorialTargetRegistry.keyForId('space_selector'),
        TutorialTargetRegistry.spaceSelectorTarget,
      );
      expect(
        TutorialTargetRegistry.keyForId('day_together'),
        TutorialTargetRegistry.dayTogetherTarget,
      );
      expect(
        TutorialTargetRegistry.keyForId('tasks'),
        TutorialTargetRegistry.tasksTarget,
      );
      expect(
        TutorialTargetRegistry.keyForId('moments_tab'),
        TutorialTargetRegistry.momentsTabTarget,
      );
      expect(
        TutorialTargetRegistry.keyForId('space_tab'),
        TutorialTargetRegistry.spaceTabTarget,
      );
      expect(
        TutorialTargetRegistry.keyForId('map_button'),
        TutorialTargetRegistry.mapButtonTarget,
      );
      expect(
        TutorialTargetRegistry.keyForId('notification_bell'),
        TutorialTargetRegistry.notificationBellTarget,
      );
      expect(TutorialTargetRegistry.keyForId('unknown'), isNull);
    });
  });

  group('TutorialInvitationSheet widget tests', () {
    testWidgets(
      'renders invitation copy and handles acceptance and dismissal',
      (tester) async {
        bool accepted = false;
        bool dismissed = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: Scaffold(
              body: TutorialInvitationSheet(
                onAccept: () => accepted = true,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('A quick look around?'), findsOneWidget);
        expect(find.text('Show me around'), findsOneWidget);
        expect(find.text('Explore on my own'), findsOneWidget);

        await tester.tap(find.text('Show me around'));
        expect(accepted, isTrue);

        await tester.tap(find.text('Explore on my own'));
        expect(dismissed, isTrue);
      },
    );
  });

  group('TutorialExampleCard widget tests', () {
    testWidgets('renders example cards for all 7 stops without layout errors', (
      tester,
    ) async {
      for (final stop in TutorialStops.all) {
        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: Scaffold(
              body: Center(child: TutorialExampleCard(stopId: stop.id)),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Example'), findsOneWidget);
      }
    });
  });

  group('TutorialOverlay widget tests', () {
    testWidgets('tab request waits until the overlay build has finished', (
      tester,
    ) async {
      int selectedTab = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: StatefulBuilder(
            builder: (context, updateHome) => Scaffold(
              body: Stack(
                children: [
                  Text('Tab $selectedTab'),
                  TutorialOverlay(
                    initialStopIndex: 0,
                    onFinished: () {},
                    onSkipped: () {},
                    onTabRequested: (tab) =>
                        updateHome(() => selectedTab = tab),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Tab 0'), findsOneWidget);
    });

    testWidgets('navigates through 7 stops, updates tabs, and completes', (
      tester,
    ) async {
      bool finished = false;
      bool skipped = false;
      int? requestedTab;

      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: TutorialOverlay(
              initialStopIndex: 0,
              onFinished: () => finished = true,
              onSkipped: () => skipped = true,
              onTabRequested: (tab) => requestedTab = tab,
            ),
          ),
        ),
      );
      await tester.pump();

      // Stop 1: Your spaces
      expect(find.text('Your spaces'), findsOneWidget);
      expect(find.text('Skip tour'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      // Back should not be visible on stop 1
      expect(find.text('Back'), findsNothing);

      // Tap Next -> Stop 2: Your day, together
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Your day, together'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);

      // Tap Back -> Back to Stop 1
      await tester.tap(find.text('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Your spaces'), findsOneWidget);

      // Advance through all stops to completion
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.text('Next'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Stop 7: Updates in one place -> Got it button
      expect(find.text('Updates in one place'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      // Tap Got it
      await tester.tap(find.text('Got it'));
      expect(finished, isTrue);
      expect(skipped, isFalse);
      expect(requestedTab, isNotNull);
    });

    testWidgets('allows skipping tour at any step', (tester) async {
      bool skipped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: TutorialOverlay(
              initialStopIndex: 2,
              onFinished: () {},
              onSkipped: () => skipped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Skip tour'), findsOneWidget);
      await tester.tap(find.text('Skip tour'));
      expect(skipped, isTrue);
    });
  });

  group('TutorialCoordinator first-use gating and lifecycle tests', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryMemory.openDatabase('test_coord.db');
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('does not prompt tour if not marked eligible for first-use', (
      tester,
    ) async {
      final coordinator = TutorialCoordinator(db);
      const uid = 'returning-user-1';

      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    coordinator.checkAndPromptTour(
                      context,
                      uid: uid,
                      onTabRequested: (_) {},
                    );
                  },
                  child: const Text('Check'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should NOT show invitation sheet
      expect(find.byType(TutorialInvitationSheet), findsNothing);
    });

    testWidgets(
      'prompts tour once if marked eligible, and debounces subsequent calls',
      (tester) async {
        final coordinator = TutorialCoordinator(db);
        const uid = 'new-user-1';

        TutorialCoordinator.markEligibleForFirstUsePrompt(uid);

        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      coordinator.checkAndPromptTour(
                        context,
                        uid: uid,
                        onTabRequested: (_) {},
                      );
                    },
                    child: const Text('Check'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // First call -> opens invitation sheet
        await tester.tap(find.text('Check'));
        await tester.pumpAndSettle();

        expect(find.byType(TutorialInvitationSheet), findsOneWidget);

        // Dismiss invitation sheet by tapping "Explore on my own"
        await tester.tap(find.text('Explore on my own'));
        await tester.pumpAndSettle();
        expect(find.byType(TutorialInvitationSheet), findsNothing);

        // Second call in same session -> debounced, never prompts again
        await tester.tap(find.text('Check'));
        await tester.pumpAndSettle();
        expect(find.byType(TutorialInvitationSheet), findsNothing);
      },
    );

    testWidgets(
      'replayTour launches tour overlay directly without first-use gating',
      (tester) async {
        final coordinator = TutorialCoordinator(db);
        const uid = 'replay-user-1';

        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      coordinator.replayTour(
                        context,
                        uid: uid,
                        onTabRequested: (_) {},
                      );
                    },
                    child: const Text('Replay'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Replay'));
        await tester.pumpAndSettle();

        // Tour overlay appears directly
        expect(find.byType(TutorialOverlay), findsOneWidget);
        expect(find.text('Your spaces'), findsOneWidget);
      },
    );
  });
}
