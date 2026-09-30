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
    return confirm(context, await picked.readAsBytes());
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
      title: const Text('Choose your avatar crop'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 230,
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
              const Text('Your profile preview'),
              const SizedBox(height: 8),
              CircleAvatar(radius: 42, backgroundImage: MemoryImage(bytes)),
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
