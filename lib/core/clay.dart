import 'package:flutter/material.dart';

import 'theme.dart';

class ClayArt extends StatelessWidget {
  const ClayArt(this.name, {super.key, this.height = 100, this.width});
  final String name;
  final double height;
  final double? width;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/illustrations/$name.png',
      height: height,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    ),
  );
}

class ClayPanel extends StatelessWidget {
  const ClayPanel({
    super.key,
    required this.child,
    this.color = SoftPop.surface,
    this.padding = const EdgeInsets.all(16),
    this.radius = const BorderRadius.all(Radius.circular(24)),
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final BorderRadius radius;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: radius,
      boxShadow: const [
        BoxShadow(
          color: Color(0x09202633),
          blurRadius: 20,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      color: color,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    ),
  );
}
