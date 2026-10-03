import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng;

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
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? SoftPop.lightButter : SoftPop.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: SoftPop.ink.withValues(alpha: .18),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MemberAvatar(uid: uid, name: name, radius: 16),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: SoftPop.ink,
                ),
              ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(12, 7),
          painter: _PinTip(selected ? SoftPop.lightButter : SoftPop.surface),
        ),
      ],
    ),
  );
}

class _PinTip extends CustomPainter {
  const _PinTip(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close(),
    Paint()..color = color,
  );
  @override
  bool shouldRepaint(_PinTip old) => color != old.color;
}

/// Nearby fixes share one holder. Coordinates remain a real member's fix.
List<List<Map<String, dynamic>>> groupMemberLocations(
  List<Map<String, dynamic>> sessions, {
  double distanceMeters = 20,
}) {
  const distance = Distance();
  final groups = <List<Map<String, dynamic>>>[];
  for (final session in sessions) {
    final lat = session['lat'], lng = session['lng'];
    if (lat is! num ||
        lng is! num ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      continue;
    }
    final point = LatLng(lat.toDouble(), lng.toDouble());
    List<Map<String, dynamic>>? target;
    for (final group in groups) {
      final first = group.first;
      if (distance(
            point,
            LatLng(
              (first['lat'] as num).toDouble(),
              (first['lng'] as num).toDouble(),
            ),
          ) <=
          distanceMeters) {
        target = group;
        break;
      }
    }
    (target ?? (groups..add(<Map<String, dynamic>>[])).last).add(session);
  }
  return groups;
}

class GroupMemberLocationPin extends StatelessWidget {
  const GroupMemberLocationPin({
    super.key,
    required this.members,
    required this.currentUid,
    required this.onSelected,
    this.selectedUid,
  });
  final List<Map<String, dynamic>> members;
  final String? currentUid, selectedUid;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: SoftPop.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: SoftPop.ink.withValues(alpha: .18),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (final member in members)
              Semantics(
                button: true,
                selected: selectedUid == member['uid'],
                label: member['name'] as String? ?? 'Member',
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelected(member),
                  child: Container(
                    width: 66,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: selectedUid == member['uid']
                          ? SoftPop.lightButter
                          : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MemberAvatar(
                          uid: member['uid'] as String? ?? '',
                          name: member['name'] as String? ?? 'Member',
                          radius: 16,
                        ),
                        Text(
                          member['uid'] == currentUid
                              ? 'You'
                              : member['name'] as String? ?? 'Member',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: SoftPop.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      CustomPaint(size: const Size(12, 7), painter: _PinTip(SoftPop.surface)),
    ],
  );
}
