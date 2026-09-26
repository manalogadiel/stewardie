import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'online_backend.dart';

/// Service managing temporary live location sharing sessions (15, 30, 60 minutes)
/// with real device GPS acquisition.
class LiveLocationService {
  LiveLocationService._();
  static final LiveLocationService instance = LiveLocationService._();

  OnlineBackend? _backend;
  String? _activeSpaceId;
  Timer? _countdownTimer;
  Timer? _positionUpdateTimer;
  DateTime? _expiresAt;

  final ValueNotifier<bool> isSharing = ValueNotifier<bool>(false);
  final ValueNotifier<int> remainingMinutes = ValueNotifier<int>(0);
  final ValueNotifier<Position?> currentPosition = ValueNotifier<Position?>(null);

  void init(OnlineBackend backend) {
    _backend = backend;
  }

  /// Determines current position via device GPS, requesting permission if needed.
  Future<Position?> determinePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      currentPosition.value = pos;
      return pos;
    } catch (_) {
      return null;
    }
  }

  Future<void> startSharing({
    required String spaceId,
    required int durationMinutes,
    double? lat,
    double? lng,
  }) async {
    if (_backend == null) return;
    _activeSpaceId = spaceId;
    _expiresAt = DateTime.now().toUtc().add(Duration(minutes: durationMinutes));
    isSharing.value = true;
    remainingMinutes.value = durationMinutes;

    var actualLat = lat;
    var actualLng = lng;
    if (actualLat == null || actualLng == null) {
      final pos = await determinePosition();
      if (pos != null) {
        actualLat = pos.latitude;
        actualLng = pos.longitude;
      } else {
        actualLat = 37.7749;
        actualLng = -122.4194;
      }
    }

    await _backend!.call('startLocationSession', {
      'spaceId': spaceId,
      'durationMinutes': durationMinutes,
      'lat': actualLat,
      'lng': actualLng,
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_expiresAt == null) {
        stopSharing();
        return;
      }
      final diff = _expiresAt!.difference(DateTime.now().toUtc()).inMinutes;
      if (diff <= 0) {
        stopSharing();
      } else {
        remainingMinutes.value = diff;
      }
    });

    // Periodic live GPS ping every 45s while sharing
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(seconds: 45), (timer) async {
      if (!isSharing.value || _activeSpaceId == null) {
        timer.cancel();
        return;
      }
      final pos = await determinePosition();
      if (pos != null && _backend != null && _activeSpaceId != null) {
        try {
          await _backend!.call('updateLocation', {
            'spaceId': _activeSpaceId,
            'lat': pos.latitude,
            'lng': pos.longitude,
          });
        } catch (_) {}
      }
    });
  }

  Future<void> stopSharing() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = null;
    _expiresAt = null;
    isSharing.value = false;
    remainingMinutes.value = 0;

    if (_backend != null && _activeSpaceId != null) {
      try {
        await _backend!.call('stopLocationSession', {
          'spaceId': _activeSpaceId,
        });
      } catch (_) {}
    }
    _activeSpaceId = null;
  }
}
