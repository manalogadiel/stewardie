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

  test('RevenueCat execution results handle cancelled, pending, and sync outcomes distinctly', () {
    const cancelled = PurchaseExecutionResult(
      PurchaseStatus.cancelled,
      message: 'Purchase was cancelled.',
    );
    expect(cancelled.isSuccess, isFalse);
    expect(cancelled.status, PurchaseStatus.cancelled);

    const pending = PurchaseExecutionResult(
      PurchaseStatus.pending,
      message: 'Purchase is pending approval.',
    );
    expect(pending.isSuccess, isFalse);
    expect(pending.status, PurchaseStatus.pending);

    const syncPending = PurchaseExecutionResult(
      PurchaseStatus.syncPending,
      message: 'Purchase verified. Account benefits update after secure synchronization.',
    );
    expect(syncPending.isSuccess, isFalse);
    expect(syncPending.status, PurchaseStatus.syncPending);

    const restoreSuccess = RestoreExecutionResult(
      RestoreStatus.success,
      message: 'Purchases restored successfully.',
    );
    expect(restoreSuccess.isSuccess, isTrue);
    expect(restoreSuccess.status, RestoreStatus.success);

    const restoreSyncPending = RestoreExecutionResult(
      RestoreStatus.syncPending,
      message: 'Purchases found. Syncing with your account...',
    );
    expect(restoreSyncPending.isSuccess, isFalse);
    expect(restoreSyncPending.status, RestoreStatus.syncPending);
  });

  test('RevenueCat configuration paths guard test keys and track subscription activity independently', () {
    // 1. Environment and apiKey guards
    final env = RevenueCatService.environment;
    final purchasesEnabled = RevenueCatService.purchasesEnabled;
    if (env == RevenueCatEnvironment.off) {
      expect(purchasesEnabled, isFalse);
    } else {
      expect(purchasesEnabled, isTrue);
    }

    // 2. Explicit platform key helper returns null when no overrides are passed
    expect(RevenueCatService.explicitPlatformKey, isNull);

    // 3. Service getters track subscription activity independently from founder status
    final service = RevenueCatService.instance;
    expect(service.isSubscriptionActive, isFalse);
    expect(service.isFounder, isFalse);
    expect(service.isPlus, isFalse);
    expect(service.entitlementSource, isNull);
    expect(service.subscriptionExpiry, isNull);
    expect(service.subscriptionStore, isNull);
    expect(service.subscriptionProductId, isNull);
  });
}
