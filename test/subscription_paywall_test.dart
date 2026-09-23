import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/subscription/revenuecat_service.dart';
import 'package:stewardie/features/subscription/soft_pop_paywall.dart';

void main() {
  setUp(() {
    RevenueCatService.instance.setPlusSimulated(false);
  });

  test('RevenueCatService updates and notifies when Plus status changes', () {
    final service = RevenueCatService.instance;
    expect(service.isPlus, isFalse);

    int notifications = 0;
    service.addListener(() => notifications++);

    service.setPlusSimulated(true);
    expect(service.isPlus, isTrue);
    expect(notifications, 1);

    service.setPlusSimulated(false);
    expect(service.isPlus, isFalse);
    expect(notifications, 2);
  });

  testWidgets('SoftPopPaywall renders perks, pricing options, and triggers demo unlock', (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool purchasedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: SoftPop.theme,
        home: Scaffold(
          body: SoftPopPaywall(
            onPurchased: () => purchasedCalled = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify key titles and Soft Pop branding
    expect(find.text('STEWARDIE PLUS'), findsOneWidget);
    expect(find.text('A little more together'), findsOneWidget);

    // Verify all 4 perks are displayed
    expect(find.text('Up to 20 shared spaces'), findsOneWidget);
    expect(find.text('Full task completion history'), findsOneWidget);
    expect(find.text('Up to 5 photos per moment'), findsOneWidget);
    expect(find.text('Personal Plus badge'), findsOneWidget);

    // Verify annual and monthly options
    expect(find.text('Annual'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Save 27%'), findsOneWidget);

    // Verify primary action button
    expect(find.text('Start Annual Plus'), findsOneWidget);

    // Tap on Monthly to switch plan
    await tester.ensureVisible(find.text('Monthly'));
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.text('Start Monthly Plus'), findsOneWidget);

    // Verify Judge Demo Unlock button
    final judgeDemoBtn = find.text('Judge Demo Unlock');
    await tester.ensureVisible(judgeDemoBtn);
    expect(judgeDemoBtn, findsOneWidget);

    await tester.tap(judgeDemoBtn);
    await tester.pumpAndSettle();

    expect(purchasedCalled, isTrue);
    expect(RevenueCatService.instance.isPlus, isTrue);
  });
}
