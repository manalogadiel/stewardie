import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';

import 'online_backend.dart';

/// A sharing session starts only after a real fix and an acknowledged write.
/// The server rules, not this timer, are the remote access boundary.
class LiveLocationService {
  LiveLocationService._();
  static final LiveLocationService instance = LiveLocationService._();

  OnlineBackend? _backend;
  String? _activeSpaceId;
  StreamSubscription<Position>? _positions;
  Timer? _countdownTimer;
  DateTime? _expiresAt;
  DateTime? _lastSent;
  bool _sending = false;

  final ValueNotifier<bool> isSharing = ValueNotifier(false);
  final ValueNotifier<bool> stopPending = ValueNotifier(false);
  final ValueNotifier<int> remainingMinutes = ValueNotifier(0);
  final ValueNotifier<Position?> currentPosition = ValueNotifier(null);
  String? get activeSpaceId => _activeSpaceId;

  void init(OnlineBackend backend) => _backend = backend;

  Future<Position?> determinePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return null;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      currentPosition.value = position;
      return position;
    } catch (_) {
      return null;
    }
  }

  Future<void> startSharing({
    required String spaceId,
    required int durationMinutes,
  }) async {
    if (_backend == null) throw StateError('Location is unavailable.');
    if (![15, 30, 60].contains(durationMinutes)) {
      throw ArgumentError('Choose 15, 30, or 60 minutes.');
    }
    final position = await determinePosition();
    if (position == null) {
      throw StateError('Turn on location access before sharing.');
    }
    if (isSharing.value) await stopSharing();
    final result = await _backend!.call('startLocationSession', {
      'spaceId': spaceId,
      'durationMinutes': durationMinutes,
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': position.accuracy,
    });
    _activeSpaceId = spaceId;
    _expiresAt = DateTime.tryParse(result['expiresAt'] as String? ?? '') ??
        DateTime.now().toUtc().add(Duration(minutes: durationMinutes));
    _lastSent = DateTime.now().toUtc();
    stopPending.value = false;
    isSharing.value = true;
    _tick();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
    _positions?.cancel();
    final settings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 30,
          intervalDuration: const Duration(seconds: 20),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Stewardie location sharing',
            notificationText: 'Your chosen space can see your location until you stop or time runs out.',
            enableWakeLock: true,
          ),
        ),
      TargetPlatform.iOS => AppleSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 30,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
          pauseLocationUpdatesAutomatically: false,
        ),
      _ => const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 30,
        ),
    };
    _positions = Geolocator.getPositionStream(locationSettings: settings).listen(
      (position) async {
        if (!isSharing.value || _activeSpaceId == null || _sending) return;
        final now = DateTime.now().toUtc();
        if (_lastSent != null && now.difference(_lastSent!) < const Duration(seconds: 15)) return;
        _sending = true;
        try {
          await _backend!.call('updateLocation', {
            'spaceId': _activeSpaceId,
            'lat': position.latitude,
            'lng': position.longitude,
            'accuracy': position.accuracy,
          });
          _lastSent = now;
          currentPosition.value = position;
        } catch (_) {
          // The next position retries; never substitute a made-up coordinate.
        } finally {
          _sending = false;
        }
      },
      onError: (_) {},
    );
  }

  void _tick() {
    final expiry = _expiresAt;
    if (expiry == null) return;
    final remaining = expiry.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      unawaited(stopSharing());
    } else {
      remainingMinutes.value = (remaining.inSeconds / 60).ceil();
    }
  }

  Future<void> stopSharing() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    await _positions?.cancel();
    _positions = null;
    isSharing.value = false;
    remainingMinutes.value = 0;
    _expiresAt = null;
    final spaceId = _activeSpaceId;
    _activeSpaceId = null;
    if (_backend == null || spaceId == null) return;
    stopPending.value = true;
    try {
      await _backend!.call('stopLocationSession', {'spaceId': spaceId});
      stopPending.value = false;
    } catch (_) {
      // Remote access remains bounded by the session's server-checked expiry.
    }
  }
}
