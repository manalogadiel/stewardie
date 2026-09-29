import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/soft_pop_backdrop.dart';

/// Static front-facing clay artwork: no GIF decoder or idle timer.
class LoginScene extends StatelessWidget {
  const LoginScene({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: MediaQuery.viewInsetsOf(context).bottom > 0 ? 112 : 196,
      child: Image.asset(
        'assets/illustrations/login-sky-front.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}

class LoginHeadline extends StatelessWidget {
  const LoginHeadline({super.key});

  @override
  Widget build(BuildContext context) => const Text.rich(
    TextSpan(
      children: [
        TextSpan(text: 'A little more\n'),
        TextSpan(
          text: 'together',
          style: TextStyle(color: SoftPop.blue),
        ),
      ],
    ),
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: 'Fredoka',
      fontSize: 34,
      fontWeight: FontWeight.w500,
      height: 1.08,
      color: SoftPop.ink,
      letterSpacing: -.4,
    ),
  );
}

/// Decoration never intercepts form taps or enters the accessibility tree.
class LoginBackdrop extends StatelessWidget {
  const LoginBackdrop({super.key, required this.child, this.variant = 0});

  final Widget child;
  final int variant;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);

    // Varied subtle peripheral silhouettes across screens (away from headings & controls):
    final List<
      (
        String asset,
        Alignment alignment,
        Offset offset,
        double angle,
        double opacity,
      )
    >
    decorations;
    switch (variant % 3) {
      case 1:
        decorations = const [
          (
            'assets/illustrations/login-sky-front.png',
            Alignment.topRight,
            Offset(60, -30),
            0.12,
            0.06,
          ),
          (
            'assets/illustrations/onboarding-mint-calendar.png',
            Alignment.bottomLeft,
            Offset(-50, 40),
            -0.10,
            0.05,
          ),
        ];
        break;
      case 2:
        decorations = const [
          (
            'assets/illustrations/onboarding-make-it-yours.png',
            Alignment.topLeft,
            Offset(-45, -20),
            -0.12,
            0.06,
          ),
          (
            'assets/illustrations/onboarding-butter-task.png',
            Alignment.bottomRight,
            Offset(55, 30),
            0.08,
            0.05,
          ),
        ];
        break;
      case 0:
      default:
        decorations = const [
          (
            'assets/illustrations/onboarding-butter-welcome.png',
            Alignment.topLeft,
            Offset(-50, -20),
            -0.14,
            0.06,
          ),
          (
            'assets/illustrations/onboarding-rose-camera.png',
            Alignment.bottomRight,
            Offset(60, 40),
            0.12,
            0.05,
          ),
        ];
        break;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF0F5FA), Color(0xFFFAF9F6), Color(0xFFFFF5E7)],
            ),
          ),
        ),
        const SoftPopBackdrop(),
        if (!highContrast) ...[
          const Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: CustomPaint(painter: _SoftWavyLinesPainter()),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Stack(
                  children: [
                    for (final dec in decorations)
                      Align(
                        alignment: dec.$2,
                        child: Transform.translate(
                          offset: dec.$3,
                          child: Transform.rotate(
                            angle: dec.$4,
                            child: Opacity(
                              opacity: dec.$5,
                              child: Image.asset(
                                dec.$1,
                                width: 220,
                                height: 220,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        child,
      ],
    );
  }
}

class _SoftWavyLinesPainter extends CustomPainter {
  const _SoftWavyLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Upper soft ribbon (pale sky tint)
    final skyPaint = Paint()
      ..color = const Color(0xFF6BAED6).withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round;

    final path1 = Path();
    path1.moveTo(size.width * 0.40, -20);
    path1.cubicTo(
      size.width * 0.65,
      size.height * 0.10,
      size.width * 0.85,
      size.height * 0.06,
      size.width + 40,
      size.height * 0.24,
    );
    canvas.drawPath(path1, skyPaint);

    // Lower soft ribbon (warm butter/rose tint)
    final warmPaint = Paint()
      ..color = const Color(0xFFF3C77C).withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round;

    final path2 = Path();
    path2.moveTo(-30, size.height * 0.74);
    path2.cubicTo(
      size.width * 0.25,
      size.height * 0.80,
      size.width * 0.40,
      size.height * 0.90,
      size.width * 0.65,
      size.height + 30,
    );
    canvas.drawPath(path2, warmPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
