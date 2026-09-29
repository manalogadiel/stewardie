import 'dart:async';

import 'package:flutter/material.dart';

import 'online_backend.dart';

/// Modal bottom sheet requiring typing the space name to confirm deletion.
class SpaceDeletionSheet extends StatefulWidget {
  const SpaceDeletionSheet({
    super.key,
    required this.backend,
    required this.spaceId,
    required this.spaceName,
    required this.onDeleted,
  });

  final OnlineBackend backend;
  final String spaceId;
  final String spaceName;
  final VoidCallback onDeleted;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required String spaceId,
    required String spaceName,
    required VoidCallback onDeleted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFAF9F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SpaceDeletionSheet(
        backend: backend,
        spaceId: spaceId,
        spaceName: spaceName,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  State<SpaceDeletionSheet> createState() => _SpaceDeletionSheetState();
}

class _SpaceDeletionSheetState extends State<SpaceDeletionSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;
  bool _requested = false;

  bool get _canDelete => _controller.text.trim() == widget.spaceName.trim();

  Future<void> _performDelete() async {
    if (!_canDelete) return;

    setState(() => _busy = true);
    try {
      await widget.backend.call('deleteSpace', {'spaceId': widget.spaceId});
      // Cron remains the durable fallback if this prompt drain fails/offlines.
      unawaited(
        widget.backend
            .callSpaceAction('drainDeletion', widget.spaceId)
            .then((_) {})
            .catchError((_) {}),
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _requested = true;
        });
        widget.onDeleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete space: $e')));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Delete space',
                  style: TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Color(0xFF596171)),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _requested
                  ? 'Members can no longer open this space. Shared photos and records are being removed.'
                  : 'Type "${widget.spaceName}" to confirm deletion. This cannot be undone.',
              style: const TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 14,
                color: Color(0xFF596171),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (_requested)
              StreamBuilder(
                stream: widget.backend.firestore
                    .doc('spaceDeletionJobs/${widget.spaceId}')
                    .snapshots(),
                builder: (context, snapshot) {
                  final status = snapshot.data?.data()?['status'] as String?;
                  final label = status == 'done'
                      ? 'Space deleted'
                      : status == 'failed'
                      ? 'Deletion needs attention. The cleanup worker will retry.'
                      : 'Deletion pending';
                  return Semantics(
                    liveRegion: true,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  );
                },
              )
            else
              TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF202633),
                ),
                decoration: InputDecoration(
                  hintText: widget.spaceName,
                  hintStyle: const TextStyle(color: Color(0xFF8E95A5)),
                  filled: true,
                  fillColor: const Color(0xFFFFFEFB),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE5E2DA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE5E2DA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFD32F2F)),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            const SizedBox(height: 24),
            if (_requested)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              )
            else if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _canDelete ? _performDelete : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE5E2DA),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Delete space',
                    style: TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
