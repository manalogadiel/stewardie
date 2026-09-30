import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stewardie/online/live_location_service.dart';
import 'package:stewardie/online/member_location_pin.dart';
import 'package:stewardie/online/online_backend.dart';
import 'package:stewardie/online/space_map_sheet.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'map-owner';
  @override
  String get displayName => 'Alexandria Catherine Montgomery';
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _Backend extends Fake implements OnlineBackend {
  @override
  FirebaseAuth get auth => _Auth();
}

class _Location extends GeolocatorPlatform {
  final Position position;
  _Location(this.position);
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => position;
}

void main() {
  testWidgets(
    'actual private map keeps selected-person details and Close reachable at enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      final original = GeolocatorPlatform.instance;
      final position = Position(
        latitude: 14.6,
        longitude: 121.0,
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
        accuracy: 25,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      GeolocatorPlatform.instance = _Location(position);
      LiveLocationService.instance.currentPosition.value = position;
      addTearDown(() {
        GeolocatorPlatform.instance = original;
        LiveLocationService.instance.currentPosition.value = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: Scaffold(body: SpaceMapSheet(backend: _Backend())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(MemberLocationPin));
      // Widget tests synthesize failed HTTP tiles and the retry card covers
      // the map center. Select through the real pin handler to test its panel.
      final pinHandler = find
          .ancestor(
            of: find.byType(MemberLocationPin),
            matching: find.byType(GestureDetector),
          )
          .first;
      tester.widget<GestureDetector>(pinHandler).onTap!();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Private · not shared · Stale'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Directions'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Close'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
