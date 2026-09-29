import 'package:flutter/material.dart';

import 'theme.dart';

/// Compact clay-shaped member plus glyph for the invite action tile.
class StewardieInviteIcon extends StatelessWidget {
  const StewardieInviteIcon({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 30,
    height: 30,
    child: CustomPaint(painter: _InvitePainter()),
  );
}

class _InvitePainter extends CustomPainter {
  const _InvitePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final clay = Paint()..color = SoftPop.rose;
    final ink = Paint()
      ..color = SoftPop.ink
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 4, 20, 23),
        const Radius.circular(11),
      ),
      clay,
    );
    canvas.drawCircle(const Offset(8, 13), 1.2, ink);
    canvas.drawCircle(const Offset(16, 13), 1.2, ink);
    canvas.drawArc(
      const Rect.fromLTWH(9, 13, 6, 5),
      0.1,
      2.9,
      false,
      Paint()
        ..color = SoftPop.ink
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(const Offset(25, 11), const Offset(25, 21), ink);
    canvas.drawLine(const Offset(20, 16), const Offset(30, 16), ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
