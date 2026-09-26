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
  bool _loading = false;

  Future<void> _completeWithoutPhoto() async {
    setState(() => _loading = true);
    try {
      await widget.backend.call('markTaskDone', {
        'spaceId': widget.spaceId,
        'taskId': widget.taskId,
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

  Future<void> _addPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    ) ??
        await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 85,
        );

    if (picked == null) return;

    setState(() => _loading = true);
    try {
      final bytes = await picked.readAsBytes();
      final draft = await compute(processPhoto, {
        'bytes': bytes,
        'source': 'library',
      });
      final myUid = widget.backend.auth.currentUser?.uid ?? '';
      await widget.momentStore.add(
        myUid,
        widget.spaceId,
        draft,
        widget.taskTitle,
      );

      await widget.backend.call('markTaskDone', {
        'spaceId': widget.spaceId,
        'taskId': widget.taskId,
      });

      if (mounted) {
        widget.onCompleted();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload photo: $e')),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4D0C8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
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
            const Text(
              'Add a photo?',
              style: TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 15,
                color: Color(0xFF596171),
              ),
            ),
            const SizedBox(height: 28),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _addPhoto,
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
                  onPressed: _completeWithoutPhoto,
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
            ],
          ],
        ),
      ),
    );
  }
}
