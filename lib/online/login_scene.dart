import 'package:flutter/material.dart';

import '../core/theme.dart';

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
  const LoginBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
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
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: MediaQuery.highContrastOf(context) ? 0 : .085,
              child: Stack(
                children: [
                  Positioned(
                    left: -80,
                    top: 48,
                    child: _decoration('login-butter-welcome.jpg', -.18),
                  ),
                  Positioned(
                    right: -90,
                    bottom: 36,
                    child: _decoration('login-rose-peekaboo.jpg', .16),
                  ),
                  const Positioned(
                    right: 28,
                    top: 76,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 46,
                      color: SoftPop.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      child,
    ],
  );

  Widget _decoration(String asset, double angle) => Transform.rotate(
    angle: angle,
    child: ClipOval(
      child: Image.asset(
        'assets/illustrations/$asset',
        width: 240,
        height: 240,
        fit: BoxFit.cover,
      ),
    ),
  );
}
