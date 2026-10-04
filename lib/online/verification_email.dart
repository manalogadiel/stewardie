import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Custom sender secrets and recipient selection remain entirely on the server.
class VerificationEmail {
  static const enabled = bool.fromEnvironment(
    'USE_BREVO_VERIFICATION',
    defaultValue: true,
  );
  static const endpoint = String.fromEnvironment(
    'VERIFICATION_EMAIL_URL',
    defaultValue: 'https://ulexhxfxatzlobabitpr.supabase.co/functions/v1/verification-email',
  );
  static final _inFlight = <String, Future<void>>{};
  static final _operations = <String, String>{};

  static Future<void> send(
    User user, {
    bool emulator = false,
    bool? customEnabled,
  }) {
    if (!(customEnabled ?? enabled)) return user.sendEmailVerification();
    if (emulator || const bool.fromEnvironment('USE_FIREBASE_EMULATOR')) {
      return user.sendEmailVerification();
    }
    return _inFlight.putIfAbsent(
      user.uid,
      () => _send(user).whenComplete(() {
        _inFlight.remove(user.uid);
      }),
    );
  }

  static Future<void> _send(User user) async {
    final operation = _operations.putIfAbsent(user.uid, () {
      final random = Random.secure();
      return List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    });
    Future<http.Response> request(bool refresh) async {
      final token = await user.getIdToken(refresh);
      if (token == null) throw StateError('Sign in again.');
      return http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'operation': operation}),
          )
          .timeout(const Duration(seconds: 45));
    }

    var response = await request(false);
    if (response.statusCode == 401) response = await request(true);
    final body = response.statusCode == 404 ? null : jsonDecode(response.body);
    // Only a known disabled/uninstalled sender falls back. Never double-send
    // after a provider timeout or an ambiguous network failure.
    if (response.statusCode == 404 ||
        (response.statusCode == 503 &&
            body is Map &&
            body['code'] == 'custom-email-disabled')) {
      _operations.remove(user.uid);
      await user.sendEmailVerification();
      return;
    }
    if (response.statusCode == 200) {
      _operations.remove(user.uid);
      return;
    }
    if (response.statusCode == 409 || response.statusCode == 429) {
      _operations.remove(user.uid);
    }
    throw FirebaseAuthException(
      code: response.statusCode == 429
          ? 'too-many-requests'
          : 'verification-email-failed',
      message: body is Map
          ? body['error'] as String?
          : 'Could not send verification.',
    );
  }
}
