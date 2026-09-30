import 'dart:async';
import 'dart:convert';

import '../core/sound_feedback.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// FCM is optional delivery; Firestore activity remains authoritative.
class PushService {
  static const _native = MethodChannel('stewardie/notifications');
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
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else {
      await _native.invokeMethod<void>('configure');
      _native.setMethodCallHandler((call) async {
        if (call.method == 'opened' &&
            _uid == uid &&
            FirebaseAuth.instance.currentUser?.uid == uid) {
          _requestInboxOpen();
        }
      });
      if (await _native.invokeMethod<String>('takeInitial') != null &&
          _uid == uid) {
        _requestInboxOpen();
      }
    }
    _foregroundMessages = FirebaseMessaging.onMessage.listen((message) {
      if (_uid == uid && FirebaseAuth.instance.currentUser?.uid == uid) {
        if (defaultTargetPlatform == TargetPlatform.iOS &&
            message.notification != null) {
          unawaited(SoundFeedback.notificationPresented());
        }
        _foregroundUpdates.add(null);
        if (defaultTargetPlatform == TargetPlatform.android) {
          unawaited(_present(message, uid).catchError((_) {}));
        }
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

  Future<void> _present(RemoteMessage message, String uid) async {
    final activityId = message.data['activityId'];
    final spaceId = message.data['spaceId'];
    if (activityId is! String || spaceId is! String) return;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) return;
    final docs = await Future.wait([
      FirebaseFirestore.instance
          .doc('accounts/$uid/notificationPrefs/global')
          .get(),
      FirebaseFirestore.instance
          .doc(
            'accounts/$uid/notificationPrefs/${spaceId.isEmpty ? 'global' : spaceId}',
          )
          .get(),
      FirebaseFirestore.instance
          .doc('accounts/$uid/activity/$activityId')
          .get(),
    ]);
    if (_uid != uid ||
        FirebaseAuth.instance.currentUser?.uid != uid ||
        docs[0].data()?['enabled'] == false ||
        docs[1].data()?['enabled'] == false ||
        !docs[2].exists) {
      return;
    }
    final item = docs[2].data()!;
    final category = {
      'photo': 'photos',
      'reaction': 'reactions',
      'mood': 'moods',
    }[item['kind']];
    if (category != null && docs[1].data()?[category] == false) return;
    if (item['accountNotice'] != true) {
      final space = await FirebaseFirestore.instance
          .doc('spaces/$spaceId')
          .get(const GetOptions(source: Source.server));
      if (!(space.data()?['memberUids'] as List? ?? []).contains(uid)) return;
    }
    if (_uid != uid || FirebaseAuth.instance.currentUser?.uid != uid) return;
    var id = 0;
    for (final unit in activityId.codeUnits) {
      id = (id * 31 + unit) & 0x7fffffff;
    }
    await SoundFeedback.notificationPresented();
    await _native.invokeMethod<void>('show', {
      'id': id,
      'activityId': activityId,
    });
  }

  Future<void> openSystemSettings() async {
    if (!available) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _native.invokeMethod<void>('settings');
    }
  }

  Future<void> syncPermission() => _syncIfPermitted();

  Future<void> _syncIfPermitted() async {
    if (!available || _uid == null) {
      return;
    }
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _register(token);
    }
  }

  Future<void> _register(String token) async {
    final uid = _uid;
    if (uid == null || FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }
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
    if (_uid == uid && FirebaseAuth.instance.currentUser?.uid == uid) {
      _documentId = id;
    }
  }

  Future<bool> requestPermission() async {
    if (!available) return false;
    final settings = await FirebaseMessaging.instance.requestPermission();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (granted) {
      final uid = _uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final pref = FirebaseFirestore.instance.doc(
          'accounts/$uid/notificationPrefs/global',
        );
        await FirebaseFirestore.instance.runTransaction((tx) async {
          if (!(await tx.get(pref)).exists) {
            tx.set(pref, {
              'enabled': true,
              'quietStart': 1320,
              'quietEnd': 420,
              'timeZone': 'Asia/Manila',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        });
      }
      await _syncIfPermitted();
    }
    return granted;
  }

  Future<void> logOut() async {
    final uid = _uid;
    _uid = null;
    _pendingInboxOpen = false;
    if (available && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _native.invokeMethod<void>('clear');
      } catch (_) {
        /* Native channel unavailable in tests. */
      }
    }
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
      try {
        await FirebaseFirestore.instance
            .doc('accounts/$uid/pushDevices/$id')
            .delete();
      } catch (_) {
        /* Invalidating the FCM token below also ends delivery offline. */
      }
    }
    if (available && uid != null) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {
        /* Retry registration on the next authenticated session. */
      }
    }
  }
}
