import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_state.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../timeline/data/demo_repository.dart';
import '../timeline/domain/models.dart';

class SpaceScreen extends ConsumerWidget {
  const SpaceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoProvider);
    final repo = ref.read(repositoryProvider);
    final space = repo.spaces.firstWhere((space) => space.id == state.spaceId);
    return PageBody(
      children: [
        const DemoNotice(),
        Text(
          'Our little corner',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text('${space.kind} · ${space.members.length} demo members'),
        const SizedBox(height: 24),
        Paper(
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
                    member.id == 'me'
                        ? 'Your fixed demo identity · Basic'
                        : 'Sample member',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    final checkIn = repo.checkIn(space.id, member.id);
                    showFeatureNote(
                      context,
                      member.name,
                      '${space.name}\n\n${checkIn == null ? 'No current check-in.' : '${checkIn.mood.label} · ${checkIn.note}\nShared today; expires at day’s end.'}\n\nThis is a sample member profile. No real account is connected.',
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'A foundation for shared days',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Invitations, routines, notification preferences, photos, and location sharing will follow the online foundation. No real members can join this demo.',
        ),
        const SizedBox(height: 24),
        Paper(
          color: SoftPop.blueSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Try the demo states',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'The next task action pauses briefly. You can also simulate failure, or let Alex claim an unclaimed task first.',
              ),
              const SizedBox(height: 16),
              if (repo is DemoRepository)
                DropdownButtonFormField<DemoOutcome>(
                  key: ValueKey('${state.revision}-${repo.nextOutcome}'),
                  initialValue: repo.nextOutcome,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Next task action',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: DemoOutcome.success,
                      child: Text('Local success'),
                    ),
                    DropdownMenuItem(
                      value: DemoOutcome.failure,
                      child: Text('Simulated failure'),
                    ),
                    DropdownMenuItem(
                      value: DemoOutcome.conflict,
                      child: Text('Claim conflict'),
                    ),
                  ],
                  onChanged: (value) {
                    repo.nextOutcome = value!;
                    ref.read(demoProvider.notifier).refresh();
                  },
                ),
              const SizedBox(height: 12),
              const Text(
                'For a conflict, open “Take out the recycling” and tap “I’ve got it”. These are simulations, not network tests.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Basic keeps unfinished tasks and shared completion available. Plus will belong to an individual account; it will not upgrade other members or grant permissions. Payments are not connected.',
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
        .firstWhere((space) => space.id == state.spaceId);
    return PageBody(
      children: [
        const DemoNotice(),
        Text(
          'Little moments',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text('The good bits from ${space.name}.'),
        const SizedBox(height: 32),
        Paper(
          color: SoftPop.warm,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: SoftPop.sky,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.camera_alt_outlined, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Room for the good bits',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'A meal made together. A tiny victory. A moment worth keeping.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Preview only · Photo sharing is not connected yet.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
