import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/subscription/revenuecat_service.dart';
import 'package:stewardie/features/subscription/soft_pop_paywall.dart';

void main() {
  testWidgets(
    'missing offerings cannot unlock Plus or claim purchase success',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var purchased = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: Scaffold(
            body: SoftPopPaywall(onPurchased: () => purchased = true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Judge Demo Unlock'), findsNothing);
      expect(find.text('Save 27%'), findsNothing);
      final button = find.widgetWithText(
        FilledButton,
        'Purchases are not available yet',
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(purchased, isFalse);
      expect(RevenueCatService.instance.isPlus, isFalse);
      await RevenueCatService.instance.logOut();
      expect(RevenueCatService.instance.offerings, isNull);
    },
  );
}
