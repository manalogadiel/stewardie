import '../online/online_backend.dart';
import '../online/avatar_storage.dart';

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'profile_photo.dart';

/// A stable identity chip: names may change, but color follows the account UID.
class MemberAvatar extends StatefulWidget {
  const MemberAvatar({
    super.key,
    required this.uid,
    required this.name,
    this.radius = 20,
    this.selected = false,
  });
  final String uid;
  final String name;
  final double radius;
  final bool selected;

  static const colors = [
    Color(0xFFA9CDE8),
    Color(0xFFEAB8C5),
    Color(0xFFF8E7B0),
    Color(0xFFBFD9C1),
    Color(0xFFD4C4EA),
  ];

  static Color colorFor(String uid) {
    var hash = 0;
    for (final code in uid.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return colors[hash % colors.length];
  }

  static String initialsFor(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    return (words.length == 1
            ? words.first.substring(0, 1)
            : '${words.first[0]}${words.last[0]}')
        .toUpperCase();
  }

  static void updateCache(String uid, Uint8List? bytes) =>
      _MemberAvatarState.updateCache(uid, bytes);

  static void clearCache() => _MemberAvatarState.clearCache();

  @override
  State<MemberAvatar> createState() => _MemberAvatarState();
}

class _MemberAvatarState extends State<MemberAvatar> {
  // Reuse decoded bytes across routes, bounded and scoped to the signed-in UID.
  static final Map<String, Uint8List?> _photos = {};
  static final Map<String, DateTime> _fetchedAt = {};
  static final Map<String, DateTime> _retryAt = {};
  static final Map<String, Future<Uint8List?>> _pendingFetches = {};
  static final ValueNotifier<int> _updates = ValueNotifier(0);
  static String? _cacheAccount;
  static int _generation = 0;

  static void updateCache(String uid, Uint8List? bytes) {
    final account = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser?.uid;
    if (_cacheAccount != account) {
      _photos.clear();
      _fetchedAt.clear();
      _retryAt.clear();
      _pendingFetches.clear();
      _cacheAccount = account;
      _generation++;
    }
    _photos[uid] = bytes;
    _retryAt.remove(uid);
    _fetchedAt[uid] = DateTime.now();
    _updates.value++;
  }

  static void clearCache() {
    AvatarStorage.clearPending();
    _photos.clear();
    _fetchedAt.clear();
    _retryAt.clear();
    _pendingFetches.clear();
    _generation++;
    _cacheAccount = null;
    _updates.value++;
  }

  String? _identity;
  Uint8List? _bytes;
  String get uid => widget.uid;
  String get name => widget.name;
  double get radius => widget.radius;
  bool get selected => widget.selected;

  @override
  void initState() {
    super.initState();
    _updates.addListener(_cacheChanged);
  }

  void _cacheChanged() {
    if (mounted) {
      setState(() {
        _bytes = _photos[uid];
        if (!_photos.containsKey(uid)) _identity = null;
      });
    }
  }

  @override
  void dispose() {
    _updates.removeListener(_cacheChanged);
    super.dispose();
  }

  void _bind() {
    final account = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser?.uid;
    if (_cacheAccount != account) {
      _photos.clear();
      _fetchedAt.clear();
      _retryAt.clear();
      _pendingFetches.clear();
      _generation++;
      _cacheAccount = account;
    }
    final identity = '$account/$uid';
    if (_identity == identity) {
      final fetched = _fetchedAt[uid];
      final retry = _retryAt[uid];
      if (account != null &&
          ((retry != null && DateTime.now().isAfter(retry)) ||
              (fetched != null &&
                  DateTime.now().difference(fetched).inMinutes >= 15))) {
        _fetchPhoto(account, uid);
      }
      return;
    }
    _identity = identity;

    if (account == null) {
      _bytes = null;
      return;
    }

    if (_photos.containsKey(uid)) {
      _bytes = _photos[uid];
    } else {
      _bytes = null;
      _fetchPhoto(account, uid);
    }
  }

  void _fetchPhoto(String account, String targetUid) {
    if (_retryAt[targetUid]?.isAfter(DateTime.now()) == true) return;
    final key = '$account/$targetUid';
    final generation = _generation;
    final previousFetch = _fetchedAt[targetUid];
    final future = _pendingFetches.putIfAbsent(key, () async {
      if (OnlineBackend.useSupabaseCore && !OnlineBackend.useEmulator) {
        return AvatarStorage.load(targetUid);
      }
      final doc = await OnlineBackend.database
          .doc('profiles/$targetUid')
          .get(const GetOptions(source: Source.serverAndCache));
      return ProfilePhoto.decode(doc.data()?['imageBase64'] as String?);
    });
    future
        .then((bytes) {
          if (identical(_pendingFetches[key], future)) {
            _pendingFetches.remove(key);
          }
          if (_cacheAccount != account || _generation != generation) return;
          if (_fetchedAt[targetUid] != previousFetch) return;
          if (_photos.length >= 100 && !_photos.containsKey(targetUid)) {
            _photos.remove(_photos.keys.first);
            _fetchedAt.removeWhere((key, _) => !_photos.containsKey(key));
          }
          _photos[targetUid] = bytes;
          _retryAt.remove(targetUid);
          _fetchedAt[targetUid] = DateTime.now();
          _updates.value++;
          if (mounted && uid == targetUid) {
            setState(() {
              _bytes = bytes;
            });
          }
        })
        .catchError((_) {
          if (identical(_pendingFetches[key], future)) {
            _pendingFetches.remove(key);
          }
          if (_cacheAccount == account && _generation == generation) {
            if (_retryAt.length >= 100) _retryAt.remove(_retryAt.keys.first);
            _retryAt[targetUid] = DateTime.now().add(
              const Duration(seconds: 45),
            );
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    _bind();
    return Container(
      padding: EdgeInsets.all(selected ? 3 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFFFFF7EB) : null,
      ),
      child: _face(_bytes),
    );
  }

  Widget _face(Uint8List? bytes) => CircleAvatar(
    radius: radius,
    backgroundColor: MemberAvatar.colorFor(uid),
    child: bytes == null
        ? _initials()
        : ClipOval(
            child: SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => _initials(),
              ),
            ),
          ),
  );

  Widget _initials() => SizedBox(
    width: radius * 2,
    height: radius * 2,
    child: Center(
      child: Text(
        MemberAvatar.initialsFor(name),
        textScaler: TextScaler.noScaling,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF202633),
          // height:1 prevents line-box misalignment at small sizes.
          height: 1,
          fontSize: radius.clamp(10.0, 18.0),
        ),
      ),
    ),
  );
}
