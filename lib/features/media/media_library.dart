import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:sembast/sembast.dart';

import '../../core/demo_state.dart';
import '../timeline/domain/models.dart';
import '../timeline/data/demo_repository.dart';

final photoRecords = stringMapStoreFactory.store('photos');
final taskRecords = stringMapStoreFactory.store('tasks');
final metaRecords = stringMapStoreFactory.store('media-meta');

/// Non-destructive framing rectangle in normalized coordinates [0.0, 1.0].
class FramingRect {
  const FramingRect({
    this.x = 0.0,
    this.y = 0.0,
    this.width = 1.0,
    this.height = 1.0,
    this.ratioName = 'original',
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final String ratioName;

  static const full = FramingRect();

  bool get isFull =>
      (x <= 0.001) &&
      (y <= 0.001) &&
      (width >= 0.999) &&
      (height >= 0.999);

  double get aspectRatio => width / (height <= 0 ? 1.0 : height);

  Map<String, dynamic> toMap() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'ratioName': ratioName,
  };

  factory FramingRect.fromMap(Map<String, dynamic>? map) {
    if (map == null) return FramingRect.full;
    final rawX = (map['x'] as num?)?.toDouble() ?? 0.0;
    final rawY = (map['y'] as num?)?.toDouble() ?? 0.0;
    final rawW = (map['width'] as num?)?.toDouble() ?? 1.0;
    final rawH = (map['height'] as num?)?.toDouble() ?? 1.0;
    final name = map['ratioName'] as String? ?? 'original';

    if (rawX.isNaN || rawX.isInfinite ||
        rawY.isNaN || rawY.isInfinite ||
        rawW.isNaN || rawW.isInfinite ||
        rawH.isNaN || rawH.isInfinite) {
      return FramingRect.full;
    }

    final validX = rawX.clamp(0.0, 0.99);
    final validY = rawY.clamp(0.0, 0.99);
    final maxW = (1.0 - validX).clamp(0.01, 1.0);
    final maxH = (1.0 - validY).clamp(0.01, 1.0);
    final validW = rawW.clamp(0.01, maxW);
    final validH = rawH.clamp(0.01, maxH);

    return FramingRect(
      x: validX,
      y: validY,
      width: validW,
      height: validH,
      ratioName: name,
    );
  }

  static FramingRect fromAspectRatio({
    required double targetRatio,
    required int imageWidth,
    required int imageHeight,
    String ratioName = 'custom',
  }) {
    if (imageWidth <= 0 || imageHeight <= 0 || targetRatio <= 0) {
      return FramingRect.full;
    }
    final imageRatio = imageWidth / imageHeight;
    if ((imageRatio - targetRatio).abs() < 0.01) {
      return FramingRect(ratioName: ratioName);
    }
    if (imageRatio > targetRatio) {
      final cropW = (targetRatio / imageRatio).clamp(0.01, 1.0);
      final cropX = ((1.0 - cropW) / 2.0).clamp(0.0, 1.0);
      return FramingRect(
        x: cropX,
        y: 0.0,
        width: cropW,
        height: 1.0,
        ratioName: ratioName,
      );
    } else {
      final cropH = (imageRatio / targetRatio).clamp(0.01, 1.0);
      final cropY = ((1.0 - cropH) / 2.0).clamp(0.0, 1.0);
      return FramingRect(
        x: 0.0,
        y: cropY,
        width: 1.0,
        height: cropH,
        ratioName: ratioName,
      );
    }
  }
}

/// Renders a photo with non-destructive framing applied without stretching or distortion.
class FramedPhoto extends StatefulWidget {
  const FramedPhoto({
    super.key,
    required this.bytes,
    required this.framing,
    this.fit = BoxFit.contain,
  });

  final Uint8List bytes;
  final FramingRect framing;
  final BoxFit fit;

  @override
  State<FramedPhoto> createState() => _FramedPhotoState();
}

class _FramedPhotoState extends State<FramedPhoto> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;
  ImageInfo? _imageInfo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(FramedPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.bytes, oldWidget.bytes)) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    final provider = MemoryImage(widget.bytes);
    final newStream = provider.resolve(createLocalImageConfiguration(context));
    if (_imageStream?.key != newStream.key) {
      if (_listener != null && _imageStream != null) {
        _imageStream!.removeListener(_listener!);
      }
      _imageStream = newStream;
      _listener = ImageStreamListener(
        (info, synchronousCall) {
          if (mounted) {
            setState(() {
              _imageInfo?.dispose();
              _imageInfo = info;
            });
          }
        },
        onError: (exception, stackTrace) {
          debugPrint('Error loading framed photo: $exception');
        },
      );
      newStream.addListener(_listener!);
    }
  }

  @override
  void dispose() {
    if (_listener != null && _imageStream != null) {
      _imageStream!.removeListener(_listener!);
    }
    _imageInfo?.dispose();
    _imageInfo = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.framing.isFull) {
      return Image.memory(widget.bytes, fit: widget.fit);
    }
    if (_imageInfo == null) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final Size layoutSize;
        if (h.isInfinite && w.isFinite) {
          layoutSize = Size(w, w / widget.framing.aspectRatio);
        } else if (w.isInfinite && h.isFinite) {
          layoutSize = Size(h * widget.framing.aspectRatio, h);
        } else {
          layoutSize = Size(w.isFinite ? w : 300, h.isFinite ? h : 200);
        }
        return SizedBox(
          width: layoutSize.width,
          height: layoutSize.height,
          child: ClipRect(
            child: CustomPaint(
              size: layoutSize,
              painter: _FramedImagePainter(
                image: _imageInfo!.image,
                framing: widget.framing,
                fit: widget.fit,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FramedImagePainter extends CustomPainter {
  const _FramedImagePainter({
    required this.image,
    required this.framing,
    required this.fit,
  });

  final ui.Image image;
  final FramingRect framing;
  final BoxFit fit;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    if (imgW <= 0 || imgH <= 0) return;

    final srcX = (framing.x * imgW).clamp(0.0, imgW);
    final srcY = (framing.y * imgH).clamp(0.0, imgH);
    final maxW = (imgW - srcX).clamp(1.0, imgW);
    final maxH = (imgH - srcY).clamp(1.0, imgH);
    final srcW = (framing.width * imgW).clamp(1.0, maxW);
    final srcH = (framing.height * imgH).clamp(1.0, maxH);
    final srcRect = Rect.fromLTWH(srcX, srcY, srcW, srcH);

    final fittedSizes = applyBoxFit(fit, srcRect.size, size);
    final dstRect = Alignment.center.inscribe(
      fittedSizes.destination,
      Offset.zero & size,
    );

    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawImageRect(image, srcRect, dstRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FramedImagePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.framing != framing ||
        oldDelegate.fit != fit;
  }
}


class PhotoDraft {
  const PhotoDraft(
    this.bytes,
    this.thumbnail,
    this.width,
    this.height,
    this.source, {
    this.framing = FramingRect.full,
  });
  final Uint8List bytes, thumbnail;
  final int width, height;
  final String source;
  final FramingRect framing;

  PhotoDraft copyWith({FramingRect? framing}) => PhotoDraft(
    bytes,
    thumbnail,
    width,
    height,
    source,
    framing: framing ?? this.framing,
  );
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
  FramingRect framing = FramingRect.full;
  if (input['framing'] is Map) {
    framing = FramingRect.fromMap(Map<String, dynamic>.from(input['framing'] as Map));
  }
  return PhotoDraft(
    encoded,
    img.encodeJpg(thumb, quality: 75),
    clean.width,
    clean.height,
    input['source'] as String,
    framing: framing,
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
    this.cloud = false,
    this.framing = FramingRect.full,
  });
  final String id, spaceId, uploaderId, caption;
  final String? taskId, taskTitle, completedBy;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final PhotoDraft photo;
  final bool cloud;
  final FramingRect framing;
  String get heading => taskTitle == null
      ? (caption.isEmpty ? 'A little moment' : caption)
      : '$taskTitle — done!';
  Map<String, Object?> toMap() => {
    'cloud': cloud,
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
    'framing': framing.toMap(),
  };
  factory MediaAttachment.fromMap(Map<String, Object?> m) {
    final framing = m['framing'] is Map
        ? FramingRect.fromMap(Map<String, dynamic>.from(m['framing'] as Map))
        : FramingRect.full;
    return MediaAttachment(
      cloud: m['cloud'] == true,
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
      framing: framing,
      photo: PhotoDraft(
        base64Decode(m['bytes'] as String),
        base64Decode(m['thumbnail'] as String),
        m['width'] as int,
        m['height'] as int,
        m['source'] as String,
        framing: framing,
      ),
    );
  }
}

class MediaLibrary extends ChangeNotifier {
  MediaLibrary(
    this.timeline, {
    this.database,
    StoreRef<String, Map<String, Object?>>? records,
    List<MediaAttachment> initial = const [],
    this._dailyLimit,
    this._storageLimit,
    DateTime Function()? clock,
  }) : records = records ?? photoRecords,
       _items = [...initial],
       clock = clock ?? DateTime.now;
  final TimelineRepository timeline;
  final Database? database;
  final StoreRef<String, Map<String, Object?>> records;
  final int? _dailyLimit, _storageLimit;
  int get dailyLimit => _dailyLimit ?? (timeline.isPlus ? 100 : 10);
  int get storageLimit =>
      _storageLimit ?? (timeline.isPlus ? 5000000000 : 100000000);
  int get attachmentLimit => timeline.isPlus ? 5 : 1;
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

  bool get supportsSharing => false;
  bool get enforceLocalQuotas => true;
  bool get syncing => false;
  String? get syncError => null;
  Set<String> get pendingIds => const {};
  Future<void> refresh(String spaceId) async {}
  Future<void> share(MediaAttachment photo) async {
    throw StateError('Photo sharing is not connected yet.');
  }

  Future<void> retryPending() async {}
  Future<Uint8List> fullPhoto(MediaAttachment photo) async => photo.photo.bytes;
  List<MediaAttachment> get items => List.unmodifiable(_items);
  List<MediaAttachment> forTask(String id) =>
      _items.where((p) => p.taskId == id).toList();
  void _member(String space, String actor) {
    if (actor != timeline.currentUserId ||
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
    if (taskId != null && forTask(taskId).length >= attachmentLimit) {
      throw StateError('This task has reached its photo limit.');
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
    if (enforceLocalQuotas &&
        size + photo.bytes.length + photo.thumbnail.length > storageLimit) {
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
    if (enforceLocalQuotas && current >= dailyLimit) {
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
      framing: photo.framing,
      taskId: taskId,
      taskTitle: task?.isDone == true ? task!.title : null,
      completedBy: task?.isDone == true ? task!.ownerId : null,
      publishedAt: task == null || task.isDone ? now : null,
    );
    if (database != null) {
      await database!.transaction((txn) async {
        await records.record(attachment.id).put(txn, attachment.toMap());
        await metaRecords.record(dayKey).put(txn, {'count': current + 1});
      });
    }
    _daily[dayKey] = current + 1;
    _items.add(attachment);
    notifyListeners();
    return attachment;
  });

  Future<void> cacheAttachment(MediaAttachment photo) async {
    await records.record(photo.id).putIfDatabase(database, photo.toMap());
    final index = _items.indexWhere((p) => p.id == photo.id);
    if (index >= 0) _items[index] = photo;
  }

  Future<void> publishTask(Task supplied) => _serialize(() async {
    final task = _task(supplied.id, supplied.spaceId);
    _member(task.spaceId, timeline.currentUserId);
    if (!task.isDone) return;
    final targets = forTask(task.id)
        .where((p) => p.publishedAt == null)
        .toList();
    for (final old in targets) {
      final updated = MediaAttachment(
        cloud: old.cloud,
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
      await records.record(old.id).putIfDatabase(database, updated.toMap());
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
          await records.record(photo.id).delete(database!);
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
