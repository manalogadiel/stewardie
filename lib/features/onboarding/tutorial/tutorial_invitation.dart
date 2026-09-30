import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Compact modal invitation displayed once after account setup:
/// "A quick look around?" with "Show me around" and "Explore on my own".
class TutorialInvitationSheet extends StatelessWidget {
  const TutorialInvitationSheet({
    super.key,
    required this.onAccept,
    required this.onDismiss,
    this.resume = false,
  });

  final VoidCallback onAccept;
  final VoidCallback onDismiss;
  final bool resume;

  static Future<bool?> show(BuildContext context, {bool resume = false}) {
    if (resume) {
      return showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: SoftPop.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: MediaQuery.sizeOf(ctx).height * .85,
            ),
            child: SingleChildScrollView(
              child: TutorialInvitationSheet(
                resume: true,
                onAccept: () => Navigator.pop(ctx, true),
                onDismiss: () => Navigator.pop(ctx, false),
              ),
            ),
          ),
        ),
      );
    }
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SoftPop.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .85,
        ),
        child: SingleChildScrollView(
          child: TutorialInvitationSheet(
            onAccept: () => Navigator.pop(ctx, true),
            onDismiss: () => Navigator.pop(ctx, false),
            resume: resume,
          ),
        ),
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
            Image.asset(
              'assets/illustrations/tour-navigation-guide.png',
              height: 150,
              semanticLabel: 'A guided look around Stewardie',
            ),
            const SizedBox(height: 12),
            const Text(
              'Ready to look around?',
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
                backgroundColor: SoftPop.lightButter,
                foregroundColor: SoftPop.ink,
                side: BorderSide.none,
                elevation: 3,
                shadowColor: SoftPop.ink.withValues(alpha: .16),
                minimumSize: const Size(48, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                resume ? 'Continue tour' : 'Show me around',
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
