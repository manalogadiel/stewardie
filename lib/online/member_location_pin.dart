import 'package:flutter/material.dart';

import '../core/member_avatar.dart';
import '../core/theme.dart';

/// Only a member's own private fix can replace an absent sharing session.
Map<String, dynamic>? resolveSelectedMemberLocation({
  required String? selectedUid,
  required String? currentUid,
  required List<Map<String, dynamic>> sessions,
  Map<String, dynamic>? personalLocation,
}) {
  if (selectedUid == null) return null;
  for (final session in sessions) {
    if (session['uid'] == selectedUid) return session;
  }
  return selectedUid == currentUid ? personalLocation : null;
}

/// Bounds include the selection ring and the user's scaled label.
class MemberLocationPin extends StatelessWidget {
  const MemberLocationPin({
    super.key,
    required this.uid,
    required this.name,
    required this.label,
    required this.selected,
    required this.isMe,
  });
  final String uid, name, label;
  final bool selected, isMe;

  static Size sizeFor(BuildContext context) =>
      Size(96, 56 + MediaQuery.textScalerOf(context).scale(11) * 1.5);

  @override
  Widget build(BuildContext context) => Semantics(
    label: name,
    selected: selected,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: selected ? SoftPop.lightButter : SoftPop.surface,
          borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: SoftPop.ink.withValues(alpha: .18), blurRadius: 6, offset: const Offset(0, 3))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          MemberAvatar(uid: uid, name: name, radius: 16),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w700, color: SoftPop.ink)),
        ])),
      CustomPaint(size: const Size(12, 7), painter: _PinTip(selected ? SoftPop.lightButter : SoftPop.surface)),
    ]),
  );
}
class _PinTip extends CustomPainter {
  const _PinTip(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(Path()..moveTo(0, 0)..lineTo(size.width / 2, size.height)..lineTo(size.width, 0)..close(), Paint()..color = color);
  @override
  bool shouldRepaint(_PinTip old) => color != old.color;
}
