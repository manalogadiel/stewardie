import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../mascot_stage.dart';

/// Compact modal invitation displayed once after account setup:
/// "A quick look around?" with "Show me around" and "Explore on my own".
class TutorialInvitationSheet extends StatelessWidget {
  const TutorialInvitationSheet({
    super.key,
    required this.onAccept,
    required this.onDismiss,
  });

  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SoftPop.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => TutorialInvitationSheet(
        onAccept: () => Navigator.pop(ctx, true),
        onDismiss: () => Navigator.pop(ctx, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MascotStage(pose: MascotPose.butterWelcome, compact: true),
            const SizedBox(height: 12),
            const Text(
              'A quick look around?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: SoftPop.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take a 1-minute guided tour of spaces, moods, and everyday tasks. You can skip anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: SoftPop.secondary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: SoftPop.blue,
                foregroundColor: SoftPop.surface,
                minimumSize: const Size(48, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Show me around',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text(
                'Explore on my own',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SoftPop.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
