import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sembast/sembast.dart';

import 'camera_screen.dart';
import 'media_library.dart';
import '../../core/demo_state.dart';

// Recovered picker results have no trusted destination after process death.
// Retain a prepared copy locally and ask for an explicit audience confirmation.
final recoveredPhotoProvider = NotifierProvider<RecoveredPhoto, CapturedPhoto?>(
  RecoveredPhoto.new,
);
final recoveredPhotoInitialProvider = Provider<CapturedPhoto?>((ref) => null);

class RecoveredPhoto extends Notifier<CapturedPhoto?> {
  @override
  CapturedPhoto? build() => ref.read(recoveredPhotoInitialProvider);

  void restore(CapturedPhoto? photo) => state = photo;

  Future<void> dismiss() async {
    final db = ref.read(mediaLibraryProvider).database;
    final repo = ref.read(repositoryProvider);
    if (db != null) {
      await metaRecords
          .record(
            repo.isShared
                ? 'recovered-picker/${repo.currentUserId}'
                : 'recovered-picker',
          )
          .delete(db);
    }
    state = null;
  }
}

Future<CapturedPhoto?> restorePickerResult(
  Database db, {
  String? accountId,
}) async {
  final key = accountId == null
      ? 'recovered-picker'
      : 'recovered-picker/$accountId';
  final owner = (await metaRecords.record('picker-account').get(db))?['uid'];
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      owner == accountId) {
    try {
      final result = await ImagePicker().retrieveLostData();
      final file = result.files?.firstOrNull;
      if (file != null) {
        final photo = await compute(processPhoto, {
          'bytes': await file.readAsBytes(),
          'source': 'library',
        });
        await metaRecords.record(key).put(db, {
          'bytes': base64Encode(photo.bytes),
        });
      }
    } catch (_) {
      // A failed platform recovery must not hide an earlier retained draft.
    }
  }
  final record = await metaRecords.record(key).get(db);
  return record == null
      ? null
      : CapturedPhoto(base64Decode(record['bytes'] as String), 'library');
}
