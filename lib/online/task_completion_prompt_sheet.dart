import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../features/media/media_library.dart';
import '../features/media/camera_screen.dart';
import '../core/place_pin.dart';
import 'online_backend.dart';
import 'online_moments.dart';

/// Minimalist celebration bottom sheet when a user marks a task done.
class TaskCompletionPromptSheet extends ConsumerStatefulWidget {
  const TaskCompletionPromptSheet({
    super.key,
    required this.backend,
    required this.spaceId,
    required this.taskId,
    required this.taskTitle,
    required this.momentStore,
    required this.onCompleted,
  });

  final OnlineBackend backend;
  final String spaceId;
  final String taskId;
  final String taskTitle;
  final OnlineMomentsStore momentStore;
  final VoidCallback onCompleted;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required String spaceId,
    required String taskId,
    required String taskTitle,
    required OnlineMomentsStore momentStore,
    required VoidCallback onCompleted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFAF9F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => TaskCompletionPromptSheet(
        backend: backend,
        spaceId: spaceId,
        taskId: taskId,
        taskTitle: taskTitle,
        momentStore: momentStore,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  ConsumerState<TaskCompletionPromptSheet> createState() =>
      _TaskCompletionPromptSheetState();
}

class _TaskCompletionPromptSheetState
    extends ConsumerState<TaskCompletionPromptSheet> {
  final List<XFile> _selectedFiles = [];
  bool _loading = false;
  late final String _operationId = widget.backend.firestore
      .collection('operationIds')
      .doc()
      .id;
  bool _confirmed = false;
  final Map<String, String> _attachmentIds = {};
  final Map<String, CapturedPhoto> _captures = {};
  final Map<String, PlacePin> _capturePins = {};
  Future<void> _pickPhotos() async {
    if (_loading || _confirmed) return;
    final picker = ImagePicker();
    final uid = widget.backend.auth.currentUser?.uid ?? '';
    final accDoc = await widget.backend.firestore
        .collection('accounts')
        .doc(uid)
        .get();
    final isPlus = accDoc.data()?['tier'] == 'plus';
    final maxPhotos = isPlus ? 5 : 1;

    if (_selectedFiles.length >= maxPhotos) {
      if (!isPlus && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Basic includes 1 photo. Upgrade to Plus for up to 5 photos.',
              style: TextStyle(fontFamily: 'NunitoSans'),
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFFFAF9F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    XFile? picked;
    if (source == ImageSource.camera) {
      if (!mounted) return;
      final capture = await Navigator.of(context).push<CapturedPhoto>(MaterialPageRoute(
        builder: (_) => const CameraScreen(spaceName: 'Task photo')));
      if (capture != null) {
        final path = 'capture-${DateTime.now().microsecondsSinceEpoch}.jpg';
        picked = XFile.fromData(capture.bytes, path: path, name: path);
        _captures[path] = capture;
        if (capture.pin != null) _capturePins[path] = capture.pin!;
        capture.pendingPin?.then((pin) {
          if (mounted && !_loading && !_confirmed && pin != null) {
            _capturePins[path] = pin;
          }
        });
      }
    } else {
      picked = await picker.pickImage(source: source, requestFullMetadata: false);
    }

    final selected = picked;
    if (selected != null && mounted) {
      setState(() {
        _selectedFiles.add(selected);
      });
    }
  }

  Future<void> _completeTask() async {
    if (_loading) return;
    setState(() => _loading = true);
    final uid = widget.backend.auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final library = ref.read(mediaLibraryProvider);
    final capturePins = Map<String, PlacePin>.from(_capturePins);
    try {
      if (!_confirmed) {
        await widget.backend.call('actOnTask', {
          'spaceId': widget.spaceId,
          'taskId': widget.taskId,
          'operationId': _operationId,
          'action': 'complete',
        });
        _confirmed = true;
        widget.onCompleted();
      }
      for (final file in _selectedFiles) {
        if (widget.backend.auth.currentUser?.uid != uid) return;
        final id = _attachmentIds.putIfAbsent(
          file.path,
          () => widget.backend.firestore.collection('photoIds').doc().id,
        );
        final draft = await compute(processPhoto, {
          'bytes': await file.readAsBytes(),
          'source': _captures[file.path]?.source ?? 'library',
          if (_captures[file.path]?.cropRatio != null) 'cropRatio': _captures[file.path]!.cropRatio!,
        });
        await library.add(
          draft,
          widget.spaceId,
          uid,
          widget.taskTitle,
          taskId: widget.taskId,
          attachmentId: id,
          pin: capturePins[file.path],
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _confirmed
                  ? 'Task finished. Photo preparation failed; retry or close to finish without photos.'
                  : 'Task could not be finished. Check your connection and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + media.viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Finished',
                    style: TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF202633),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF596171)),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _selectedFiles.isEmpty
                    ? 'Attach moments to celebrate completion.'
                    : '${_selectedFiles.length} photo${_selectedFiles.length > 1 ? 's' : ''} attached',
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 15,
                  color: Color(0xFF596171),
                ),
              ),
              const SizedBox(height: 20),
              if (_selectedFiles.isNotEmpty) ...[
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedFiles.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      if (index == _selectedFiles.length) {
                        return InkWell(
                          onTap: _loading || _confirmed ? null : _pickPhotos,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF244BFF)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.add_a_photo_outlined,
                              color: Color(0xFF244BFF),
                            ),
                          ),
                        );
                      }
                      return Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: const Color(0xFFE5E2DA),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: FutureBuilder<Uint8List>(
                              future: _selectedFiles[index].readAsBytes(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: _loading || _confirmed ? null : () => setState(
                                () => _selectedFiles.removeAt(index),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                if (_selectedFiles.isEmpty) ...[
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _confirmed ? null : _pickPhotos,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF244BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Add photo',
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _completeTask,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF202633),
                        side: const BorderSide(color: Color(0xFFD4D0C8)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Done without photo',
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _completeTask,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF244BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Share & complete',
                        style: TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
