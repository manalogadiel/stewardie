import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/onboarding/screens/account_screen.dart';

void main() {
  testWidgets('notices open before signup and preserve the email draft', (
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
          body: AccountScreen(
            name: 'Diel',
            initialEmail: 'diel@example.com',
            onAccountCreated: (_, _) {},
            onDraftChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Privacy Notice'));
    await tester.tap(find.text('Privacy Notice'));
    await tester.pumpAndSettle();
    expect(find.text('What your space can see'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Camera and location'),
      150,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Camera and location'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('diel@example.com'), findsOneWidget);
    await tester.ensureVisible(find.text('Community Guidelines'));
    await tester.tap(find.text('Community Guidelines'));
    await tester.pumpAndSettle();
    expect(find.text('Share with permission'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
