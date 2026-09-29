import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'onboarding_store.dart';

/// Top bar with a smooth, restrained progress pill and an accessible 48px Back target.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.step,
    required this.onBack,
    this.canGoBack = true,
  });

  final OnboardingStep step;
  final VoidCallback? onBack;
  final bool canGoBack;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final isWelcome = step == OnboardingStep.welcome;
    final isDone = step == OnboardingStep.allSet;

    // Value from 0.0 to 1.0 clamped
    final double progressValue = step.progress.clamp(0.0, 1.0);

    return Semantics(
      label: 'Onboarding step ${step.index} of 6, ${(progressValue * 100).toInt()}% complete',
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                // 48-pixel Back target
                if (!isWelcome && !isDone && canGoBack) ...[
                  IconButton(
                    key: const ValueKey('onboarding_back_button'),
                    onPressed: onBack,
                    tooltip: 'Back',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: SoftPop.ink,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                ] else
                  const SizedBox(width: 8),

                // Smooth progress track
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEBE6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: Duration(
                              milliseconds: reduceMotion ? 100 : 360,
                            ),
                            curve: Curves.easeOutCubic,
                            width: constraints.maxWidth * progressValue,
                            height: 8,
                            decoration: BoxDecoration(
                              color: SoftPop.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
