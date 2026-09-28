import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../features/media/media_library.dart';
import 'online_backend.dart';
import 'online_moments.dart';

/// Minimalist celebration bottom sheet when a user marks a task done.
class TaskCompletionPromptSheet extends StatefulWidget {
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
  State<TaskCompletionPromptSheet> createState() =>
      _TaskCompletionPromptSheetState();
}

class _TaskCompletionPromptSheetState
    extends State<TaskCompletionPromptSheet> {
  final List<XFile> _selectedFiles = [];
  bool _loading = false;
  bool _attachLocation = false;
  late final TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController();
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final uid = widget.backend.auth.currentUser?.uid ?? '';
    final accDoc = await widget.backend.firestore.collection('accounts').doc(uid).get();
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

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() {
        _selectedFiles.add(picked);
      });
    }
  }

  Future<void> _completeTask() async {
    setState(() => _loading = true);
    try {
      final myUid = widget.backend.auth.currentUser?.uid ?? '';

      // If photos were selected, process each and save to store
      for (final file in _selectedFiles) {
        final bytes = await file.readAsBytes();
        final draft = await compute(processPhoto, {
          'bytes': bytes,
          'source': 'library',
        });
        var caption = widget.taskTitle;
        if (_attachLocation && _locationController.text.trim().isNotEmpty) {
          caption = '$caption • ${_locationController.text.trim()}';
        }
        await widget.momentStore.add(
          myUid,
          widget.spaceId,
          draft,
          caption,
        );
      }

      final operationId = widget.backend.firestore
          .collection('operationIds')
          .doc()
          .id;
      await widget.backend.call('actOnTask', {
        'spaceId': widget.spaceId,
        'taskId': widget.taskId,
        'operationId': operationId,
        'action': 'complete',
      });

      if (mounted) {
        widget.onCompleted();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete task: $e')),
        );
      }
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
                          onTap: _pickPhotos,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EEFF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF244BFF).withValues(alpha: 0.3)),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF244BFF)),
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
                                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                }
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              },
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => setState(() => _selectedFiles.removeAt(index)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _attachLocation,
                      onChanged: (val) => setState(() => _attachLocation = val ?? false),
                      activeColor: const Color(0xFF244BFF),
                    ),
                    const Text(
                      'Attach location label',
                      style: TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF202633),
                      ),
                    ),
                  ],
                ),
                if (_attachLocation) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: _locationController,
                    style: const TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 14,
                      color: Color(0xFF202633),
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Living room, Grocery store...',
                      hintStyle: const TextStyle(color: Color(0xFF8E95A5)),
                      filled: true,
                      fillColor: const Color(0xFFFFFEFB),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E2DA)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E2DA)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF244BFF)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
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
                      onPressed: _pickPhotos,
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
