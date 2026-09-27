import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// OneSignal delivers generic push only. Task state and the inbox live in
/// Firebase and continue to work if the push provider is unavailable.
class PushService {
  PushService._();
  static final instance = PushService._();
  static const appId = String.fromEnvironment('ONESIGNAL_APP_ID');
  bool _initialized = false;

  bool get available =>
      !kIsWeb &&
      appId.isNotEmpty &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void init(String uid) {
    if (!available) return;
    if (!_initialized) {
      OneSignal.initialize(appId);
      _initialized = true;
    }
    OneSignal.login(uid);
  }

  Future<void> requestPermission() async {
    if (!available) return;
    await OneSignal.Notifications.requestPermission(false);
  }

  void logOut() {
    if (_initialized) OneSignal.logout();
  }
}
