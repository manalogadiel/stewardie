import 'package:flutter/material.dart';

import '../features/timeline/domain/models.dart';

String compactMemberName(Member member) {
  final preferred = member.preferredName?.trim();
  if (preferred != null && preferred.isNotEmpty) return preferred;
  return member.name.trim().split(RegExp(r'\s+')).first;
}

String calendarTitle(Space space, String? personId) => personId == null
    ? 'Shared calendar'
    : personId == 'me'
    ? 'Your calendar'
    : '${compactMemberName(space.member(personId))}’s calendar';

String calendarScope(Space space, String? personId) => personId == null
    ? 'Everyone’s plans'
    : personId == 'me'
    ? 'Your plans'
    : '${compactMemberName(space.member(personId))}’s plans';

/// Keeps the noun visible even when a long given name needs ellipsis.
class CompactPersonTitle extends StatelessWidget {
  const CompactPersonTitle({
    super.key,
    required this.space,
    required this.personId,
    required this.noun,
    this.style,
  });
  final Space space;
  final String? personId;
  final String noun;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final member = personId == null || personId == 'me'
        ? null
        : space.member(personId!);
    final own = noun == 'calendar' ? 'Your calendar' : 'Your mood';
    final everyone = noun == 'calendar' ? 'Shared calendar' : own;
    if (member == null) {
      return Text(
        personId == null ? everyone : own,
        style: style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Semantics(
      label: '${member.name}’s $noun',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '${compactMemberName(member)}’s',
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(' $noun', style: style, maxLines: 1),
          ],
        ),
      ),
    );
  }
}
