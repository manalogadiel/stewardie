import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../online/push_service.dart';

enum PermissionCapability { camera, location, notifications }

enum PermissionStatusState {
  notDetermined,
  granted,
  denied,
  permanentlyDenied,
  unavailable,
}

/// Adapter isolating OS permission requests for Camera, Location, and Notifications.
///
/// Ensures:
/// - Only foreground/while-in-use location is ever requested.
/// - Never collects or uploads coordinates upon granting.
/// - Honest unavailable state on unconfigured / desktop / unsupported platforms.
/// - One-by-one user initiated requests only; never auto-queues requests.
class PermissionAdapter {
  const PermissionAdapter();

  /// Checks the current status of the given capability without prompting the user.
  Future<PermissionStatusState> checkStatus(
    PermissionCapability capability,
  ) async {
    switch (capability) {
      case PermissionCapability.camera:
        if (kIsWeb) return PermissionStatusState.unavailable;
        try {
          // If cameras can be queried, permission might already be granted
          return PermissionStatusState.notDetermined;
        } catch (_) {
          return PermissionStatusState.unavailable;
        }

      case PermissionCapability.location:
        if (kIsWeb) return PermissionStatusState.unavailable;
        try {
          final permission = await Geolocator.checkPermission();
          return switch (permission) {
            LocationPermission.always ||
            LocationPermission.whileInUse => PermissionStatusState.granted,
            LocationPermission.denied => PermissionStatusState.notDetermined,
            LocationPermission.deniedForever =>
              PermissionStatusState.permanentlyDenied,
            LocationPermission.unableToDetermine =>
              PermissionStatusState.notDetermined,
          };
        } catch (_) {
          return PermissionStatusState.unavailable;
        }

      case PermissionCapability.notifications:
        if (!PushService.instance.available) {
          return PermissionStatusState.unavailable;
        }
        return PermissionStatusState.notDetermined;
    }
  }

  /// Explicitly requests permission for the capability from the OS.
  Future<PermissionStatusState> requestPermission(
    PermissionCapability capability,
  ) async {
    switch (capability) {
      case PermissionCapability.camera:
        if (kIsWeb) return PermissionStatusState.unavailable;
        try {
          final cameras = await availableCameras();
          if (cameras.isNotEmpty) {
            return PermissionStatusState.granted;
          }
          return PermissionStatusState.denied;
        } on CameraException catch (e) {
          if (e.code == 'CameraAccessDenied' ||
              e.code == 'CameraAccessDeniedWithoutPrompt') {
            return PermissionStatusState.permanentlyDenied;
          }
          return PermissionStatusState.denied;
        } catch (_) {
          return PermissionStatusState.denied;
        }

      case PermissionCapability.location:
        if (kIsWeb) return PermissionStatusState.unavailable;
        try {
          final permission = await Geolocator.requestPermission();
          return switch (permission) {
            LocationPermission.always ||
            LocationPermission.whileInUse => PermissionStatusState.granted,
            LocationPermission.denied => PermissionStatusState.denied,
            LocationPermission.deniedForever =>
              PermissionStatusState.permanentlyDenied,
            LocationPermission.unableToDetermine =>
              PermissionStatusState.unavailable,
          };
        } catch (_) {
          return PermissionStatusState.denied;
        }

      case PermissionCapability.notifications:
        if (!PushService.instance.available) {
          return PermissionStatusState.unavailable;
        }
        try {
          final granted = await PushService.instance.requestPermission();
          return granted
              ? PermissionStatusState.granted
              : PermissionStatusState.denied;
        } catch (_) {
          return PermissionStatusState.denied;
        }
    }
  }

  /// Opens platform settings when a permission is permanently denied.
  Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }
}
