import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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
  Timer? _retryTimer;
  final Map<String, DateTime> _pendingStops = {};
  DateTime? _expiresAt;
  DateTime? _lastSent;
  bool _sending = false;

  final ValueNotifier<bool> isSharing = ValueNotifier(false);
  final ValueNotifier<bool> stopPending = ValueNotifier(false);
  final ValueNotifier<bool> updatesUnavailable = ValueNotifier(false);
  final ValueNotifier<int> remainingMinutes = ValueNotifier(0);
  final ValueNotifier<Position?> currentPosition = ValueNotifier(null);
  String? get activeSpaceId => _activeSpaceId;

  void init(OnlineBackend backend) => _backend = backend;

  Future<void> restore() async {
    final backend = _backend;
    final uid = backend?.auth.currentUser?.uid;
    if (backend == null || uid == null || isSharing.value) return;
    try {
      final account = await backend.firestore.doc('accounts/$uid')
          .get(const GetOptions(source: Source.server));
      for (final spaceId in List<String>.from(account.data()?['spaceIds'] as List? ?? [])) {
        try {
          final session = await backend.firestore
              .doc('spaces/$spaceId/locationSessions/$uid')
              .get(const GetOptions(source: Source.server));
          if (isSharing.value || backend.auth.currentUser?.uid != uid) return;
          final expiry = (session.data()?['expiresAt'] as Timestamp?)?.toDate();
          if (expiry == null || !expiry.isAfter(DateTime.now().toUtc())) continue;
          _activeSpaceId = spaceId;
          _expiresAt = expiry;
          _lastSent = (session.data()?['updatedAt'] as Timestamp?)?.toDate();
          isSharing.value = true;
          _tick();
          _countdownTimer?.cancel();
          _countdownTimer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
          await _beginUpdates();
          return;
        } catch (_) {
          // An absent or expired session is expected for most spaces.
        }
      }
    } catch (_) {
      // Signed-in UI remains usable when restoring location is unavailable.
    }
  }

  Future<Position?> determinePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
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
    if (_pendingStops.containsKey(spaceId)) {
      await _retryStops();
      if (_pendingStops.containsKey(spaceId)) {
        throw StateError(
          'Waiting for the previous sharing session to stop. Try again shortly.',
        );
      }
    }
    final position = await determinePosition();
    if (position == null) {
      throw StateError('Turn on location access before sharing.');
    }
    if (isSharing.value) await stopSharing();
    late final Map<String, dynamic> result;
    try {
      result = await _backend!.call('startLocationSession', {
        'spaceId': spaceId,
        'durationMinutes': durationMinutes,
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
      });
    } catch (_) {
      // A lost acknowledgement could follow a successful write. Try to undo it.
      try {
        await _backend!.call('stopLocationSession', {'spaceId': spaceId});
      } catch (_) {
        _queueStop(
          spaceId,
          DateTime.now().toUtc().add(Duration(minutes: durationMinutes)),
        );
      }
      rethrow;
    }
    _activeSpaceId = spaceId;
    _expiresAt =
        DateTime.tryParse(result['expiresAt'] as String? ?? '') ??
        DateTime.now().toUtc().add(Duration(minutes: durationMinutes));
    _lastSent = DateTime.now().toUtc();
    updatesUnavailable.value = false;
    isSharing.value = true;
    _tick();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _tick(),
    );
    await _beginUpdates();
  }

  Future<void> _beginUpdates() async {
    await _positions?.cancel();
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      updatesUnavailable.value = true;
      return;
    }
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
    _positions = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) async {
          if (!isSharing.value || _activeSpaceId == null || _sending) return;
          final now = DateTime.now().toUtc();
          if (_lastSent != null &&
              now.difference(_lastSent!) < const Duration(seconds: 15)) {
            return;
          }
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
            updatesUnavailable.value = false;
          } catch (_) {
            updatesUnavailable.value = true;
            // The next position retries; never substitute a made-up coordinate.
          } finally {
            _sending = false;
          }
        }, onError: (_) => updatesUnavailable.value = true);
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
    updatesUnavailable.value = false;
    remainingMinutes.value = 0;
    final expiry = _expiresAt;
    _expiresAt = null;
    final spaceId = _activeSpaceId;
    _activeSpaceId = null;
    if (_backend == null || spaceId == null) return;
    try {
      await _backend!.call('stopLocationSession', {'spaceId': spaceId});
      _pendingStops.remove(spaceId);
      stopPending.value = _pendingStops.isNotEmpty;
    } catch (_) {
      _queueStop(
        spaceId,
        expiry ?? DateTime.now().toUtc().add(const Duration(minutes: 60)),
      );
    }
  }

  void _queueStop(String spaceId, DateTime expiry) {
    _pendingStops[spaceId] = expiry;
    stopPending.value = true;
    _retryTimer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => _retryStops(),
    );
  }

  Future<void> _retryStops() async {
    final backend = _backend;
    if (backend == null) return;
    for (final entry in _pendingStops.entries.toList()) {
      if (entry.value.isBefore(DateTime.now().toUtc())) {
        _pendingStops.remove(entry.key);
        continue;
      }
      try {
        await backend.call('stopLocationSession', {'spaceId': entry.key});
        _pendingStops.remove(entry.key);
      } catch (_) {
        // Retry while signed in; server rules deny reads once expiry is reached.
      }
    }
    stopPending.value = _pendingStops.isNotEmpty;
    if (_pendingStops.isEmpty) {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }
}
