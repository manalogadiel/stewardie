import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cloud_media_library.dart' show mediaEndpoint;

/// Private avatar gateway. Image bytes are transferred, never stored in SQL.
class AvatarStorage {
  static final _pending = <String, ({String id, Uint8List bytes})>{};
  static void clearPending() => _pending.clear();
  static Future<http.Response> _send(
    Future<http.Response> Function(String token) request,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError('Verify your email first.');
    }
    Future<String> token(bool refresh) async {
      final value = await user.getIdToken(refresh);
      if (FirebaseAuth.instance.currentUser?.uid != user.uid || value == null) {
        throw StateError('Sign in again.');
      }
      return value;
    }

    var response = await request(await token(false))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 401) {
      response = await request(await token(true))
          .timeout(const Duration(seconds: 30));
    }
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw StateError('Sign in again.');
    }
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw StateError(
        body is Map
            ? body['error'] as String? ?? 'Could not load profile.'
            : 'Could not load profile.',
      );
    }
    return response;
  }

  static Future<Uint8List?> load(String uid) async {
    final response = await _send(
      (token) => http.post(
        Uri.parse(mediaEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'action': 'avatarGet', 'target': uid}),
      ),
    );
    final encoded = (jsonDecode(response.body) as Map)['photo'];
    return encoded is String && encoded.isNotEmpty
        ? base64Decode(encoded)
        : null;
  }

  static Future<void> save(Uint8List bytes) async {
    if (bytes.length > 120000) throw StateError('Choose a smaller photo.');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in again.');
    final random = Random.secure();
    final previous = _pending[uid];
    final id = previous != null && listEquals(previous.bytes, bytes)
        ? previous.id
        : List.generate(
            24,
            (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
    _pending.removeWhere((key, _) => key != uid);
    _pending[uid] = (id: id, bytes: bytes);
    await _send((token) async {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('$mediaEndpoint?action=avatarUpload'),
            )
            ..headers['Authorization'] = 'Bearer $token'
            ..fields['id'] = id
            ..files.add(
              http.MultipartFile.fromBytes(
                'photo',
                bytes,
                filename: 'avatar.jpg',
              ),
            );
      return http.Response.fromStream(await request.send());
    });
    if (_pending[uid]?.id == id) _pending.remove(uid);
  }

  static Future<void> remove() async {
    await _send(
      (token) => http.post(
        Uri.parse(mediaEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'action': 'avatarRemove'}),
      ),
    );
  }
}
