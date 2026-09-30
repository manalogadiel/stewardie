import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM is optional delivery; Firestore activity remains authoritative.
class PushService {
  PushService._();
  static final instance = PushService._();

  StreamSubscription<String>? _rotation;
  StreamSubscription<RemoteMessage>? _openedMessages;
  StreamSubscription<RemoteMessage>? _foregroundMessages;
  final _foregroundUpdates = StreamController<void>.broadcast();
  final _openInbox = StreamController<void>.broadcast();
  bool _pendingInboxOpen = false;
  String? _uid;
  String? _documentId;

  bool get available =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// A push only opens the account inbox. Its items recheck access on tap.
  Stream<void> get inboxOpens => _openInbox.stream;
  Stream<void> get foregroundUpdates => _foregroundUpdates.stream;

  bool takePendingInboxOpen() {
    final pending = _pendingInboxOpen;
    _pendingInboxOpen = false;
    return pending;
  }

  void _requestInboxOpen() {
    if (_openInbox.hasListener) {
      _openInbox.add(null);
    } else {
      _pendingInboxOpen = true;
    }
  }

  String get _platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  String _id(String token) =>
      base64Url.encode(utf8.encode(token)).replaceAll('=', '');

  Future<void> init(String uid) async {
    if (!available) return;
    if (_uid == uid && _rotation != null) return;
    await logOut();
    _uid = uid;
    _foregroundMessages = FirebaseMessaging.onMessage.listen((_) {
      if (_uid == uid && FirebaseAuth.instance.currentUser?.uid == uid) {
        _foregroundUpdates.add(null);
      }
    });
    _rotation = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(_register(token).catchError((_) {}));
    });
    _openedMessages = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (_uid == uid && message.data['activityId'] != null) {
        _requestInboxOpen();
      }
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (_uid == uid && initial?.data['activityId'] != null) {
      _requestInboxOpen();
    }
    await _syncIfPermitted();
  }

  Future<void> _syncIfPermitted() async {
    if (!available || _uid == null) return;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional)
      return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _register(token);
  }

  Future<void> _register(String token) async {
    final uid = _uid;
    if (uid == null || FirebaseAuth.instance.currentUser?.uid != uid) return;
    final id = _id(token);
    final collection = FirebaseFirestore.instance.collection(
      'accounts/$uid/pushDevices',
    );
    if (_documentId != null && _documentId != id) {
      await collection.doc(_documentId).delete();
    }
    await collection.doc(id).set({
      'token': token,
      'platform': _platform,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _documentId = id;
  }

  Future<bool> requestPermission() async {
    if (!available) return false;
    final settings = await FirebaseMessaging.instance.requestPermission();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (granted) {
      await _syncIfPermitted();
    }
    return granted;
  }

  Future<void> logOut() async {
    final uid = _uid;
    _uid = null;
    _pendingInboxOpen = false;
    await _rotation?.cancel();
    _rotation = null;
    await _openedMessages?.cancel();
    _openedMessages = null;
    await _foregroundMessages?.cancel();
    _foregroundMessages = null;
    final id = _documentId;
    _documentId = null;
    if (uid != null &&
        id != null &&
        FirebaseAuth.instance.currentUser?.uid == uid) {
      await FirebaseFirestore.instance
          .doc('accounts/$uid/pushDevices/$id')
          .delete();
    }
  }
}
