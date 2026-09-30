import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// A manual recovery path remains useful when the OS cannot open its switch.
String get locationSettingsHint => defaultTargetPlatform == TargetPlatform.iOS
    ? 'In Settings, open Privacy & Security → Location Services and turn it on.'
    : 'In device Settings, open Location and turn it on.';

Future<bool> openDeviceLocationSettings() async {
  try {
    if (await Geolocator.openLocationSettings()) return true;
    return await Geolocator.openAppSettings();
  } catch (_) {
    return false;
  }
}
