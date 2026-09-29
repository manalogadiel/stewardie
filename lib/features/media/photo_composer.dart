import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sembast/sembast.dart';

import '../../core/clay.dart';
import '../../core/place_pin.dart';
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
  showDragHandle: false,
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
  PlacePin? pin;
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
      pin = existing.pin;
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
        'framing': photo.framing.toMap(),
      });
      if (mounted) {
        setState(() {
          draft = processed;
          pin = photo.pin;
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

  void _setFramingRatio(String r) {
    if (draft == null) return;
    final FramingRect framing;
    switch (r) {
      case '1:1':
        framing = FramingRect.fromAspectRatio(
          targetRatio: 1.0,
          imageWidth: draft!.width,
          imageHeight: draft!.height,
          ratioName: '1:1',
        );
        break;
      case '3:4':
        framing = FramingRect.fromAspectRatio(
          targetRatio: 3.0 / 4.0,
          imageWidth: draft!.width,
          imageHeight: draft!.height,
          ratioName: '3:4',
        );
        break;
      case '4:3':
        framing = FramingRect.fromAspectRatio(
          targetRatio: 4.0 / 3.0,
          imageWidth: draft!.width,
          imageHeight: draft!.height,
          ratioName: '4:3',
        );
        break;
      case '9:16':
        framing = FramingRect.fromAspectRatio(
          targetRatio: 9.0 / 16.0,
          imageWidth: draft!.width,
          imageHeight: draft!.height,
          ratioName: '9:16',
        );
        break;
      case '16:9':
        framing = FramingRect.fromAspectRatio(
          targetRatio: 16.0 / 9.0,
          imageWidth: draft!.width,
          imageHeight: draft!.height,
          ratioName: '16:9',
        );
        break;
      case 'Free':
        framing = const FramingRect(
          x: 0.05,
          y: 0.05,
          width: 0.9,
          height: 0.9,
          ratioName: 'Free',
        );
        break;
      default:
        framing = FramingRect.full;
    }
    setState(() {
      draft = draft!.copyWith(framing: framing);
    });
  }

  void _updateFreeFraming({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    if (draft == null) return;
    final current = draft!.framing;
    final newW = (width ?? current.width).clamp(0.1, 1.0);
    final newH = (height ?? current.height).clamp(0.1, 1.0);
    final maxX = (1.0 - newW).clamp(0.0, 0.99);
    final maxY = (1.0 - newH).clamp(0.0, 0.99);
    final newX = (x ?? current.x).clamp(0.0, maxX);
    final newY = (y ?? current.y).clamp(0.0, maxY);

    setState(() {
      draft = draft!.copyWith(
        framing: FramingRect(
          x: newX,
          y: newY,
          width: newW,
          height: newH,
          ratioName: 'Free',
        ),
      );
    });
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
          pin: pin,
        );
        if (widget.task != null && mounted) setState(() => attached = true);
      }
      if (widget.complete) {
        final current = ref
            .read(demoProvider)
            .tasks
            .where((t) => t.id == widget.task!.id)
            .firstOrNull;
        if (current != null && !current.isDone) {
          await ref
              .read(demoProvider.notifier)
              .act(widget.task!, TaskAction.complete);
        }
        final state = ref.read(demoProvider);
        final updated = state.tasks
            .where((t) => t.id == widget.task!.id)
            .firstOrNull;
        if (updated == null) {
          return;
        }
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
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 260,
                  color: const Color(0xFF161B26),
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      if (draft?.framing.ratioName == 'Free') {
                        final dx = details.delta.dx / 260.0;
                        final dy = details.delta.dy / 260.0;
                        _updateFreeFraming(
                          x: draft!.framing.x + dx,
                          y: draft!.framing.y + dy,
                        );
                      }
                    },
                    child: FramedPhoto(
                      bytes: draft!.bytes,
                      framing: draft!.framing,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: SoftPop.canvas,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: SoftPop.border, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final r in [
                          'Original',
                          '1:1',
                          '3:4',
                          '4:3',
                          '9:16',
                          '16:9',
                          'Free',
                        ])
                          InkWell(
                            onTap: () => _setFramingRatio(r),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (draft!.framing.ratioName.toLowerCase() ==
                                            r.toLowerCase() ||
                                        (r == 'Original' &&
                                            draft!.framing.isFull))
                                    ? SoftPop.surface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow:
                                    (draft!.framing.ratioName.toLowerCase() ==
                                            r.toLowerCase() ||
                                        (r == 'Original' &&
                                            draft!.framing.isFull))
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x15202633),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                r,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      (draft!.framing.ratioName.toLowerCase() ==
                                              r.toLowerCase() ||
                                          (r == 'Original' &&
                                              draft!.framing.isFull))
                                      ? SoftPop.ink
                                      : SoftPop.secondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (draft!.framing.ratioName == 'Free')
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: SoftPop.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SoftPop.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.crop_free_rounded,
                              size: 16,
                              color: SoftPop.blue,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Free crop adjustment',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: SoftPop.ink,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(48, 24),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                _updateFreeFraming(
                                  x: (1.0 - draft!.framing.width) / 2,
                                  y: (1.0 - draft!.framing.height) / 2,
                                );
                              },
                              child: const Text(
                                'Center',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: SoftPop.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const SizedBox(
                              width: 44,
                              child: Text(
                                'Width',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: SoftPop.secondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                ),
                                child: Slider(
                                  value: draft!.framing.width,
                                  min: 0.2,
                                  max: 1.0,
                                  activeColor: SoftPop.blue,
                                  onChanged: (val) =>
                                      _updateFreeFraming(width: val),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 34,
                              child: Text(
                                '${(draft!.framing.width * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const SizedBox(
                              width: 44,
                              child: Text(
                                'Height',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: SoftPop.secondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                ),
                                child: Slider(
                                  value: draft!.framing.height,
                                  min: 0.2,
                                  max: 1.0,
                                  activeColor: SoftPop.blue,
                                  onChanged: (val) =>
                                      _updateFreeFraming(height: val),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 34,
                              child: Text(
                                '${(draft!.framing.height * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const SizedBox(
                              width: 44,
                              child: Text(
                                'Pan X',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: SoftPop.secondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                ),
                                child: Slider(
                                  value: draft!.framing.x,
                                  min: 0.0,
                                  max: (1.0 - draft!.framing.width).clamp(
                                    0.001,
                                    1.0,
                                  ),
                                  activeColor: SoftPop.blue,
                                  onChanged: (val) =>
                                      _updateFreeFraming(x: val),
                                ),
                              ),
                            ),
                            const SizedBox(width: 34),
                          ],
                        ),
                        Row(
                          children: [
                            const SizedBox(
                              width: 44,
                              child: Text(
                                'Pan Y',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: SoftPop.secondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                ),
                                child: Slider(
                                  value: draft!.framing.y,
                                  min: 0.0,
                                  max: (1.0 - draft!.framing.height).clamp(
                                    0.001,
                                    1.0,
                                  ),
                                  activeColor: SoftPop.blue,
                                  onChanged: (val) =>
                                      _updateFreeFraming(y: val),
                                ),
                              ),
                            ),
                            const SizedBox(width: 34),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
              if (pin != null)
                Paper(
                  color: SoftPop.warm,
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pin!.source == 'capture'
                              ? 'Capture location · ${pin!.accuracy?.round() ?? '?'} m accuracy'
                              : 'Manually chosen place · ${pin!.label}',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove photo location',
                        onPressed: () => setState(() => pin = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              if (draft!.source != 'camera' && pin == null)
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showPlacePicker(context);
                    if (selected != null && mounted)
                      setState(() => pin = selected);
                  },
                  icon: const Icon(Icons.place_outlined),
                  label: const Text('Add a manual place (optional)'),
                ),
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
  final spaces = ref.read(repositoryProvider).spaces;
  final space =
      spaces.where((s) => s.id == task.spaceId).firstOrNull ??
      spaces.firstOrNull;
  if (space == null) return;
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
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheet, 'camera'),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take photo'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheet, 'library'),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose photo'),
              ),
              const SizedBox(height: 8),
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
      if (result != true) {
        return;
      }
      return;
    }
  }
  await ref.read(demoProvider.notifier).act(task, TaskAction.complete);
  final updated = ref
      .read(demoProvider)
      .tasks
      .where((t) => t.id == task.id)
      .firstOrNull;
  if (updated != null && updated.isDone) {
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
