import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../mascot_stage.dart';
import 'tutorial_state.dart';
import 'tutorial_target_registry.dart';

/// Modal overlay that renders a translucent scrim, rounded spotlight cutout,
/// and responsive explanation card for the guided tour.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.initialStopIndex,
    required this.onFinished,
    required this.onSkipped,
    this.onTabRequested,
  });

  final int initialStopIndex;
  final VoidCallback onFinished;
  final VoidCallback onSkipped;
  final ValueChanged<int>? onTabRequested;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  late int _currentStopIndex;

  @override
  void initState() {
    super.initState();
    _currentStopIndex = widget.initialStopIndex.clamp(
      0,
      TutorialStops.all.length - 1,
    );
    _syncTabIfNeeded();
  }

  void _syncTabIfNeeded() {
    final requestedIndex = _currentStopIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || requestedIndex != _currentStopIndex) return;
      final stop = TutorialStops.all[requestedIndex];
      widget.onTabRequested?.call(stop.destinationTab);
      // The destination tab's target is laid out in the following frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && requestedIndex == _currentStopIndex) setState(() {});
      });
    });
  }

  void _nextStop() {
    if (_currentStopIndex < TutorialStops.all.length - 1) {
      setState(() {
        _currentStopIndex++;
      });
      _syncTabIfNeeded();
    } else {
      widget.onFinished();
    }
  }

  void _prevStop() {
    if (_currentStopIndex > 0) {
      setState(() {
        _currentStopIndex--;
      });
      _syncTabIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final stop = TutorialStops.all[_currentStopIndex];
    final targetKey = TutorialTargetRegistry.keyForId(stop.targetKeyGetter());
    final targetRect = TutorialTargetRegistry.getTargetRect(targetKey);

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final isLast = _currentStopIndex == TutorialStops.all.length - 1;

    // Determine whether explanation card sits above, below, or centered (if target absent)
    final Alignment cardAlignment;
    if (targetRect != null) {
      final targetCenterY = targetRect.center.dy;
      final cardAbove = targetCenterY > (screenSize.height * 0.55);
      cardAlignment = cardAbove ? Alignment.topCenter : Alignment.bottomCenter;
    } else {
      cardAlignment = Alignment.center;
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Scrim with cutout spotlight
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // Prevent taps leaking through
              child: CustomPaint(
                painter: _SpotlightPainter(
                  targetRect: targetRect,
                  scrimColor: const Color(0x7F202633),
                ),
              ),
            ),
          ),

          // 2. Explanation Card
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Align(
                alignment: cardAlignment,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    decoration: BoxDecoration(
                      color: SoftPop.surface,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x28202633),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header with Stop count and Skip
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4F7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Stop ${_currentStopIndex + 1} of ${TutorialStops.all.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: SoftPop.secondary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: widget.onSkipped,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                minimumSize: const Size(48, 48),
                              ),
                              child: const Text(
                                'Skip tour',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: SoftPop.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Title & mascot
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stop.title,
                                    style: const TextStyle(
                                      fontFamily: 'Fredoka',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: SoftPop.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    stop.explanation,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: SoftPop.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            MascotStage(pose: stop.pose, compact: true),
                          ],
                        ),

                        // The highlighted control is the real app UI. Avoid a
                        // miniature copy that drifts as the screens change.
                        if (targetRect == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: Text(
                              'This feature appears after you join or create a space.',
                              style: TextStyle(color: SoftPop.secondary),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Progress dots and Back / Next actions
                        Row(
                          children: [
                            // Progress dots
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                TutorialStops.all.length,
                                (i) {
                                  final active = i == _currentStopIndex;
                                  return AnimatedContainer(
                                    duration: Duration(
                                      milliseconds: reduceMotion ? 100 : 200,
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1.5,
                                    ),
                                    width: active ? 10 : 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? SoftPop.blue
                                          : const Color(0xFFD6D6DC),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const Spacer(),
                            if (_currentStopIndex > 0) ...[
                              TextButton(
                                onPressed: _prevStop,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  minimumSize: const Size(48, 48),
                                ),
                                child: const Text('Back'),
                              ),
                              const SizedBox(width: 4),
                            ],
                            FilledButton(
                              onPressed: _nextStop,
                              style: FilledButton.styleFrom(
                                backgroundColor: SoftPop.blue,
                                foregroundColor: SoftPop.surface,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                minimumSize: const Size(48, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                isLast ? 'Got it' : 'Next',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.targetRect, required this.scrimColor});

  final Rect? targetRect;
  final Color scrimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (targetRect != null) {
      // Expand target area slightly for breathing room
      final spotlightRect = targetRect!.inflate(6);
      final cutoutPath = Path()
        ..addRRect(
          RRect.fromRectAndRadius(spotlightRect, const Radius.circular(16)),
        );
      final combined = Path.combine(
        PathOperation.difference,
        screenPath,
        cutoutPath,
      );
      canvas.drawPath(combined, Paint()..color = scrimColor);

      // Draw subtle pulsing rim around cutout
      final rimPaint = Paint()
        ..color = SoftPop.blueSoft.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(spotlightRect, const Radius.circular(16)),
        rimPaint,
      );
    } else {
      canvas.drawPath(screenPath, Paint()..color = scrimColor);
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect ||
      oldDelegate.scrimColor != scrimColor;
}
