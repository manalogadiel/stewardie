import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:sembast/sembast.dart';

import '../../core/demo_state.dart';
import '../timeline/domain/models.dart';
import '../timeline/data/demo_repository.dart';

final photoRecords = stringMapStoreFactory.store('photos');
final taskRecords = stringMapStoreFactory.store('tasks');
final metaRecords = stringMapStoreFactory.store('media-meta');

class PhotoDraft {
  const PhotoDraft(
    this.bytes,
    this.thumbnail,
    this.width,
    this.height,
    this.source,
  );
  final Uint8List bytes, thumbnail;
  final int width, height;
  final String source;
}

// Run in an isolate on native targets. Decode and re-encode pixels into a fresh
// image so EXIF/GPS and other imported metadata do not travel with the photo.
PhotoDraft processPhoto(Map<String, Object> input) {
  final bytes = input['bytes'] as Uint8List;
  if (bytes.length > 32000000) {
    throw const FormatException('Choose a photo smaller than 32 MB.');
  }
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width * info.height > 40000000) {
    throw const FormatException(
      'Choose a JPEG, PNG or WebP photo under 40 megapixels.',
    );
  }
  var decoded = decoder!.decodeFrame(0);
  if (decoded == null) {
    throw const FormatException('This photo could not be read.');
  }
  decoded = img.bakeOrientation(decoded);
  if (decoded.width > 1600 || decoded.height > 1600) {
    decoded = img.copyResize(
      decoded,
      width: decoded.width >= decoded.height ? 1600 : null,
      height: decoded.height > decoded.width ? 1600 : null,
    );
  }
  final clean = img.Image(
    width: decoded.width,
    height: decoded.height,
    numChannels: 3,
  );
  img.fill(clean, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(clean, decoded);
  var quality = 88;
  var encoded = img.encodeJpg(clean, quality: quality);
  while (encoded.length > 500000 && quality > 48) {
    quality -= 10;
    encoded = img.encodeJpg(clean, quality: quality);
  }
  if (encoded.length > 2000000) {
    throw const FormatException(
      'This photo is too large after processing. Choose a smaller image.',
    );
  }
  final thumb = img.copyResize(
    clean,
    width: clean.width >= clean.height ? 320 : null,
    height: clean.height > clean.width ? 320 : null,
  );
  return PhotoDraft(
    encoded,
    img.encodeJpg(thumb, quality: 75),
    clean.width,
    clean.height,
    input['source'] as String,
  );
}

class MediaAttachment {
  const MediaAttachment({
    required this.id,
    required this.spaceId,
    required this.uploaderId,
    required this.caption,
    required this.createdAt,
    required this.photo,
    this.taskId,
    this.taskTitle,
    this.completedBy,
    this.publishedAt,
  });
  final String id, spaceId, uploaderId, caption;
  final String? taskId, taskTitle, completedBy;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final PhotoDraft photo;
  String get heading => taskTitle == null
      ? (caption.isEmpty ? 'A little moment' : caption)
      : '$taskTitle — done!';
  Map<String, Object?> toMap() => {
    'id': id,
    'spaceId': spaceId,
    'uploaderId': uploaderId,
    'caption': caption,
    'createdAt': createdAt.toIso8601String(),
    'taskId': taskId,
    'taskTitle': taskTitle,
    'completedBy': completedBy,
    'publishedAt': publishedAt?.toIso8601String(),
    'bytes': base64Encode(photo.bytes),
    'thumbnail': base64Encode(photo.thumbnail),
    'width': photo.width,
    'height': photo.height,
    'source': photo.source,
  };
  factory MediaAttachment.fromMap(Map<String, Object?> m) => MediaAttachment(
    id: m['id'] as String,
    spaceId: m['spaceId'] as String,
    uploaderId: m['uploaderId'] as String,
    caption: m['caption'] as String,
    createdAt: DateTime.parse(m['createdAt'] as String),
    taskId: m['taskId'] as String?,
    taskTitle: m['taskTitle'] as String?,
    completedBy: m['completedBy'] as String?,
    publishedAt: m['publishedAt'] == null
        ? null
        : DateTime.parse(m['publishedAt'] as String),
    photo: PhotoDraft(
      base64Decode(m['bytes'] as String),
      base64Decode(m['thumbnail'] as String),
      m['width'] as int,
      m['height'] as int,
      m['source'] as String,
    ),
  );
}

class MediaLibrary extends ChangeNotifier {
  MediaLibrary(
    this.timeline, {
    this.database,
    List<MediaAttachment> initial = const [],
    this.dailyLimit = 10,
    this.storageLimit = 100000000,
    DateTime Function()? clock,
  }) : _items = [...initial],
       clock = clock ?? DateTime.now;
  final TimelineRepository timeline;
  final Database? database;
  final int dailyLimit, storageLimit;
  final DateTime Function() clock;
  final List<MediaAttachment> _items;
  final Map<String, int> _daily = {};
  Future<void> _writes = Future.value();
  int _serial = 0;
  Future<T> _serialize<T>(Future<T> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return next;
  }

  List<MediaAttachment> get items => List.unmodifiable(_items);
  List<MediaAttachment> forTask(String id) =>
      _items.where((p) => p.taskId == id).toList();
  void _member(String space, String actor) {
    if (actor != 'me' ||
        !timeline.spaces.any(
          (s) => s.id == space && s.members.any((m) => m.id == actor),
        )) {
      throw StateError('You cannot change photos in this space.');
    }
  }

  Task _task(String id, String space) =>
      timeline.tasks.firstWhere((t) => t.id == id && t.spaceId == space);
  Future<MediaAttachment> add(
    PhotoDraft photo,
    String space,
    String actor,
    String caption, {
    String? taskId,
  }) => _serialize(() async {
    _member(space, actor);
    final task = taskId == null ? null : _task(taskId, space);
    if (task != null && task.creatorId != actor && task.ownerId != actor) {
      throw StateError(
        'Only the creator or responsible person can attach a photo.',
      );
    }
    if (taskId != null && forTask(taskId).isNotEmpty) {
      throw StateError('This task already has its photo.');
    }
    if (photo.bytes.length > 2000000) {
      throw StateError('Choose a smaller photo.');
    }
    final size = _items
        .where((p) => p.uploaderId == actor)
        .fold<int>(
          0,
          (n, p) => n + p.photo.bytes.length + p.photo.thumbnail.length,
        );
    if (size + photo.bytes.length + photo.thumbnail.length > storageLimit) {
      throw StateError(
        'Photo storage is full. You can still finish without a photo.',
      );
    }
    final now = clock().toUtc();
    final dayKey = '$actor/${now.toIso8601String().substring(0, 10)}';
    final current = database == null
        ? _daily[dayKey] ?? 0
        : (await metaRecords.record(dayKey).get(database!))?['count'] as int? ??
              0;
    if (current >= dailyLimit) {
      throw StateError(
        'Today’s photo limit is reached. Resets at 00:00 UTC. You can still finish without a photo.',
      );
    }
    final attachment = MediaAttachment(
      id: 'photo-${now.microsecondsSinceEpoch}-${_serial++}',
      spaceId: space,
      uploaderId: actor,
      caption: caption.trim(),
      createdAt: now,
      photo: photo,
      taskId: taskId,
      taskTitle: task?.isDone == true ? task!.title : null,
      completedBy: task?.isDone == true ? task!.ownerId : null,
      publishedAt: task == null || task.isDone ? now : null,
    );
    if (database != null) {
      await database!.transaction((txn) async {
        await photoRecords.record(attachment.id).put(txn, attachment.toMap());
        await metaRecords.record(dayKey).put(txn, {'count': current + 1});
      });
    }
    _daily[dayKey] = current + 1;
    _items.add(attachment);
    notifyListeners();
    return attachment;
  });

  Future<void> publishTask(Task supplied) => _serialize(() async {
    final task = _task(supplied.id, supplied.spaceId);
    _member(task.spaceId, 'me');
    if (!task.isDone) return;
    final targets = forTask(task.id)
        .where((p) => p.publishedAt == null)
        .toList();
    for (final old in targets) {
      final updated = MediaAttachment(
        id: old.id,
        spaceId: old.spaceId,
        uploaderId: old.uploaderId,
        caption: old.caption,
        createdAt: old.createdAt,
        photo: old.photo,
        taskId: task.id,
        taskTitle: task.title,
        completedBy: task.ownerId,
        publishedAt: task.completedAt ?? clock(),
      );
      await photoRecords
          .record(old.id)
          .putIfDatabase(database, updated.toMap());
      final index = _items.indexWhere((p) => p.id == old.id);
      if (index >= 0) _items[index] = updated;
    }
    notifyListeners();
  });

  Future<void> remove(MediaAttachment supplied, String actor) =>
      _serialize(() async {
        final photo = _items.where((p) => p.id == supplied.id).firstOrNull;
        if (photo == null) return;
        _member(photo.spaceId, actor);
        if (photo.uploaderId != actor) {
          throw StateError('Only the uploader can remove this photo.');
        }
        if (database != null) {
          await photoRecords.record(photo.id).delete(database!);
        }
        _items.removeWhere((p) => p.id == photo.id);
        notifyListeners();
      });
}

extension on RecordRef<String, Map<String, Object?>> {
  Future<void> putIfDatabase(
    Database? database,
    Map<String, Object?> value,
  ) async {
    if (database != null) await put(database, value);
  }
}

final mediaLibraryProvider = Provider<MediaLibrary>((ref) {
  final library = MediaLibrary(ref.read(repositoryProvider));
  ref.onDispose(library.dispose);
  return library;
});
final mediaProvider = NotifierProvider<MediaController, List<MediaAttachment>>(
  MediaController.new,
);

class MediaController extends Notifier<List<MediaAttachment>> {
  @override
  List<MediaAttachment> build() {
    final library = ref.watch(mediaLibraryProvider);
    void refresh() => state = library.items;
    library.addListener(refresh);
    ref.onDispose(() => library.removeListener(refresh));
    return library.items;
  }
}
