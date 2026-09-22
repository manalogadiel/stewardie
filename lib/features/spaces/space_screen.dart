import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clay.dart';
import '../../core/demo_state.dart';
import '../../core/widgets.dart';
import '../timeline/domain/models.dart';

class SpaceScreen extends ConsumerWidget {
  const SpaceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoProvider), repo = ref.read(repositoryProvider);
    final space = repo.spaces.firstWhere((s) => s.id == state.spaceId);
    return PageBody(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
      children: [
        const ClayArt('greeting', height: 140),
        Text(
          'Our little corner',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text('${space.kind} · ${space.members.length} members'),
        const SizedBox(height: 24),
        ClayPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your people',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final member in space.members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: MemberAvatar(member, size: 40),
                  title: Text(member.name),
                  subtitle: Text(
                    member.id == 'me' ? 'Your account · Basic' : 'Member',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    final mood = repo.checkIn(space.id, member.id);
                    showFeatureNote(
                      context,
                      member.name,
                      '${space.name}\n\n${mood == null ? 'No current check-in.' : '${mood.mood.label} · ${mood.note}\nUntil the end of today.'}',
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class MomentsScreen extends ConsumerWidget {
  const MomentsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoProvider);
    final space = ref
        .read(repositoryProvider)
        .spaces
        .firstWhere((s) => s.id == state.spaceId);
    return PageBody(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
      children: [
        Text(
          'Little moments',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text('The good bits from ${space.name}.'),
        const SizedBox(height: 32),
        ClayPanel(
          child: Column(
            children: [
              const ClayArt('celebrate', height: 180),
              const SizedBox(height: 20),
              Text(
                'Room for the good bits',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'A meal made together. A tiny victory. A moment worth keeping.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
