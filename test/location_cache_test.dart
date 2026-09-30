import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stewardie/online/online_backend.dart';
import 'package:stewardie/online/live_location_service.dart';

class _Location extends GeolocatorPlatform {
  int fixes = 0;
  LocationPermission permission = LocationPermission.whileInUse;
  final result = Completer<Position>();
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    fixes++;
    return result.future;
  }
}

class _User extends Fake implements User {
  _User(this.accountUid);
  final String accountUid;
  @override
  String get uid => accountUid;
}

class _Auth extends Fake implements FirebaseAuth {
  String accountUid = 'location-test';
  @override
  User get currentUser => _User(accountUid);
}

// The sharing service now resolves its space label before requesting GPS.
// Test-only SDK mock; sealed Firestore types have no public constructors.
// ignore: subtype_of_sealed_class
class _SpaceSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  Map<String, dynamic>? data() => {'name': 'Test space'};
}

// ignore: subtype_of_sealed_class
class _SpaceDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _SpaceSnapshot();
}

class _Firestore extends Fake implements FirebaseFirestore {
  @override
  DocumentReference<Map<String, dynamic>> doc(String path) => _SpaceDocument();
}

class _Backend extends Fake implements OnlineBackend {
  @override
  FirebaseFirestore get firestore => _Firestore();
  final started = Completer<void>();
  final response = Completer<Map<String, dynamic>>();
  int stops = 0;
  bool failStops = false;
  final _Auth identity = _Auth();
  @override
  FirebaseAuth get auth => identity;
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
    bool feedback = true,
  ]) async {
    if (action == 'startLocationSession') {
      started.complete();
      return response.future;
    }
    stops++;
    if (failStops) throw StateError('Offline');
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('queued Stop retries only under its original account', (
    tester,
  ) async {
    final original = GeolocatorPlatform.instance;
    final platform = _Location();
    final backend = _Backend()..failStops = true;
    final service = LiveLocationService.instance;
    GeolocatorPlatform.instance = platform;
    service.init(backend);
    final position = Position(
      latitude: 14.6,
      longitude: 121,
      timestamp: DateTime.now(),
      accuracy: 15,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    service.currentPosition.value = position;
    addTearDown(() {
      service.currentPosition.value = null;
      GeolocatorPlatform.instance = original;
    });
    final rejected = expectLater(
      service.startSharing(spaceId: 'space', durationMinutes: 15),
      throwsStateError,
    );
    await tester.pump();
    await backend.started.future;
    await service.stopSharing();
    backend.response.complete({
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 15))
          .toIso8601String(),
    });
    await tester.pump();
    await rejected;
    expect(service.stopPending.value, true);
    backend.identity.accountUid = 'another-account';
    service.init(backend);
    expect(service.stopPending.value, false);
    await tester.pump(const Duration(seconds: 16));
    expect(backend.stops, 1);
    backend.identity.accountUid = 'location-test';
    backend.failStops = false;
    service.init(backend);
    expect(service.stopPending.value, true);
    await tester.pump(const Duration(seconds: 16));
    expect(backend.stops, 2);
    expect(service.stopPending.value, false);
  });
  test('Stop cancels a pending acknowledgement and prevents late collection restart', () async {
    final original = GeolocatorPlatform.instance;
    final platform = _Location();
    final backend = _Backend();
    final service = LiveLocationService.instance;
    GeolocatorPlatform.instance = platform;
    service.init(backend);
    final position = Position(
      latitude: 14.6,
      longitude: 121,
      timestamp: DateTime.now(),
      accuracy: 15,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    platform.result.complete(position);
    service.currentPosition.value = position;
    addTearDown(() {
      service.currentPosition.value = null;
      GeolocatorPlatform.instance = original;
    });
    final starting = service.startSharing(
      spaceId: 'space',
      durationMinutes: 15,
    );
    final rejected = expectLater(starting, throwsStateError);
    await backend.started.future;
    await service.stopSharing();
    backend.response.complete({
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 15))
          .toIso8601String(),
    });
    await rejected;
    expect(service.isSharing.value, false);
    expect(service.activeSpaceId, isNull);
    expect(backend.stops, 1);
  });
  test('overlapping requests share a fix; reopening uses permission-checked recent cache', () async {
    final original = GeolocatorPlatform.instance;
    final platform = _Location();
    final service = LiveLocationService.instance;
    GeolocatorPlatform.instance = platform;
    service.currentPosition.value = null;
    addTearDown(() {
      service.currentPosition.value = null;
      GeolocatorPlatform.instance = original;
    });
    final first = service.determinePosition();
    final second = service.determinePosition();
    await Future<void>.delayed(Duration.zero);
    expect(platform.fixes, 1);
    final position = Position(
      latitude: 14.6,
      longitude: 121.0,
      timestamp: DateTime.now(),
      accuracy: 15,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    platform.result.complete(position);
    expect(await first, position);
    expect(await second, position);
    expect(await service.determinePosition(), position);
    expect(platform.fixes, 1);
    platform.permission = LocationPermission.deniedForever;
    expect(await service.determinePosition(), isNull);
    expect(platform.fixes, 1);
  });
}
