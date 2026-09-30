import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

/// Small metadata-free square avatars fit safely in a single profile document.
class ProfilePhoto {
  ProfilePhoto._();

  static Uint8List? decode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> choose(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
            ListTile(
              title: const Text('Skip for now'),
              onTap: () => Navigator.pop(sheet),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return null;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (picked == null || !context.mounted) return null;
    final original = image.decodeImage(await picked.readAsBytes());
    if (original == null) throw StateError('Choose a valid photo.');
    final upright = image.bakeOrientation(original);
    final edge = upright.width < upright.height
        ? upright.width
        : upright.height;
    final square = image.copyCrop(
      upright,
      x: (upright.width - edge) ~/ 2,
      y: (upright.height - edge) ~/ 2,
      width: edge,
      height: edge,
    );
    final small = image.copyResize(square, width: 256, height: 256);
    var bytes = Uint8List.fromList(image.encodeJpg(small, quality: 78));
    if (bytes.length > 110000) {
      bytes = Uint8List.fromList(image.encodeJpg(small, quality: 55));
    }
    if (bytes.length > 110000)
      throw StateError('This photo is too detailed. Try another.');
    if (!context.mounted) return null;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Use this photo?'),
        content: CircleAvatar(radius: 82, backgroundImage: MemoryImage(bytes)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Choose again'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Use photo'),
          ),
        ],
      ),
    );
    return accepted == true ? base64Encode(bytes) : null;
  }

  static Future<void> save(String base64) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified)
      throw StateError('Verify your email first.');
    if (base64.length > 160000 || decode(base64) == null) {
      throw StateError('Choose a smaller photo.');
    }
    await FirebaseFirestore.instance.doc('profiles/${user.uid}').set({
      'imageBase64': base64,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> remove() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null)
      await FirebaseFirestore.instance.doc('profiles/$uid').delete();
  }
}
