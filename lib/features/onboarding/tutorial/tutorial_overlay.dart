import 'dart:async';

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
    this.onStopChanged,
    this.stops = TutorialStops.all,
    this.finishLabel = 'Got it',
  });

  final int initialStopIndex;
  final VoidCallback onFinished;
  final VoidCallback onSkipped;
  final ValueChanged<int>? onTabRequested;
  final ValueChanged<int>? onStopChanged;
  final List<TutorialStopData> stops;
  final String finishLabel;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with WidgetsBindingObserver {
  late int _currentStopIndex;
  Timer? _targetMonitor;
  Rect? _targetRect;
  bool _locating = true;
  int _requestGeneration = 0;

  @override
  void dispose() {
    _requestGeneration++;
    _targetMonitor?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureTarget();
    });
  }

  void _measureTarget() {
    final stop = widget.stops[_currentStopIndex];
    final rect = TutorialTargetRegistry.getTargetRect(
      TutorialTargetRegistry.keyForId(stop.targetKeyGetter()),
    );
    if (rect != _targetRect) setState(() => _targetRect = rect);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentStopIndex = widget.initialStopIndex.clamp(
      0,
      widget.stops.length - 1,
    );
    _syncTabIfNeeded();
  }

  void _syncTabIfNeeded() {
    final request = ++_requestGeneration;
    _targetMonitor?.cancel();
    _targetRect = null;
    _locating = true;
    var attempts = 0;
    var revealing = false;
    var revealed = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || request != _requestGeneration) return;
      final stop = widget.stops[_currentStopIndex];
      widget.onStopChanged?.call(_currentStopIndex);
      widget.onTabRequested?.call(stop.destinationTab);
      _targetMonitor = Timer.periodic(const Duration(milliseconds: 100), (
        _,
      ) async {
        if (!mounted || request != _requestGeneration) return;
        if (_locating) TutorialTargetRegistry.prepare(stop.targetKeyGetter());
        final target = TutorialTargetRegistry.keyForId(stop.targetKeyGetter());
        final targetContext = target?.currentContext;
        if (!revealed &&
            !revealing &&
            targetContext != null &&
            targetContext.mounted) {
          revealing = true;
          await Scrollable.ensureVisible(
            targetContext,
            alignment: .2,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
          );
          if (!mounted || request != _requestGeneration) return;
          revealed = true;
          revealing = false;
        }
        _measureTarget();
        if (_targetRect != null && _locating) {
          setState(() => _locating = false);
        } else if (++attempts >= 40 && _locating && !revealing) {
          setState(() => _locating = false);
        }
        // Keep measuring while visible: route rebuilds, scroll, keyboard and
        // orientation can move a target after its first successful layout.
      });
    });
  }

  void _nextStop() {
    if (_currentStopIndex < widget.stops.length - 1) {
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
    final stop = widget.stops[_currentStopIndex];
    final targetRect = _targetRect;

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final isLast = _currentStopIndex == widget.stops.length - 1;

    final above = targetRect == null
        ? 0.0
        : targetRect.top - mediaQuery.padding.top - 32;
    final below = targetRect == null
        ? 0.0
        : screenSize.height -
              targetRect.bottom -
              mediaQuery.padding.bottom -
              mediaQuery.viewInsets.bottom -
              32;
    // Fit the explanation entirely on the side with more room.
    final Alignment cardAlignment;
    if (targetRect != null) {
      final cardAbove = above > below;
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
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    maxHeight: targetRect == null
                        ? screenSize.height - mediaQuery.padding.vertical - 24
                        : (above > below ? above : below).clamp(
                            80.0,
                            screenSize.height,
                          ),
                  ),
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
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header with Stop count and Skip
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
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
                                  'Stop ${_currentStopIndex + 1} of ${widget.stops.length}',
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
                              if (mediaQuery.textScaler.scale(16) <= 24) ...[
                                const SizedBox(width: 12),
                                MascotStage(pose: stop.pose, compact: true),
                              ],
                            ],
                          ),

                          // The highlighted control is the real app UI. Avoid a
                          // miniature copy that drifts as the screens change.
                          if (targetRect == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _locating
                                  ? const Text(
                                      'Finding this control…',
                                      style: TextStyle(
                                        color: SoftPop.secondary,
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        const Text(
                                          'This part has not loaded.',
                                          style: TextStyle(
                                            color: SoftPop.secondary,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              setState(_syncTabIfNeeded),
                                          child: const Text('Retry'),
                                        ),
                                        TextButton(
                                          onPressed: _nextStop,
                                          child: const Text('Skip this stop'),
                                        ),
                                      ],
                                    ),
                            ),

                          const SizedBox(height: 12),

                          // Progress dots and Back / Next actions
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Progress dots
                              if (widget.stops.length > 1)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(widget.stops.length, (
                                    i,
                                  ) {
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
                                  }),
                                ),
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
                                onPressed: targetRect == null
                                    ? null
                                    : _nextStop,
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
                                  isLast ? widget.finishLabel : 'Next',
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
