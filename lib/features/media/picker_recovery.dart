import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sembast/sembast.dart';

import 'camera_screen.dart';
import 'media_library.dart';

// Recovered picker results have no trusted destination after process death.
// Retain a prepared copy locally and ask for an explicit audience confirmation.
final recoveredPhotoProvider = NotifierProvider<RecoveredPhoto, CapturedPhoto?>(
  RecoveredPhoto.new,
);

class RecoveredPhoto extends Notifier<CapturedPhoto?> {
  @override
  CapturedPhoto? build() => null;

  void restore(CapturedPhoto? photo) => state = photo;

  Future<void> dismiss() async {
    final db = ref.read(mediaLibraryProvider).database;
    if (db != null) await metaRecords.record('recovered-picker').delete(db);
    state = null;
  }
}

Future<CapturedPhoto?> restorePickerResult(Database db) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      final result = await ImagePicker().retrieveLostData();
      final file = result.files?.firstOrNull;
      if (file != null) {
        final photo = await compute(processPhoto, {
          'bytes': await file.readAsBytes(),
          'source': 'library',
        });
        await metaRecords.record('recovered-picker').put(db, {
          'bytes': base64Encode(photo.bytes),
        });
      }
    } catch (_) {
      // A failed platform recovery must not hide an earlier retained draft.
    }
  }
  final record = await metaRecords.record('recovered-picker').get(db);
  return record == null
      ? null
      : CapturedPhoto(base64Decode(record['bytes'] as String), 'library');
}
