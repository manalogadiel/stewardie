import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../mascot_stage.dart';
import '../staggered_entrance.dart';

/// Screen 7: All set, [Name]!
/// Celebratory conclusion with restrained confetti and "Open Stewardie".
/// The primary button is immediately usable without forced delays.
class AllSetScreen extends StatefulWidget {
  const AllSetScreen({
    super.key,
    required this.name,
    required this.onOpenApp,
  });

  final String name;
  final VoidCallback onOpenApp;

  @override
  State<AllSetScreen> createState() => _AllSetScreenState();
}

class _AllSetScreenState extends State<AllSetScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final displayName = widget.name.trim().isNotEmpty
        ? widget.name.trim()
        : 'friend';

    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MascotStage(
                    pose: MascotPose.done,
                    celebrating: true,
                  ),
                  const SizedBox(height: 24),
                  StaggeredEntrance(
                    order: 1,
                    child: Text(
                      'All set, $displayName!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: SoftPop.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const StaggeredEntrance(
                    order: 2,
                    child: Text(
                      'Your account is ready for your spaces and everyday moments.',
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
                    child: FilledButton(
                      onPressed: widget.onOpenApp,
                      style: FilledButton.styleFrom(
                        backgroundColor: SoftPop.blue,
                        foregroundColor: SoftPop.surface,
                        minimumSize: const Size(48, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Open Stewardie',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!reduceMotion)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConfettiPainter(progress: _confettiController.value),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiParticle {
  _ConfettiParticle({
    required this.xRatio,
    required this.speed,
    required this.size,
    required this.color,
    required this.spinSpeed,
  });

  final double xRatio;
  final double speed;
  final double size;
  final Color color;
  final double spinSpeed;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  static final List<_ConfettiParticle> _particles = List.generate(24, (i) {
    final colors = [
      SoftPop.blue,
      SoftPop.butter,
      SoftPop.rose,
      SoftPop.sky,
      const Color(0xFF67B28B),
    ];
    final rand = math.Random(i * 37);
    return _ConfettiParticle(
      xRatio: 0.1 + (rand.nextDouble() * 0.8),
      speed: 0.6 + (rand.nextDouble() * 0.8),
      size: 5.0 + (rand.nextDouble() * 4.0),
      color: colors[i % colors.length],
      spinSpeed: 2.0 + (rand.nextDouble() * 4.0),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in _particles) {
      final y = progress * size.height * p.speed;
      final x = p.xRatio * size.width +
          math.sin(progress * 4.0 * math.pi + p.xRatio * 10) * 16.0;

      final alpha = (1.0 - progress).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: alpha * 0.85);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.spinSpeed * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.7,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
