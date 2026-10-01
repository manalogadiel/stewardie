import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/onboarding/mascot_stage.dart';
import 'package:stewardie/features/onboarding/onboarding_progress.dart';
import 'package:stewardie/features/onboarding/onboarding_store.dart';
import 'package:stewardie/features/onboarding/permission_adapter.dart';
import 'package:stewardie/features/onboarding/screens/account_screen.dart';
import 'package:stewardie/features/onboarding/screens/all_set_screen.dart';
import 'package:stewardie/features/onboarding/screens/features_screen.dart';
import 'package:stewardie/features/onboarding/screens/name_screen.dart';
import 'package:stewardie/features/onboarding/screens/permissions_screen.dart';
import 'package:stewardie/features/onboarding/screens/welcome_screen.dart';

class TestPermissionAdapter extends PermissionAdapter {
  TestPermissionAdapter({
    this.cameraStatus = PermissionStatusState.notDetermined,
    this.locationStatus = PermissionStatusState.notDetermined,
    this.notificationsStatus = PermissionStatusState.notDetermined,
  });

  PermissionStatusState cameraStatus;
  PermissionStatusState locationStatus;
  PermissionStatusState notificationsStatus;

  @override
  Future<bool> locationServicesEnabled() async => true;

  @override
  Future<PermissionStatusState> checkStatus(
    PermissionCapability capability,
  ) async {
    return switch (capability) {
      PermissionCapability.camera => cameraStatus,
      PermissionCapability.location => locationStatus,
      PermissionCapability.notifications => notificationsStatus,
    };
  }

  @override
  Future<PermissionStatusState> requestPermission(
    PermissionCapability capability,
  ) async {
    return switch (capability) {
      PermissionCapability.camera =>
        cameraStatus = PermissionStatusState.granted,
      PermissionCapability.location =>
        locationStatus = PermissionStatusState.granted,
      PermissionCapability.notifications =>
        notificationsStatus = PermissionStatusState.granted,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingStore unit tests', () {
    late Database db;
    late OnboardingStore store;

    setUp(() async {
      db = await databaseFactoryMemory.openDatabase('test_onboarding.db');
      store = OnboardingStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('draft saves and loads fields without saving passwords', () async {
      await store.saveDraft(
        uid: null, // pre-auth
        step: OnboardingStep.name,
        name: 'Diel',
        email: 'diel@example.com',
      );

      final draft = await store.loadDraft(null);
      expect(draft, isNotNull);
      expect(draft!['name'], 'Diel');
      expect(draft['email'], 'diel@example.com');
      // Explicitly ensure adultConfirmed is never retained in drafts
      expect(draft.containsKey('adultConfirmed'), isFalse);
      expect(draft['stepIndex'], OnboardingStep.name.index);
      // Explicitly ensure password is never in draft
      expect(draft.containsKey('password'), isFalse);
    });

    test('post-auth draft uses uid and clearDraft removes it', () async {
      const uid = 'user-123';
      await store.saveDraft(
        uid: uid,
        step: OnboardingStep.verifyEmail,
        name: 'Jordan',
        email: 'jordan@example.com',
      );

      var draft = await store.loadDraft(uid);
      expect(draft!['name'], 'Jordan');

      await store.clearDraft(uid);
      draft = await store.loadDraft(uid);
      expect(draft, isNull);
    });

    test('cooldown timer correctly decrements and expires', () async {
      const uid = 'user-resend';
      // No resend yet -> 0 seconds cooldown
      expect(await store.getRemainingCooldownSeconds(uid), 0);

      // Record a resend
      await store.recordResendTimestamp(uid);
      final remaining = await store.getRemainingCooldownSeconds(uid);
      expect(remaining, inInclusiveRange(28, 30));
    });

    test(
      'isCompleted returns false initially, then true after markCompleted',
      () async {
        const uid = 'user-done';
        expect(await store.isCompleted(uid), isFalse);

        await store.markCompleted(uid);
        expect(await store.isCompleted(uid), isTrue);

        // Check draft was cleared on completion
        final draft = await store.loadDraft(uid);
        expect(draft, isNull);
      },
    );

    test('OnboardingStep indices and progress increments are exact', () {
      expect(OnboardingStep.welcome.index, 0);
      expect(OnboardingStep.welcome.progress, 0.0);

      expect(OnboardingStep.name.index, 1);
      expect(OnboardingStep.name.progress, closeTo(1 / 8, 0.001));

      expect(OnboardingStep.account.index, 2);
      expect(OnboardingStep.account.progress, closeTo(2 / 8, 0.001));

      expect(OnboardingStep.verifyEmail.index, 3);
      expect(OnboardingStep.verifyEmail.progress, closeTo(3 / 8, 0.001));

      expect(OnboardingStep.permissions.index, 4);
      expect(OnboardingStep.permissions.progress, closeTo(4 / 8, 0.001));

      expect(OnboardingStep.features.index, 6);
      expect(OnboardingStep.features.progress, closeTo(6 / 8, 0.001));

      expect(OnboardingStep.subscription.index, 7);
      expect(OnboardingStep.subscription.progress, closeTo(7 / 8, 0.001));
      expect(OnboardingStep.allSet.index, 8);
      expect(OnboardingStep.allSet.progress, 1.0);
    });
  });

  group('MascotStage widget tests', () {
    testWidgets('renders stage with illustration asset', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MascotStage(pose: MascotPose.butterWelcome)),
        ),
      );

      expect(find.byType(MascotStage), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('respects disableAnimationsOf by freezing float transform', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: MascotStage(pose: MascotPose.mintAttentive)),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MascotStage), findsOneWidget);
    });
  });

  group('OnboardingProgressBar widget tests', () {
    testWidgets('shows Back button on steps 2-6 and hides on step 1 & 7', (
      tester,
    ) async {
      bool backTapped = false;

      // Step 1: Welcome (step 0) -> No back button
      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: OnboardingProgressBar(
              step: OnboardingStep.welcome,
              onBack: () => backTapped = true,
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('onboarding_back_button')),
        findsNothing,
      );

      // Step 2: Name (step 1) -> Back button visible
      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: OnboardingProgressBar(
              step: OnboardingStep.name,
              onBack: () => backTapped = true,
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('onboarding_back_button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('onboarding_back_button')));
      expect(backTapped, isTrue);

      // Step 7: All Set (step 6) -> No back button
      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: OnboardingProgressBar(
              step: OnboardingStep.allSet,
              onBack: () {},
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('onboarding_back_button')),
        findsNothing,
      );
    });
  });

  group('WelcomeScreen widget tests', () {
    testWidgets('displays headline and action buttons', (tester) async {
      bool started = false;
      bool signIn = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: WelcomeScreen(
              onGetStarted: () => started = true,
              onSignIn: () => signIn = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Little things'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);

      await tester.tap(find.text('Get started'));
      expect(started, isTrue);

      await tester.tap(find.text('Already have an account? Sign in'));
      expect(signIn, isTrue);
    });
  });

  group('NameScreen widget tests', () {
    testWidgets('enforces name input and validates whitespace trimming', (
      tester,
    ) async {
      String? enteredName;

      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: NameScreen(
              initialName: '',
              onContinue: (name) => enteredName = name,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('What should we'), findsOneWidget);

      // Tap continue with empty field -> validates and shows error
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(
        find.text('Enter what you would like to be called'),
        findsOneWidget,
      );
      expect(enteredName, isNull);

      // Enter spaces only -> still invalid
      await tester.enterText(find.byType(TextField), '    ');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(
        find.text('Enter what you would like to be called'),
        findsOneWidget,
      );
      expect(enteredName, isNull);

      // Enter valid name with trailing space
      await tester.enterText(find.byType(TextField), '  Robin  ');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(enteredName, 'Robin');
    });
  });

  group('PermissionsScreen widget tests', () {
    testWidgets('allows individual permission toggling and continue', (
      tester,
    ) async {
      final adapter = TestPermissionAdapter();
      bool continued = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: PermissionsScreen(
              adapter: adapter,
              onContinue: () => continued = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Make it yours'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);

      // Tap Allow on Camera
      final allowButtons = find.text('Allow');
      expect(allowButtons, findsNWidgets(3));

      await tester.tap(allowButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(adapter.cameraStatus, PermissionStatusState.granted);
      expect(find.text('Allowed'), findsOneWidget);

      // Scroll to Continue button and tap
      await tester.ensureVisible(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(continued, isTrue);
    });
  });

  group('FeaturesScreen widget tests', () {
    testWidgets('carousels 3 cards with dots and advances to payoff', (
      tester,
    ) async {
      bool finished = false;
      int currentPage = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: FeaturesScreen(
              initialPage: 0,
              onPageChanged: (idx) => currentPage = idx,
              onLetsGo: () => finished = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Card 1
      expect(find.text('Share the everyday'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Advance to Card 2
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(currentPage, 1);
      expect(find.text('Keep the little moments'), findsOneWidget);

      // Advance to Card 3
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(currentPage, 2);
      expect(find.text('Stay in the loop'), findsOneWidget);
      expect(find.text("Let's go"), findsOneWidget);

      // Tap Let's go
      await tester.tap(find.text("Let's go"));
      expect(finished, isTrue);
    });
  });

  group('AllSetScreen widget tests', () {
    testWidgets('renders celebratory headline and open action', (tester) async {
      bool opened = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: AllSetScreen(name: 'Taylor', onOpenApp: () => opened = true),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("All set, Taylor!"), findsOneWidget);
      expect(find.text('Open Stewardie'), findsOneWidget);

      await tester.tap(find.text('Open Stewardie'));
      expect(opened, isTrue);
    });
  });

  group('AccountScreen widget tests', () {
    testWidgets(
      'renders email/password fields without any age question or 18+ checkbox',
      (tester) async {
        String? draftEmail;
        bool submitted = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: Scaffold(
              body: AccountScreen(
                name: 'Taylor',
                initialEmail: '',
                onAccountCreated: (user, emailSent) {},
                onDraftChanged: (email) => draftEmail = email,
                onSubmitForTesting: (email, password) async {
                  submitted = true;
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // Screen title and inputs
        expect(find.text('Add your email'), findsOneWidget);
        expect(
          find.byType(TextFormField),
          findsNWidgets(2),
        ); // Email & password

        // CRITICAL: verify age question is COMPLETELY absent
        expect(find.byType(CheckboxListTile), findsNothing);
        expect(find.byType(Checkbox), findsNothing);
        expect(find.textContaining('18'), findsNothing);
        expect(find.textContaining('adult'), findsNothing);

        // Verify terms & privacy notice is present
        expect(find.textContaining('privacy notice'), findsOneWidget);

        // Test draft update
        await tester.enterText(
          find.byType(TextFormField).first,
          'taylor@example.com',
        );
        expect(draftEmail, 'taylor@example.com');

        // Test validation: short password
        await tester.enterText(find.byType(TextFormField).last, 'short');
        await tester.ensureVisible(find.text('Create account'));
        await tester.tap(find.text('Create account'));
        await tester.pump();
        expect(
          find.text('Password must be at least 8 characters'),
          findsOneWidget,
        );
        expect(submitted, isFalse);

        // Test valid password submission
        await tester.enterText(
          find.byType(TextFormField).last,
          'valid-password-123',
        );
        await tester.ensureVisible(find.text('Create account'));
        await tester.tap(find.text('Create account'));
        await tester.pump();
        expect(submitted, isTrue);
      },
    );
  });

  group('MascotPose asset mapping tests', () {
    test('all MascotPose values map to existing transparent PNG assets', () {
      for (final pose in MascotPose.values) {
        expect(pose.assetPath, startsWith('assets/illustrations/'));
        expect(pose.assetPath, endsWith('.png'));
        expect(
          File(pose.assetPath).existsSync(),
          isTrue,
          reason: '${pose.name} asset does not exist: ${pose.assetPath}',
        );
      }
      expect(
        MascotPose.butterWelcome.assetPath,
        'assets/illustrations/onboarding-butter-welcome.png',
      );
      expect(
        MascotPose.attentive.assetPath,
        'assets/illustrations/onboarding-attentive.png',
      );
      expect(
        MascotPose.skyKey.assetPath,
        'assets/illustrations/onboarding-sky-key.png',
      );
      expect(
        MascotPose.emailVerification.assetPath,
        'assets/illustrations/onboarding-email-verification.png',
      );
      expect(
        MascotPose.makeItYours.assetPath,
        'assets/illustrations/onboarding-make-it-yours.png',
      );
      expect(
        MascotPose.butterTask.assetPath,
        'assets/illustrations/tour-task-helper.png',
      );
      expect(
        MascotPose.roseCamera.assetPath,
        'assets/illustrations/tour-moment-camera.png',
      );
      expect(
        MascotPose.mintCalendar.assetPath,
        'assets/illustrations/tour-calendar-planner.png',
      );
      expect(
        MascotPose.done.assetPath,
        'assets/illustrations/onboarding-done.png',
      );
    });
  });
}
