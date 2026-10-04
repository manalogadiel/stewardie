import '../online/online_backend.dart';
import '../online/avatar_storage.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

import 'member_avatar.dart';
import 'theme.dart';

/// Metadata-free square avatars; production bytes live in private Storage.
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
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return null;
    return confirm(context, bytes);
  }

  static Future<String?> confirm(BuildContext context, Uint8List bytes) async {
    final original = image.decodeImage(bytes);
    if (original == null) throw StateError('Choose a valid photo.');
    final upright = image.bakeOrientation(original);
    if (!context.mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (_) => _AvatarCropDialog(photo: upright),
    );
  }

  static Future<void> save(String base64, {String? photoUrl}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError('Verify your email first.');
    }
    if (photoUrl == null &&
        (base64.length > 160000 || decode(base64) == null)) {
      throw StateError('Choose a smaller photo.');
    }
    if (OnlineBackend.useSupabaseCore &&
        !OnlineBackend.useEmulator &&
        base64.isNotEmpty) {
      final bytes = decode(base64)!;
      await AvatarStorage.save(bytes);
      MemberAvatar.updateCache(user.uid, bytes);
      return;
    }
    final data = <String, dynamic>{
      if (base64.isNotEmpty) 'imageBase64': base64,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }
    await OnlineBackend.database.doc('profiles/${user.uid}').set(data);
    MemberAvatar.updateCache(user.uid, decode(base64));
  }

  static Future<void> remove() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      if (OnlineBackend.useSupabaseCore && !OnlineBackend.useEmulator) {
        await AvatarStorage.remove();
      } else {
        await OnlineBackend.database.doc('profiles/$uid').delete();
      }
      MemberAvatar.updateCache(uid, null);
    }
  }
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.photo});
  final image.Image photo;
  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  double offset = .5;
  late final full = Uint8List.fromList(
    image.encodeJpg(widget.photo, quality: 85),
  );
  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final edge = photo.width < photo.height ? photo.width : photo.height;
    final x = ((photo.width - edge) * offset).round();
    final y = ((photo.height - edge) * offset).round();
    final crop = image.copyResize(
      image.copyCrop(photo, x: x, y: y, width: edge, height: edge),
      width: 256,
      height: 256,
    );
    final clean = image.Image(width: 256, height: 256, numChannels: 3);
    image.fill(clean, color: image.ColorRgb8(255, 255, 255));
    image.compositeImage(clean, crop);
    final bytes = Uint8List.fromList(image.encodeJpg(clean, quality: 75));
    return AlertDialog(
      backgroundColor: SoftPop.surface,
      title: Text('Your photo', style: Theme.of(context).textTheme.titleLarge),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: (MediaQuery.sizeOf(context).height * .3).clamp(
                  120.0,
                  230.0,
                ),
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, size) {
                    final scale =
                        (size.maxWidth / photo.width) <
                            (size.maxHeight / photo.height)
                        ? size.maxWidth / photo.width
                        : size.maxHeight / photo.height;
                    final left = (size.maxWidth - photo.width * scale) / 2;
                    final top = (size.maxHeight - photo.height * scale) / 2;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Image.memory(full, fit: BoxFit.contain),
                        ),
                        Positioned(
                          left: left + x * scale,
                          top: top + y * scale,
                          width: edge * scale,
                          height: edge * scale,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF244BFF),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (photo.width != photo.height)
                Slider(
                  value: offset,
                  onChanged: (value) => setState(() => offset = value),
                  semanticFormatterCallback: (value) =>
                      'Avatar crop position ${(value * 100).round()} percent',
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(radius: 28, backgroundImage: MemoryImage(bytes)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Profile preview')),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, base64Encode(bytes)),
          child: const Text('Use photo'),
        ),
      ],
    );
  }
}
