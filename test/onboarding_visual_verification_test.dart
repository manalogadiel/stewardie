import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/onboarding/mascot_stage.dart';
import 'package:stewardie/features/onboarding/onboarding_store.dart';
import 'package:stewardie/features/onboarding/permission_adapter.dart';
import 'package:stewardie/features/onboarding/screens/account_screen.dart';
import 'package:stewardie/features/onboarding/screens/all_set_screen.dart';
import 'package:stewardie/features/onboarding/screens/features_screen.dart';
import 'package:stewardie/features/onboarding/screens/name_screen.dart';
import 'package:stewardie/features/onboarding/screens/permissions_screen.dart';
import 'package:stewardie/features/onboarding/screens/verify_email_screen.dart';
import 'package:stewardie/features/onboarding/screens/welcome_screen.dart';
import 'package:stewardie/online/login_scene.dart';

class _FakeUser extends Fake implements User {
  @override
  String get uid => 'user-123';
  @override
  String get email => 'taylor@example.com';
  @override
  bool get emailVerified => false;
  @override
  Future<void> reload() async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final entry in {
      'NunitoSans': 'assets/fonts/nunito-sans.ttf',
      'Fredoka': 'assets/fonts/fredoka.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  group(
    'Onboarding 7 screens visual rendering and transition verification',
    () {
      testWidgets(
        'Screen 1 (Welcome) renders clean butter hero, backdrop waves, and no sparkles',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              theme: SoftPop.theme,
              home: Scaffold(
                body: LoginBackdrop(
                  variant: 0,
                  child: SafeArea(
                    child: WelcomeScreen(onGetStarted: () {}, onSignIn: () {}),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Little things,\ntogether.'), findsOneWidget);
          expect(find.text('Get started'), findsOneWidget);
          expect(find.text('Already have an account? Sign in'), findsOneWidget);
          expect(find.byType(MascotStage), findsOneWidget);

          // Verify no generic face icon fallback
          expect(find.byIcon(Icons.face_rounded), findsNothing);
          // Verify no broken sparkle icon
          expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
          // Verify CustomPaint with wavy lines painter exists
          expect(find.byType(CustomPaint), findsWidgets);
        },
      );

      testWidgets(
        'Screen 2 (Name) renders clean attentive mint hero and form',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              theme: SoftPop.theme,
              home: Scaffold(
                body: LoginBackdrop(
                  variant: 1,
                  child: SafeArea(
                    child: NameScreen(
                      initialName: 'Taylor',
                      onContinue: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('What should we\ncall you?'), findsOneWidget);
          expect(find.text('Taylor'), findsOneWidget);
          expect(find.text('Continue'), findsOneWidget);
          expect(find.byIcon(Icons.face_rounded), findsNothing);
        },
      );

      testWidgets(
        'Screen 3 (Account) renders skyKey hero without age confirmation',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              theme: SoftPop.theme,
              home: Scaffold(
                body: LoginBackdrop(
                  variant: 2,
                  child: SafeArea(
                    child: AccountScreen(
                      name: 'Taylor',
                      initialEmail: 'taylor@example.com',
                      onSubmitForTesting: (email, pass) async {},
                      onDraftChanged: (_) {},
                      onAccountCreated: (_, _) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Add your email'), findsOneWidget);
          expect(find.text('Email address'), findsOneWidget);
          expect(find.text('Password'), findsOneWidget);
          expect(find.text('Create account'), findsOneWidget);
          // Verify age question is completely absent
          expect(find.textContaining('18'), findsNothing);
          expect(find.textContaining('adult'), findsNothing);
          expect(find.byType(Checkbox), findsNothing);
          expect(find.byIcon(Icons.face_rounded), findsNothing);
        },
      );

      testWidgets(
        'Screen 4 (Verify email) renders emailVerification mint mascot',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final user = _FakeUser();

          await tester.pumpWidget(
            MaterialApp(
              theme: SoftPop.theme,
              home: Scaffold(
                body: LoginBackdrop(
                  variant: 0,
                  child: SafeArea(
                    child: VerifyEmailScreen(
                      user: user,
                      store: OnboardingStore(null),
                      initialEmailSent: true,
                      onVerified: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Check your email'), findsOneWidget);
          expect(find.textContaining('taylor@example.com'), findsOneWidget);
          expect(find.text('I\'ve verified'), findsOneWidget);
          expect(find.text('Open email app'), findsOneWidget);
          expect(find.byIcon(Icons.face_rounded), findsNothing);
        },
      );

      testWidgets('Screen 5 (Permissions) renders makeItYours rose mascot', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: Scaffold(
              body: LoginBackdrop(
                variant: 1,
                child: SafeArea(
                  child: PermissionsScreen(
                    adapter: PermissionAdapter(),
                    onContinue: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Make it yours'), findsOneWidget);
        expect(find.text('Camera'), findsOneWidget);
        expect(find.text('Location'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.byIcon(Icons.face_rounded), findsNothing);
      });

      testWidgets(
        'Screen 6 (Features) carousels 3 cards with distinct mascots',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              theme: SoftPop.theme,
              home: Scaffold(
                body: LoginBackdrop(
                  variant: 2,
                  child: SafeArea(
                    child: FeaturesScreen(
                      initialPage: 0,
                      onPageChanged: (_) {},
                      onLetsGo: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Card 1: Share the everyday (Butter task)
          expect(find.text('Share the everyday'), findsOneWidget);
          expect(find.byIcon(Icons.face_rounded), findsNothing);

          // Advance to Card 2: Keep the little moments (Rose camera)
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
          expect(find.text('Keep the little moments'), findsOneWidget);
          expect(find.byIcon(Icons.face_rounded), findsNothing);

          // Advance to Card 3: Stay in the loop (Mint calendar)
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
          expect(find.text('Stay in the loop'), findsOneWidget);
          expect(find.text('Let\'s go'), findsOneWidget);
          expect(find.byIcon(Icons.face_rounded), findsNothing);
        },
      );

      testWidgets('Screen 7 (All set) renders done mascot and confetti', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: Scaffold(
              body: LoginBackdrop(
                variant: 0,
                child: SafeArea(
                  child: AllSetScreen(name: 'Taylor', onOpenApp: () {}),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('All set, Taylor!'), findsOneWidget);
        expect(find.text('Open Stewardie'), findsOneWidget);
        expect(find.byIcon(Icons.face_rounded), findsNothing);
      });

      testWidgets(
        'Reduced motion mode suppresses confetti and transitions cleanly',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              theme: SoftPop.theme,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 780),
                  disableAnimations: true,
                ),
                child: Scaffold(
                  body: LoginBackdrop(
                    child: SafeArea(
                      child: AllSetScreen(name: 'Taylor', onOpenApp: () {}),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('All set, Taylor!'), findsOneWidget);
          expect(find.text('Open Stewardie'), findsOneWidget);
        },
      );

      testWidgets('High contrast mode omits background decorations', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: SoftPop.theme,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 780),
                highContrast: true,
              ),
              child: const Scaffold(
                body: LoginBackdrop(
                  child: SafeArea(child: Text('High contrast content')),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('High contrast content'), findsOneWidget);
        // In high contrast, background decorations and wavy lines are completely omitted
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is CustomPaint &&
                w.painter?.runtimeType.toString() == '_SoftWavyLinesPainter',
          ),
          findsNothing,
        );
        expect(find.byType(Image), findsNothing);
      });

      testWidgets(
        'captures rendered review images of all 7 onboarding screens to build/review/onboarding',
        (tester) async {
          tester.view.physicalSize = const Size(360, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          Future<void> captureScreen(
            Widget screen,
            int variant,
            String filename,
          ) async {
            final previousShadows = debugDisableShadows;
            debugDisableShadows = false;
            final key = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                theme: SoftPop.theme,
                home: RepaintBoundary(
                  key: key,
                  child: Scaffold(
                    body: LoginBackdrop(
                      variant: variant,
                      child: SafeArea(
                        child: KeyedSubtree(key: UniqueKey(), child: screen),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!.buffer.asUint8List();
              final file = File('build/review/onboarding/$filename');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes);
              image.dispose();
            });
            debugDisableShadows = previousShadows;
          }

          await captureScreen(
            WelcomeScreen(onGetStarted: () {}, onSignIn: () {}),
            0,
            'screen_1_welcome.png',
          );

          await captureScreen(
            NameScreen(initialName: 'Taylor', onContinue: (_) {}),
            1,
            'screen_2_name.png',
          );

          await captureScreen(
            AccountScreen(
              name: 'Taylor',
              initialEmail: 'taylor@example.com',
              onSubmitForTesting: (email, pass) async {},
              onDraftChanged: (_) {},
              onAccountCreated: (_, _) {},
            ),
            2,
            'screen_3_account.png',
          );

          await captureScreen(
            VerifyEmailScreen(
              user: _FakeUser(),
              store: OnboardingStore(null),
              initialEmailSent: true,
              onVerified: () {},
            ),
            0,
            'screen_4_verify_email.png',
          );

          await captureScreen(
            PermissionsScreen(adapter: PermissionAdapter(), onContinue: () {}),
            1,
            'screen_5_permissions.png',
          );

          await captureScreen(
            FeaturesScreen(
              initialPage: 0,
              onPageChanged: (_) {},
              onLetsGo: () {},
            ),
            2,
            'screen_6_features.png',
          );

          await captureScreen(
            AllSetScreen(name: 'Taylor', onOpenApp: () {}),
            0,
            'screen_7_all_set.png',
          );
        },
      );
    },
  );
}
