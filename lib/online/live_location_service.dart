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
  final Map<(String, String), DateTime> _pendingStops = {};
  DateTime? _expiresAt;
  DateTime? _lastSent;
  bool _sending = false;
  int _sharingRevision = 0;
  bool _startPending = false;

  final ValueNotifier<bool> isSharing = ValueNotifier(false);
  final ValueNotifier<bool> stopPending = ValueNotifier(false);
  final ValueNotifier<bool> updatesUnavailable = ValueNotifier(false);
  final ValueNotifier<int> remainingMinutes = ValueNotifier(0);
  final ValueNotifier<Position?> currentPosition = ValueNotifier(null);
  String? get activeSpaceId => _activeSpaceId;
  String get presentationSessionKey => '$_activeSpaceId/$_expiresAt';
  bool get _hasCurrentAccountStops => _pendingStops.keys.any(
    (key) => key.$1 == _backend?.auth.currentUser?.uid,
  );

  void init(OnlineBackend backend) {
    _backend = backend;
    stopPending.value = _hasCurrentAccountStops;
  }

  Future<void> restore() async {
    final backend = _backend;
    final uid = backend?.auth.currentUser?.uid;
    final revision = _sharingRevision;
    if (backend == null || uid == null || isSharing.value || _startPending) {
      return;
    }
    try {
      final account = await backend.firestore
          .doc('accounts/$uid')
          .get(const GetOptions(source: Source.server));
      for (final spaceId in List<String>.from(
        account.data()?['spaceIds'] as List? ?? [],
      )) {
        try {
          final session = await backend.firestore
              .doc('spaces/$spaceId/locationSessions/$uid')
              .get(const GetOptions(source: Source.server));
          if (isSharing.value ||
              _startPending ||
              revision != _sharingRevision ||
              backend.auth.currentUser?.uid != uid) {
            return;
          }
          final expiry = (session.data()?['expiresAt'] as Timestamp?)?.toDate();
          if (expiry == null || !expiry.isAfter(DateTime.now().toUtc())) {
            continue;
          }
          _activeSpaceId = spaceId;
          _expiresAt = expiry;
          _lastSent = (session.data()?['updatedAt'] as Timestamp?)?.toDate();
          isSharing.value = true;
          _tick();
          _countdownTimer?.cancel();
          _countdownTimer = Timer.periodic(
            const Duration(seconds: 15),
            (_) => _tick(),
          );
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

  Future<Position?>? _positionRequest;

  Future<Position?> determinePosition() async {
    final pending = _positionRequest;
    if (pending != null) return pending;
    final request = _determinePosition();
    _positionRequest = request;
    try {
      return await request;
    } finally {
      if (identical(_positionRequest, request)) _positionRequest = null;
    }
  }

  Future<Position?> _determinePosition() async {
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
      final recent = currentPosition.value;
      if (recent != null &&
          DateTime.now().toUtc().difference(recent.timestamp.toUtc()).abs() <
              const Duration(seconds: 30)) {
        return recent;
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
    if (_startPending) {
      throw StateError('A sharing request is still finishing.');
    }
    _startPending = true;
    try {
      await _startSharing(spaceId: spaceId, durationMinutes: durationMinutes);
    } finally {
      _startPending = false;
    }
  }

  Future<void> _startSharing({
    required String spaceId,
    required int durationMinutes,
  }) async {
    final backend = _backend;
    final uid = backend?.auth.currentUser?.uid;
    if (backend == null || uid == null) {
      throw StateError('Sign in before sharing.');
    }
    if (![15, 30, 60].contains(durationMinutes)) {
      throw ArgumentError('Choose 15, 30, or 60 minutes.');
    }
    if (isSharing.value) await stopSharing();
    final revision = ++_sharingRevision;
    bool current() =>
        revision == _sharingRevision &&
        identical(backend, _backend) &&
        backend.auth.currentUser?.uid == uid;
    if (_pendingStops.containsKey((uid, spaceId))) {
      await _retryStops();
      if (_pendingStops.containsKey((uid, spaceId))) {
        throw StateError(
          'Waiting for the previous sharing session to stop. Try again shortly.',
        );
      }
    }
    final position = await determinePosition();
    if (!current()) throw StateError('Sharing was cancelled.');
    if (position == null) {
      throw StateError('Turn on location access before sharing.');
    }
    if (!position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > 10000) {
      throw StateError(
        'Your location fix is too imprecise to share. Enable precise location or try again where GPS is available.',
      );
    }
    late final Map<String, dynamic> result;
    try {
      result = await backend.call('startLocationSession', {
        'spaceId': spaceId,
        'durationMinutes': durationMinutes,
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
      });
      if (!current()) throw StateError('Sharing was cancelled.');
    } catch (_) {
      // A lost acknowledgement could follow a successful write. Try to undo it.
      // Never issue an old account's cleanup as the newly signed-in account.
      if (backend.auth.currentUser?.uid == uid) {
        try {
          await backend.call('stopLocationSession', {'spaceId': spaceId});
        } catch (_) {
          _queueStop(
            uid,
            spaceId,
            DateTime.now().toUtc().add(Duration(minutes: durationMinutes)),
          );
        }
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
    try {
      await _beginUpdates();
    } catch (_) {
      // The server acknowledged sharing. A native stream failure must not
      // hide the active session or its End action from the member.
      updatesUnavailable.value = true;
    }
  }

  Future<void> _beginUpdates() async {
    final revision = _sharingRevision;
    await _positions?.cancel();
    if (!isSharing.value || revision != _sharingRevision) return;
    final permission = await Geolocator.checkPermission();
    if (!isSharing.value || revision != _sharingRevision) return;
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
    final backend = _backend;
    final uid = backend?.auth.currentUser?.uid;
    _sharingRevision++;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    final positions = _positions;
    _positions = null;
    isSharing.value = false;
    updatesUnavailable.value = false;
    remainingMinutes.value = 0;
    final expiry = _expiresAt;
    _expiresAt = null;
    final spaceId = _activeSpaceId;
    _activeSpaceId = null;
    await positions?.cancel();
    if (backend == null || uid == null || spaceId == null) return;
    try {
      if (backend.auth.currentUser?.uid != uid) return;
      await backend.call('stopLocationSession', {'spaceId': spaceId});
      _pendingStops.remove((uid, spaceId));
      stopPending.value = _hasCurrentAccountStops;
    } catch (_) {
      _queueStop(
        uid,
        spaceId,
        expiry ?? DateTime.now().toUtc().add(const Duration(minutes: 60)),
      );
    }
  }

  void _queueStop(String uid, String spaceId, DateTime expiry) {
    _pendingStops[(uid, spaceId)] = expiry;
    stopPending.value = _hasCurrentAccountStops;
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
      if (backend.auth.currentUser?.uid != entry.key.$1) continue;
      try {
        await backend.call('stopLocationSession', {'spaceId': entry.key.$2});
        _pendingStops.remove(entry.key);
      } catch (_) {
        // Retry while signed in; server rules deny reads once expiry is reached.
      }
    }
    stopPending.value = _hasCurrentAccountStops;
    if (_pendingStops.isEmpty) {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }
}
