import 'dart:async';
import 'package:flutter/foundation.dart';

import 'online_backend.dart';

/// Service managing temporary live location sharing sessions (15, 30, 60 minutes).
class LiveLocationService {
  LiveLocationService._();
  static final LiveLocationService instance = LiveLocationService._();

  OnlineBackend? _backend;
  String? _activeSpaceId;
  Timer? _countdownTimer;
  DateTime? _expiresAt;

  final ValueNotifier<bool> isSharing = ValueNotifier<bool>(false);
  final ValueNotifier<int> remainingMinutes = ValueNotifier<int>(0);

  void init(OnlineBackend backend) {
    _backend = backend;
  }

  Future<void> startSharing({
    required String spaceId,
    required int durationMinutes,
    double lat = 37.7749,
    double lng = -122.4194,
  }) async {
    if (_backend == null) return;
    _activeSpaceId = spaceId;
    _expiresAt = DateTime.now().toUtc().add(Duration(minutes: durationMinutes));
    isSharing.value = true;
    remainingMinutes.value = durationMinutes;

    await _backend!.call('startLocationSession', {
      'spaceId': spaceId,
      'durationMinutes': durationMinutes,
      'lat': lat,
      'lng': lng,
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
  }

  Future<void> stopSharing() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
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
