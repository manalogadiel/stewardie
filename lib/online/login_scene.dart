import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Rendered from one articulated 3D model. Every action shares its rest pose.
class LoginScene extends StatefulWidget {
  const LoginScene({super.key});
  @override
  State<LoginScene> createState() => _LoginSceneState();
}

class _LoginSceneState extends State<LoginScene> with WidgetsBindingObserver {
  static const _actions = ['wave', 'look', 'bounce', 'peek', 'stretch'];
  Timer? _timer;
  int _action = 0, _cycle = 0;
  bool _moving = false, _foreground = true, _enabled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _update();
  }

  void _update() {
    final enabled =
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
    if (enabled == _enabled) return;
    _enabled = enabled;
    _timer?.cancel();
    if (enabled) {
      _play();
    } else {
      setState(() => _moving = false);
    }
  }

  void _play() {
    if (!_enabled || !mounted) return;
    setState(() {
      _moving = true;
      _cycle++;
    });
    _timer = Timer(const Duration(milliseconds: 3360), () {
      if (!mounted) return;
      setState(() => _moving = false);
      _action = (_action + 1) % _actions.length;
      _timer = Timer(const Duration(milliseconds: 2200), _play);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 190,
      child: Center(
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          child: Image.asset(
            _moving
                ? 'assets/illustrations/login-3d-${_actions[_action]}.gif'
                : 'assets/illustrations/login-3d-still.png',
            key: ValueKey(_moving ? '${_actions[_action]}/$_cycle' : 'still'),
            width: 190,
            height: 190,
            fit: BoxFit.contain,
          ),
        ),
      ),
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
