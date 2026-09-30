import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/app.dart';
import 'package:stewardie/core/backend_provider.dart';
import 'package:stewardie/core/demo_state.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_coordinator.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_state.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_target_registry.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/online/online_backend.dart';

class _MapOnlyBackend extends Fake implements OnlineBackend {
  @override
  FirebaseAuth get auth => _SignedOutAuth();
}

class _SignedOutAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;
}

void main() {
  testWidgets(
    'tour reveals real routed controls including the lazy task header',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(
              DemoRepository(delay: Duration.zero),
            ),
            sharedBackendProvider.overrideWithValue(_MapOnlyBackend()),
          ],
          child: const StewardieApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StewardieApp)),
      );
      final router = container.read(routerProvider);
      final running = TutorialCoordinator(null).replayTour(
        tester.element(find.byType(AppShell)),
        uid: 'route-test',
        onTabRequested: (tab) =>
            router.go(['/today', '/moments', '/space'][tab]),
      );
      for (final stop in TutorialStops.all) {
        Rect? rect;
        for (var i = 0; i < 35; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          rect = TutorialTargetRegistry.getTargetRect(
            TutorialTargetRegistry.keyForId(stop.targetKeyGetter()),
          );
          if (rect != null && i >= 3) break;
        }
        expect(
          rect,
          isNotNull,
          reason: '${stop.id} must have a real routed target',
        );
        if (stop.id == TutorialStopId.askCoverFinish) {
          expect(
            rect!.top,
            greaterThanOrEqualTo(90),
            reason: 'The task header must remain below the floating navigation',
          );
        }
        expect(find.text('This part has not loaded.'), findsNothing);
        expect(tester.takeException(), isNull);
        final advance = find.text(
          stop == TutorialStops.all.last ? 'Got it' : 'Next',
        );
        await tester.ensureVisible(advance);
        await tester.pumpAndSettle();
        await tester.tap(advance);
        await tester.pumpAndSettle();
      }
      await running;
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
