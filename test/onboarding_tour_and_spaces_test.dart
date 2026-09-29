import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_coordinator.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_invitation.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_overlay.dart';

/// Test harness widget that simulates the entry flow of an account with or without spaces,
/// exactly matching OnlineHome._runEntryPrompts and space selector behavior.
class _TourAndSpacesHarness extends StatefulWidget {
  const _TourAndSpacesHarness({
    required this.database,
    required this.uid,
    required this.hasSpaces,
  });

  final Database database;
  final String uid;
  final bool hasSpaces;

  @override
  State<_TourAndSpacesHarness> createState() => _TourAndSpacesHarnessState();
}

class _TourAndSpacesHarnessState extends State<_TourAndSpacesHarness> {
  late int _destination;
  bool _spaceSelectorOpened = false;

  @override
  void initState() {
    super.initState();
    _destination = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runEntryPrompts();
    });
  }

  Future<void> _runEntryPrompts() async {
    try {
      await TutorialCoordinator(widget.database).checkAndPromptTour(
        context,
        uid: widget.uid,
        onTabRequested: (tab) {
          if (mounted && _destination != tab) {
            setState(() => _destination = tab);
          }
        },
      );
    } catch (_) {}

    if (!mounted || widget.hasSpaces) return;
    await Future<void>.delayed(Duration.zero);
    if (mounted && !widget.hasSpaces) {
      _showSpaceSelector();
    }
  }

  void _showSpaceSelector() {
    setState(() => _spaceSelectorOpened = true);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('Create a space'),
              onTap: () => Navigator.pop(sheet),
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('Join with a code'),
              onTap: () => Navigator.pop(sheet),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tab $_destination | Selector: $_spaceSelectorOpened'),
        actions: [
          IconButton(
            icon: const Icon(Icons.explore_outlined),
            tooltip: 'Take a tour',
            onPressed: () {
              TutorialCoordinator(widget.database).replayTour(
                context,
                uid: widget.uid,
                onTabRequested: (tab) {
                  if (mounted && _destination != tab) {
                    setState(() => _destination = tab);
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Text('Current Tab: $_destination'),
      ),
    );
  }
}

void main() {
  group('Onboarding Tour and No-Space Prompt Flow', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryMemory.openDatabase('tour_and_spaces_test.db');
      TutorialCoordinator.resetSessionState();
    });

    tearDown(() async {
      await db.close();
      TutorialCoordinator.resetSessionState();
    });

    testWidgets(
      'Verified account with no spaces: "Show me around" never produces setState during build, and after tour completion opens space selector with Create a space and Join with a code',
      (tester) async {
        const uid = 'verified-no-spaces-tour-user';
        TutorialCoordinator.markEligibleForFirstUsePrompt(uid);

        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: _TourAndSpacesHarness(
              database: db,
              uid: uid,
              hasSpaces: false,
            ),
          ),
        );

        // Advance to postFrameCallback
        await tester.pump();
        await tester.pumpAndSettle();

        // 1. Tutorial invitation sheet should be shown
        expect(find.byType(TutorialInvitationSheet), findsOneWidget);
        expect(find.text('A quick look around?'), findsOneWidget);
        expect(find.text('Show me around'), findsOneWidget);
        expect(find.text('Explore on my own'), findsOneWidget);

        // 2. Tap "Show me around"
        await tester.tap(find.text('Show me around'));
        await tester.pump();
        // Check immediately: NO setState during build exception!
        expect(tester.takeException(), isNull);

        // Settle sheet dismissal and overlay entrance
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 3. Tour overlay is visible
        expect(find.byType(TutorialOverlay), findsOneWidget);
        expect(find.text('Your spaces'), findsOneWidget);

        // Complete the tour by advancing to the end
        for (int i = 0; i < 6; i++) {
          await tester.tap(find.text('Next'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
        }

        // Last stop shows "Got it"
        expect(find.text('Got it'), findsOneWidget);
        await tester.tap(find.text('Got it'));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 4. After finishing tour, space selector bottom sheet opens automatically!
        expect(find.text('Create a space'), findsOneWidget);
        expect(find.text('Join with a code'), findsOneWidget);
      },
    );

    testWidgets(
      'Verified account with no spaces: skipping tour ("Explore on my own") opens space selector with Create a space and Join with a code',
      (tester) async {
        const uid = 'verified-no-spaces-skip-user';
        TutorialCoordinator.markEligibleForFirstUsePrompt(uid);

        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: _TourAndSpacesHarness(
              database: db,
              uid: uid,
              hasSpaces: false,
            ),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(TutorialInvitationSheet), findsOneWidget);

        // Tap "Explore on my own"
        await tester.tap(find.text('Explore on my own'));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Space selector opens automatically!
        expect(find.text('Create a space'), findsOneWidget);
        expect(find.text('Join with a code'), findsOneWidget);
      },
    );

    testWidgets(
      'Returning account with no spaces: does not show tour, directly opens space selector with Create a space and Join with a code',
      (tester) async {
        const uid = 'returning-account-no-spaces';
        // Note: markEligibleForFirstUsePrompt is NOT called for returning accounts

        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: _TourAndSpacesHarness(
              database: db,
              uid: uid,
              hasSpaces: false,
            ),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        // Tour invitation must NOT appear
        expect(find.byType(TutorialInvitationSheet), findsNothing);
        expect(tester.takeException(), isNull);

        // Space selector opens directly!
        expect(find.text('Create a space'), findsOneWidget);
        expect(find.text('Join with a code'), findsOneWidget);
      },
    );

    testWidgets(
      'Account with spaces: does not open empty space selector after tour or on launch',
      (tester) async {
        const uid = 'account-with-spaces-user';
        TutorialCoordinator.markEligibleForFirstUsePrompt(uid);

        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: _TourAndSpacesHarness(
              database: db,
              uid: uid,
              hasSpaces: true,
            ),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        // First-use tour is offered
        expect(find.byType(TutorialInvitationSheet), findsOneWidget);
        await tester.tap(find.text('Explore on my own'));
        await tester.pumpAndSettle();

        // Empty space selector does NOT open because hasSpaces is true!
        expect(find.text('Create a space'), findsNothing);
        expect(find.text('Join with a code'), findsNothing);
      },
    );

    testWidgets(
      'Manual "Take a tour" replay from settings: launches overlay without gating, updates tabs, and completes cleanly',
      (tester) async {
        const uid = 'replay-tour-user';
        // Returning user with spaces

        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: _TourAndSpacesHarness(
              database: db,
              uid: uid,
              hasSpaces: true,
            ),
          ),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        // Tap the replay tour action (app bar button)
        await tester.tap(find.byTooltip('Take a tour'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Tour overlay opens directly
        expect(find.byType(TutorialOverlay), findsOneWidget);
        expect(find.text('Your spaces'), findsOneWidget);

        // Advance to stop 4 (which targets moments tab)
        await tester.tap(find.text('Next')); // Stop 2
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next')); // Stop 3
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next')); // Stop 4 (Moments)
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Tap "Skip tour"
        await tester.tap(find.text('Skip tour'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Tour overlay is dismissed
        expect(find.byType(TutorialOverlay), findsNothing);
        // And space selector does NOT open
        expect(find.text('Create a space'), findsNothing);
      },
    );
  });
}
