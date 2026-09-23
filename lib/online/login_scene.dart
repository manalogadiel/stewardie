import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/clay.dart';
import '../core/theme.dart';

class LoginScene extends StatelessWidget {
  const LoginScene({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            bottom: 8,
            child: Transform.rotate(
              angle: -.14,
              child: const ClayArt('calendar', width: 84, height: 88),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 4,
            child: Transform.rotate(
              angle: .12,
              child: const ClayArt('celebrate', width: 88, height: 94),
            ),
          ),
          const Positioned(
            left: 20,
            top: 14,
            child: _FlatFriend(color: SoftPop.butter, reading: true),
          ),
          const Positioned(
            right: 20,
            top: 10,
            child: _FlatFriend(color: SoftPop.rose, reading: false),
          ),
          Image.asset(
            MediaQuery.disableAnimationsOf(context)
                ? 'assets/illustrations/welcome-wave.png'
                : 'assets/illustrations/welcome-wave.gif',
            width: 190,
            height: 190,
            gaplessPlayback: true,
          ),
        ],
      ),
    ),
  );
}

class _FlatFriend extends StatelessWidget {
  const _FlatFriend({required this.color, required this.reading});
  final Color color;
  final bool reading;
  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 50,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(21),
      border: Border.all(color: SoftPop.surface, width: 3),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('•‿•', style: TextStyle(fontSize: 13, color: SoftPop.ink)),
        Icon(
          reading ? Icons.menu_book_rounded : Icons.local_florist_rounded,
          size: 16,
          color: SoftPop.ink,
        ),
      ],
    ),
  );
}

/// Original vector artwork used to render the bundled waving GIF. Gradients
/// give the clay shape depth; no existing raster art is altered.
class WelcomeWavePainter extends CustomPainter {
  const WelcomeWavePainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 240, size.height / 240);
    final bounce = math.sin(progress * math.pi * 2) * 2;
    canvas.translate(0, bounce);
    canvas.drawOval(
      const Rect.fromLTWH(51, 209, 135, 13),
      Paint()
        ..color = const Color(0x18334656)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    void clay(Rect rect, {double radius = 45}) {
      final paint = Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.55, -.7),
          radius: 1.3,
          colors: [Color(0xFFD0EDFB), Color(0xFFA9D5EE), Color(0xFF669CBF)],
          stops: [0, .48, 1],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );
    }

    clay(const Rect.fromLTWH(51, 80, 30, 96));
    clay(const Rect.fromLTWH(65, 47, 115, 163), radius: 59);
    // A separate shoulder joint makes the hand wave rather than rotating the body.
    canvas.save();
    canvas.translate(167, 119);
    canvas.rotate(.35 + math.sin(progress * math.pi * 4) * .32);
    clay(const Rect.fromLTWH(-12, -80, 30, 86), radius: 18);
    canvas.restore();
    clay(const Rect.fromLTWH(69, 177, 50, 42), radius: 24);
    clay(const Rect.fromLTWH(126, 177, 50, 42), radius: 24);
    final face = Paint()
      ..color = SoftPop.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final x in [98.0, 139.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 6, 103)
          ..quadraticBezierTo(x, 93, x + 6, 103),
        face,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(111, 116)
        ..quadraticBezierTo(121, 128, 131, 116),
      face,
    );
    final cheek = Paint()..color = SoftPop.rose.withValues(alpha: .6);
    canvas.drawOval(const Rect.fromLTWH(85, 111, 13, 7), cheek);
    canvas.drawOval(const Rect.fromLTWH(143, 111, 13, 7), cheek);
    final sparkle = Paint()
      ..color = SoftPop.butter
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(37, 58), const Offset(37, 74), sparkle);
    canvas.drawLine(const Offset(29, 66), const Offset(45, 66), sparkle);
  }

  @override
  bool shouldRepaint(WelcomeWavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
