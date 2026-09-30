import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/app.dart';
import 'package:stewardie/core/demo_state.dart';
import 'package:stewardie/core/soft_pop_backdrop.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/onboarding/tutorial/tutorial_target_registry.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';

void main() {
  for (final device in [
    (390.0, 844.0, 47.0), // Notch.
    (393.0, 852.0, 59.0), // Dynamic Island.
    (430.0, 932.0, 62.0), // Larger Dynamic Island phone.
  ]) {
    testWidgets('edge-to-edge shell respects iPhone top inset ${device.$3}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(device.$1, device.$2);
      tester.view.padding = FakeViewPadding(top: device.$3, bottom: 34);
      tester.view.viewPadding = FakeViewPadding(top: device.$3, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(
              DemoRepository(delay: Duration.zero),
            ),
          ],
          child: MaterialApp(
            theme: SoftPop.theme,
            home: const AppShell(
              path: '/today',
              child: ColoredBox(
                key: ValueKey('page-paint'),
                color: SoftPop.today,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selector = tester.getRect(
        find.byKey(TutorialTargetRegistry.spaceSelectorTarget),
      );
      expect(selector.top, greaterThanOrEqualTo(device.$3 + 12));
      final backdrop = tester.getRect(find.byType(SoftPopBackdrop));
      expect(backdrop.top, 0);
      expect(backdrop.bottom, device.$2);
      final paint = tester.getRect(find.byKey(const ValueKey('page-paint')));
      expect(paint.top, 0);
      expect(paint.width, device.$1);
      expect(paint.bottom, device.$2);
      final dock = tester.getRect(find.byType(GlassDock));
      expect(dock.bottom, lessThanOrEqualTo(device.$2 - 34));
      expect(tester.takeException(), isNull);
    });
  }
}
