import 'package:flutter/material.dart';

import '../core/member_avatar.dart';
import '../core/theme.dart';

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
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MemberAvatar(uid: uid, name: name, radius: 19, selected: selected),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isMe ? SoftPop.blue : SoftPop.ink,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.3,
              fontFamily: 'NunitoSans',
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}
