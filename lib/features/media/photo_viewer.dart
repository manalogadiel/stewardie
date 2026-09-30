import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/clay.dart';
import '../../core/soft_pop_backdrop.dart';
import '../../core/demo_state.dart';
import '../../core/theme.dart';
import '../../core/stewardie_map.dart';
import '../timeline/domain/models.dart';
import 'media_library.dart';
import 'photo_composer.dart';
import 'export.dart';

Future<void> viewPhoto(BuildContext context, MediaAttachment photo) =>
    Navigator.of(
      context,
      rootNavigator: true,
    ).push<void>(MaterialPageRoute(builder: (_) => PhotoViewer(photo)));

Future<void> showPhotoLocation(
  BuildContext context,
  MediaAttachment photo,
) async {
  final pin = photo.pin;
  if (pin == null) return;
  final point = LatLng(pin.lat, pin.lng);
  final details = [
    pin.source == 'capture' ? 'Taken here' : 'Place tag',
    pin.label,
    if (pin.source == 'capture' && pin.locatedAt != null)
      '${MaterialLocalizations.of(context).formatMediumDate(pin.locatedAt!.toLocal())} '
          '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(pin.locatedAt!.toLocal()))}',
    if (pin.accuracy != null) '±${pin.accuracy!.round()} m',
  ].join(' · ');
  var expandedStyle = mapTilerKey.isEmpty
      ? StewardieMapStyle.streets
      : StewardieMapStyle.satellite;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setMapState) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .8,
          child: Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheet).height * .25,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(details),
                  ),
                ),
              ),
              Expanded(
                child: StewardieMap(
                  center: point,
                  zoom: 16,
                  style: expandedStyle,
                  onStyleChanged: (value) =>
                      setMapState(() => expandedStyle = value),
                  markers: [
                    Marker(
                      point: point,
                      width: 72,
                      height: 72,
                      child: ClipOval(
                        child: Image.memory(
                          photo.photo.thumbnail,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PhotoViewer extends ConsumerStatefulWidget {
  const PhotoViewer(this.photo, {super.key});
  final MediaAttachment photo;
  @override
  ConsumerState<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<PhotoViewer> {
  late final _full = ref.read(mediaLibraryProvider).fullPhoto(widget.photo);
  bool saving = false;
  String? message;
  @override
  Widget build(BuildContext context) {
    ref.watch(demoProvider);
    final allowed = ref
        .read(repositoryProvider)
        .spaces
        .any((s) => s.id == widget.photo.spaceId);
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This space is no longer available.')),
      );
    }
    final space = ref
        .read(repositoryProvider)
        .spaces
        .firstWhere((s) => s.id == widget.photo.spaceId);
    final author = space.member(widget.photo.uploaderId).name;
    return Scaffold(
      backgroundColor: SoftPop.canvas,
      appBar: AppBar(
        foregroundColor: SoftPop.ink,
        title: const Text('Your moment', style: TextStyle(color: SoftPop.ink)),
        actions: [
          if (widget.photo.pin != null)
            IconButton(
              tooltip: 'Photo location',
              onPressed: () => showPhotoLocation(context, widget.photo),
              icon: const Icon(Icons.place_rounded),
            ),
          IconButton(
            tooltip: 'Save photo',
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      final result = await exportPhoto(
                        await ref
                            .read(mediaLibraryProvider)
                            .fullPhoto(widget.photo),
                        widget.photo.id,
                      );
                      if (mounted) setState(() => message = result);
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => message = 'Could not save. Check photo permissions and available storage, then try again.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: SoftPopBackdrop()),
            Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: InteractiveViewer(
                        minScale: .8,
                        maxScale: 5,
                        child: Center(
                          child: FutureBuilder(
                            future: _full,
                            builder: (context, snapshot) => snapshot.hasError
                                ? const Text(
                                    'Could not load this photo. Close and try again.',
                                    style: TextStyle(color: SoftPop.ink),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Image.memory(
                                      snapshot.data ??
                                          widget.photo.photo.thumbnail,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    author,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.photo.caption.isNotEmpty ||
                    widget.photo.taskTitle != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      widget.photo.taskTitle ?? widget.photo.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (widget.photo.pin != null)
                  Flexible(
                    child: SingleChildScrollView(
                      child: _photoLocation(context),
                    ),
                  ),
                if (saving) const LinearProgressIndicator(),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        message!,
                        style: const TextStyle(color: SoftPop.ink),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoLocation(BuildContext context) {
    final pin = widget.photo.pin!;
    final point = LatLng(pin.lat, pin.lng);
    final subtitle = pin.source == 'capture' ? 'Taken here' : 'Place tag';
    final details = [
      subtitle,
      pin.label,
      if (pin.source == 'capture' && pin.locatedAt != null)
        '${MaterialLocalizations.of(context).formatMediumDate(pin.locatedAt!.toLocal())} '
            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(pin.locatedAt!.toLocal()))}',
      if (pin.accuracy != null) '±${pin.accuracy!.round()} m',
    ].join(' · ');
    Widget map(double height) => SizedBox(
      height: height,
      child: StewardieMap(
        center: point,
        zoom: 15,
        markers: [
          Marker(
            point: point,
            width: 56,
            height: 56,
            child: ClipOval(
              child: Image.memory(
                widget.photo.photo.thumbnail,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(details, style: const TextStyle(color: SoftPop.ink)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                showPhotoLocation(context, widget.photo);
              },
              child: map(150),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> removePhoto(
  BuildContext context,
  WidgetRef ref,
  MediaAttachment photo,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Remove this photo?'),
      content: const Text(
        'It will disappear from this task and Moments. Task completion stays unchanged.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Keep photo'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref
        .read(mediaLibraryProvider)
        .remove(photo, ref.read(repositoryProvider).currentUserId);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove the photo. Try again.')),
      );
    }
  }
}

class TaskPhotos extends ConsumerStatefulWidget {
  const TaskPhotos(this.task, {super.key});
  final Task task;
  @override
  ConsumerState<TaskPhotos> createState() => _TaskPhotosState();
}

class _TaskPhotosState extends ConsumerState<TaskPhotos> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  void _refresh() {
    if (mounted &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
      unawaited(ref.read(mediaLibraryProvider).refresh(widget.task.spaceId));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final photos = ref
        .watch(mediaProvider)
        .where((p) => p.taskId == task.id && p.spaceId == task.spaceId)
        .toList();
    final space = ref
        .read(repositoryProvider)
        .spaces
        .firstWhere((s) => s.id == task.spaceId);
    final canAdd =
        task.ownerId == ref.read(repositoryProvider).currentUserId ||
        task.creatorId == ref.read(repositoryProvider).currentUserId;
    return ClayPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Photos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (ref.read(mediaLibraryProvider).syncError != null)
            Text(ref.read(mediaLibraryProvider).syncError!),
          if (photos.any(
            (p) => ref.read(mediaLibraryProvider).pendingIds.contains(p.id),
          ))
            TextButton(
              onPressed: () => ref.read(mediaLibraryProvider).retryPending(),
              child: const Text('Retry sharing photos'),
            ),
          for (final photo in photos) ...[
            Semantics(
              label: 'Open task photo',
              button: true,
              child: InkWell(
                onTap: () => viewPhoto(context, photo),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(
                    photo.photo.thumbnail,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            if (photo.caption.isNotEmpty) Text(photo.caption),
            if (photo.publishedAt == null)
              Text(
                task.isDone
                    ? 'Ready to add to Moments.'
                    : 'Appears in Moments when this task is done.',
              ),
            if (task.isDone && photo.publishedAt == null)
              TextButton(
                onPressed: () async {
                  try {
                    await ref.read(mediaLibraryProvider).publishTask(task);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not add to Moments. Try again.'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Retry adding to Moments'),
              ),
            if (photo.uploaderId == ref.read(repositoryProvider).currentUserId)
              TextButton(
                onPressed: () => removePhoto(context, ref, photo),
                child: const Text('Remove photo'),
              ),
          ],
          if (photos.length < ref.read(mediaLibraryProvider).attachmentLimit &&
              canAdd)
            OutlinedButton.icon(
              onPressed: () => showPhotoComposer(context, space, task: task),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add photo'),
            ),
          if (photos.isEmpty && !canAdd) const Text('No photo attached yet.'),
        ],
      ),
    );
  }
}
