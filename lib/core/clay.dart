import 'package:flutter/material.dart';

import 'theme.dart';

/// Borderless secondary action with the shared shallow clay shadow.
class ClayAction extends StatelessWidget {
  const ClayAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = SoftPop.lightButter,
  });
  final Widget icon;
  final Widget label;
  final VoidCallback? onPressed;
  final Color color;
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onPressed,
    icon: icon,
    label: label,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: SoftPop.ink,
      shadowColor: SoftPop.ink.withValues(alpha: .14),
      elevation: 2,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: const StadiumBorder(),
      side: BorderSide.none,
    ),
  );
}

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

/// Choose a consistent illustration for a space's persisted type.
class SpaceMascotArt extends StatelessWidget {
  const SpaceMascotArt(this.kind, {super.key, this.height = 100, this.width});

  final String? kind;
  final double height;
  final double? width;

  String get _asset => switch (kind) {
    'family' => 'mascot-family-cutout.png',
    'friends' => 'mascot-friends-cutout.png',
    'organization' => 'mascot-organization-cutout.png',
    'couple' => 'mascot-couple.png',
    _ => 'mascot-other.png',
  };

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/illustrations/$_asset',
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
