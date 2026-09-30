import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as native;
import '../../online/push_service.dart';

enum PermissionCapability { camera, location, notifications }
enum PermissionStatusState { notDetermined, granted, denied, permanentlyDenied, unavailable }

/// Only explicit user actions request access; checks reflect the OS, not UI cache.
class PermissionAdapter {
  const PermissionAdapter();
  bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  static PermissionStatusState mapStatus(native.PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) return PermissionStatusState.granted;
    if (status.isPermanentlyDenied || status.isRestricted) return PermissionStatusState.permanentlyDenied;
    return PermissionStatusState.denied;
  }
  native.Permission _permission(PermissionCapability capability) => switch (capability) {
    PermissionCapability.camera => native.Permission.camera,
    PermissionCapability.location => native.Permission.locationWhenInUse,
    PermissionCapability.notifications => native.Permission.notification,
  };
  Future<PermissionStatusState> checkStatus(PermissionCapability capability) async {
    if (!supported || (capability == PermissionCapability.notifications && !PushService.instance.available)) return PermissionStatusState.unavailable;
    try { return mapStatus(await _permission(capability).status); }
    catch (_) { return PermissionStatusState.unavailable; }
  }
  Future<PermissionStatusState> requestPermission(PermissionCapability capability) async {
    if (!supported) return PermissionStatusState.unavailable;
    try {
      if (capability == PermissionCapability.notifications) {
        if (!PushService.instance.available) return PermissionStatusState.unavailable;
        await PushService.instance.requestPermission();
        return checkStatus(capability);
      }
      return mapStatus(await _permission(capability).request());
    } catch (_) { return PermissionStatusState.unavailable; }
  }
  Future<bool> locationServicesEnabled() async => !supported || await Geolocator.isLocationServiceEnabled();
  Future<void> openLocationSettings() async { if (supported) await Geolocator.openLocationSettings(); }
  Future<void> openSettings() async { if (supported) await native.openAppSettings(); }
}
