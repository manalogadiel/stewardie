import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stewardie/app.dart';
import 'package:stewardie/core/backend_provider.dart';
import 'package:stewardie/core/demo_state.dart';
import 'package:stewardie/core/theme.dart';
import 'package:stewardie/features/timeline/data/demo_repository.dart';
import 'package:stewardie/online/online_backend.dart';
import 'package:stewardie/online/live_location_service.dart';
import 'package:stewardie/online/live_location_pill.dart';
import 'package:stewardie/online/qr_join_sheet.dart';

class _Backend extends Fake implements OnlineBackend {
  @override
  FirebaseAuth get auth => _Auth();
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;
}

void main() {
  testWidgets(
    'member shell selector restores create and code join entry points',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(
              DemoRepository(delay: Duration.zero),
            ),
            sharedBackendProvider.overrideWithValue(_Backend()),
          ],
          child: const StewardieApp(),
        ),
      );
      await tester.pumpAndSettle();
      // Fixture names are resolved from the same repository as the real selector.
      final name = ProviderScope.containerOf(
        tester.element(find.byType(StewardieApp)),
      ).read(repositoryProvider).spaces.first.name;
      final button = find.widgetWithText(TextButton, name);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Create a space'), findsOneWidget);
      expect(find.text('Join with a code'), findsOneWidget);
      await tester.tap(find.text('Create a space'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join with a code'));
      await tester.pumpAndSettle();
      expect(find.byType(QrJoinSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sharing panel fits enlarged text and End stops the local session',
    (tester) async {
      final service = LiveLocationService.instance;
      service.isSharing.value = true;
      service.remainingMinutes.value = 15;
      addTearDown(() async => service.stopSharing());
      await tester.pumpWidget(
        MaterialApp(
          theme: SoftPop.theme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: const Scaffold(
              body: SizedBox(width: 320, child: LiveLocationPill()),
            ),
          ),
        ),
      );
      expect(find.textContaining('15m left'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('End'));
      await tester.pumpAndSettle();
      expect(service.isSharing.value, isFalse);
      expect(find.text('End'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
