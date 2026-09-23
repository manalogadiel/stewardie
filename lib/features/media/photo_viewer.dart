import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clay.dart';
import '../../core/demo_state.dart';
import '../../core/theme.dart';
import '../timeline/domain/models.dart';
import 'media_library.dart';
import 'photo_composer.dart';
import 'export.dart';

Future<void> viewPhoto(BuildContext context, MediaAttachment photo) =>
    Navigator.of(
      context,
      rootNavigator: true,
    ).push<void>(MaterialPageRoute(builder: (_) => PhotoViewer(photo)));

class PhotoViewer extends StatefulWidget {
  const PhotoViewer(this.photo, {super.key});
  final MediaAttachment photo;
  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  bool saving = false;
  String? message;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SoftPop.ink,
    appBar: AppBar(
      foregroundColor: Colors.white,
      title: const Text('Your moment', style: TextStyle(color: Colors.white)),
      actions: [
        IconButton(
          tooltip: 'Save photo',
          onPressed: saving
              ? null
              : () async {
                  setState(() => saving = true);
                  try {
                    final result = await exportPhoto(
                      widget.photo.photo.bytes,
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
      child: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              minScale: .8,
              maxScale: 5,
              child: Center(
                child: Image.memory(
                  widget.photo.photo.bytes,
                  fit: BoxFit.contain,
                ),
              ),
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
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    ),
  );
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

class TaskPhotos extends ConsumerWidget {
  const TaskPhotos(this.task, {super.key});
  final Task task;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
