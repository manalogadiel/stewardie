import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sembast/sembast.dart';

import '../../core/clay.dart';
import '../../core/theme.dart';
import '../../core/demo_state.dart';
import '../../core/widgets.dart';
import '../timeline/domain/models.dart';
import 'camera_screen.dart';
import 'media_library.dart';

final photoPickerProvider = Provider<Future<CapturedPhoto?> Function()>(
  (ref) => () async {
    final repo = ref.read(repositoryProvider);
    final db = ref.read(mediaLibraryProvider).database;
    if (db != null) {
      await metaRecords.record('picker-account').put(db, {
        'uid': repo.isShared ? repo.currentUserId : null,
      });
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (db != null) await metaRecords.record('picker-account').delete(db);
    return picked == null
        ? null
        : CapturedPhoto(await picked.readAsBytes(), 'library');
  },
);
Future<bool?> showPhotoComposer(
  BuildContext context,
  Space space, {
  Task? task,
  bool complete = false,
  CapturedPhoto? recovered,
  bool? initialCamera,
}) => showModalBottomSheet<bool>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: SoftPop.surface,
  constraints: const BoxConstraints(maxWidth: 640),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (sheet) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            (MediaQuery.sizeOf(sheet).height -
                    MediaQuery.paddingOf(sheet).top -
                    MediaQuery.viewInsetsOf(sheet).bottom -
                    24)
                .clamp(180.0, MediaQuery.sizeOf(sheet).height),
      ),
      child: PhotoComposer(
        space: space,
        task: task,
        complete: complete,
        recovered: recovered,
        initialCamera: initialCamera,
      ),
    ),
  ),
);

class PhotoComposer extends ConsumerStatefulWidget {
  const PhotoComposer({
    super.key,
    required this.space,
    this.task,
    this.complete = false,
    this.recovered,
    this.initialCamera,
  });
  final Space space;
  final Task? task;
  final bool complete;
  final CapturedPhoto? recovered;
  final bool? initialCamera;
  @override
  ConsumerState<PhotoComposer> createState() => _PhotoComposerState();
}

class _PhotoComposerState extends ConsumerState<PhotoComposer> {
  final caption = TextEditingController();
  PhotoDraft? draft;
  bool busy = false;
  bool attached = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final existing = widget.task == null
        ? null
        : ref.read(mediaLibraryProvider).forTask(widget.task!.id).firstOrNull;
    if (existing != null) {
      attached = true;
      draft = existing.photo;
      caption.text = existing.caption;
      return;
    }
    if (widget.recovered != null) prepare(widget.recovered!);
    if (widget.initialCamera != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) acquire(widget.initialCamera!);
      });
    }
  }

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  Future<void> prepare(CapturedPhoto photo) async {
    setState(() => busy = true);
    try {
      final processed = await compute(processPhoto, {
        'bytes': photo.bytes,
        'source': photo.source,
      });
      if (mounted) {
        setState(() {
          draft = processed;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'This photo could not be prepared. Choose another.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> acquire(bool camera) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final CapturedPhoto? photo = camera
          ? await Navigator.of(context).push<CapturedPhoto>(
              MaterialPageRoute(
                builder: (_) => CameraScreen(spaceName: widget.space.name),
              ),
            )
          : await ref.read(photoPickerProvider)();
      if (photo != null && mounted) await prepare(photo);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not open your photos. You can try again or cancel.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (busy || draft == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final library = ref.read(mediaLibraryProvider);
      // The accepted attachment is durable before completion, and is reusable
      // if completion fails. Retrying never creates a second attachment.
      if (widget.task == null ||
          (!attached &&
              library.forTask(widget.task!.id).length <
                  library.attachmentLimit)) {
        await library.add(
          draft!,
          widget.space.id,
          ref.read(repositoryProvider).currentUserId,
          caption.text,
          taskId: widget.task?.id,
        );
        if (widget.task != null && mounted) setState(() => attached = true);
      }
      if (widget.complete) {
        if (!ref
            .read(demoProvider)
            .tasks
            .firstWhere((t) => t.id == widget.task!.id)
            .isDone) {
          await ref
              .read(demoProvider.notifier)
              .act(widget.task!, TaskAction.complete);
        }
        final state = ref.read(demoProvider);
        final updated = state.tasks.firstWhere((t) => t.id == widget.task!.id);
        if (!updated.isDone) {
          throw StateError(
            state.errors[updated.id] ??
                'Could not finish the task. Your photo is kept for retry.',
          );
        }
        await library.publishTask(updated);
      }
      if (mounted) {
        setState(() => closing = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message
              : 'Could not save the photo. Your draft is here for retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool closing = false;
  Future<void> close() async {
    if (busy) return;
    if (draft != null && !attached) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Discard this moment?'),
          content: const Text(
            'Your unsaved photo and caption will be discarded.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: closing,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) close();
    },
    child: Material(
      color: SoftPop.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: SoftPop.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    widget.complete
                        ? 'A little win'
                        : widget.task == null
                        ? 'Add a moment'
                        : 'Task photo',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: busy ? null : close,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (draft == null)
              const ClayArt('greeting', height: 96)
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.memory(
                  draft!.bytes,
                  height: 260,
                  fit: BoxFit.contain,
                ),
              ),
            const SizedBox(height: 16),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(liveRegion: true, child: Text(error!)),
              ),
            Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy || attached ? null : () => acquire(true),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    draft?.source == 'camera' ? 'Retake' : 'Take photo',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy || attached ? null : () => acquire(false),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    draft == null ? 'Choose photo' : 'Choose another',
                  ),
                ),
              ],
            ),
            if (draft != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: caption,
                readOnly: attached,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'A caption (optional)',
                ),
              ),
              const SizedBox(height: 16),
              Paper(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.read(repositoryProvider).isShared &&
                              !ref.read(mediaLibraryProvider).supportsSharing
                          ? 'Saved in ${widget.space.name} on this device'
                          : 'Sharing with ${widget.space.name}',
                    ),
                    if (!ref.read(repositoryProvider).isShared)
                      Text('${widget.space.members.length} members'),
                    if (widget.task != null) Text(widget.task!.title),
                    if (widget.task != null &&
                        !widget.complete &&
                        !widget.task!.isDone)
                      const Text('Appears in Moments when this task is done.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(
                  widget.complete
                      ? (ref.read(repositoryProvider).isShared &&
                                !ref.read(mediaLibraryProvider).supportsSharing
                            ? 'Finish & save photo'
                            : 'Finish & share photo')
                      : widget.task == null
                      ? (ref.read(repositoryProvider).isShared &&
                                !ref.read(mediaLibraryProvider).supportsSharing
                            ? 'Save moment'
                            : 'Share moment')
                      : 'Attach photo',
                ),
              ),
            ],
            TextButton(
              onPressed: busy ? null : close,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}

final _completionFlows = Provider<Set<String>>((ref) => <String>{});

Future<void> completeWithPhoto(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final flows = ref.read(_completionFlows);
  if (!flows.add(task.id)) return;
  try {
    await _completeWithPhoto(context, ref, task);
  } finally {
    flows.remove(task.id);
  }
}

Future<void> _completeWithPhoto(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final library = ref.read(mediaLibraryProvider);
  final space = ref
      .read(repositoryProvider)
      .spaces
      .firstWhere((s) => s.id == task.spaceId);
  if (library.forTask(task.id).isEmpty) {
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A photo for this little win?',
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('A photo is optional.'),
              TextButton(
                onPressed: () => Navigator.pop(sheet, 'skip'),
                child: const Text('Mark done without photo'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheet, 'camera'),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take photo'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheet, 'library'),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose photo'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheet),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'camera' || choice == 'library') {
      final result = await showPhotoComposer(
        context,
        space,
        task: task,
        complete: true,
        initialCamera: choice == 'camera',
      );
      if (result != true &&
          context.mounted &&
          library.forTask(task.id).isEmpty &&
          !ref
              .read(demoProvider)
              .tasks
              .firstWhere((t) => t.id == task.id)
              .isDone) {
        // A retained photo after a failed completion must never turn Cancel
        // into an implicit completion. Always ask for an explicit decision.
        await _completeWithPhoto(context, ref, task);
      }
      return;
    }
  }
  await ref.read(demoProvider.notifier).act(task, TaskAction.complete);
  final updated = ref
      .read(demoProvider)
      .tasks
      .firstWhere((t) => t.id == task.id);
  if (updated.isDone) {
    try {
      await library.publishTask(updated);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Task done. Open its photo to retry adding it to Moments.',
            ),
          ),
        );
      }
    }
  }
}
