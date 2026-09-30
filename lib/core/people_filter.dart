import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_state.dart';
import 'widgets.dart';
import 'theme.dart';
import '../features/timeline/domain/models.dart';
import 'person_labels.dart';

class PeopleFilter extends ConsumerWidget {
  const PeopleFilter(this.space, {super.key});
  final Space space;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(demoProvider.select((state) => state.personId));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final id in <String?>[null, ...space.members.map((m) => m.id)])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: id == selected,
                showCheckmark: false,
                side: BorderSide.none,
                selectedColor: SoftPop.lightButter,
                elevation: id == selected ? 2 : 0,
                avatar: id == null
                    ? null
                    : MemberAvatar(space.member(id), size: 26),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Tooltip(
                    message: id == null
                        ? 'Everyone'
                        : id == space.currentUserId
                        ? space.member(id).name
                        : space.member(id).name,
                    child: Text(
                      id == null
                          ? 'Everyone'
                          : id == space.currentUserId
                          ? 'Me'
                          : compactMemberName(space.member(id)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel: id == null
                          ? 'Everyone'
                          : space.member(id).name,
                    ),
                  ),
                ),
                onSelected: (_) =>
                    ref.read(demoProvider.notifier).selectPerson(id),
              ),
            ),
        ],
      ),
    );
  }
}
