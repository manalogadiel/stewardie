import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../mascot_stage.dart';
import '../staggered_entrance.dart';

/// Screen 1: Hi! Welcome
/// “Little things, together.”
/// One primary Get started button.
/// A quiet Already have an account? Sign in text link preserves returning access.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
    required this.onSignIn,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MascotStage(pose: MascotPose.butterWelcome),
              const SizedBox(height: 24),
              const StaggeredEntrance(
                order: 1,
                child: Text(
                  'Little things,\ntogether.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    letterSpacing: -0.4,
                    color: SoftPop.ink,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const StaggeredEntrance(
                order: 2,
                child: Text(
                  'A gentle shared space for plans, everyday help, and moments that matter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: SoftPop.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              StaggeredEntrance(
                order: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: onGetStarted,
                      style: FilledButton.styleFrom(
                        backgroundColor: SoftPop.blue,
                        foregroundColor: SoftPop.surface,
                        minimumSize: const Size(48, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Get started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onSignIn,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text(
                        'Already have an account? Sign in',
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
            ],
          ),
        ),
      ),
    );
  }
}
