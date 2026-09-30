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

  @override
  State<MemberAvatar> createState() => _MemberAvatarState();
}

class _MemberAvatarState extends State<MemberAvatar> {
  // Reuse decoded bytes across routes, bounded and scoped to the signed-in UID.
  static final Map<String, Uint8List?> _photos = {};
  static String? _cacheAccount;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;
  String? _identity;
  String? _encoded;
  Uint8List? _bytes;
  String get uid => widget.uid;
  String get name => widget.name;
  double get radius => widget.radius;
  bool get selected => widget.selected;

  void _bind() {
    final account = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser?.uid;
    if (_cacheAccount != account) {
      _photos.clear();
      _cacheAccount = account;
    }
    final identity = '$account/$uid';
    if (_identity == identity) return;
    _identity = identity;
    _encoded = null;
    _bytes = account == null ? null : _photos[uid];
    _stream = account == null
        ? null
        : FirebaseFirestore.instance.doc('profiles/$uid').snapshots();
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
      child: _stream == null
          ? _face(null)
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              key: ValueKey(_identity),
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final encoded =
                      snapshot.data!.data()?['imageBase64'] as String?;
                  if (encoded != _encoded || encoded == null) {
                    _encoded = encoded;
                    _bytes = ProfilePhoto.decode(encoded);
                    if (_photos.length >= 100 && !_photos.containsKey(uid)) {
                      _photos.remove(_photos.keys.first);
                    }
                    _photos[uid] = _bytes;
                  }
                }
                return _face(_bytes);
              },
            ),
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
