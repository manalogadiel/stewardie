import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clay.dart';
import '../../core/demo_state.dart';
import '../../core/top_controls.dart';
import '../../core/widgets.dart';
import '../../core/backend_provider.dart';
import '../../core/theme.dart';
import '../../online/online_home.dart';
import '../subscription/soft_pop_paywall.dart';
import '../timeline/domain/models.dart';

class SpaceScreen extends ConsumerWidget {
  const SpaceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoProvider), repo = ref.read(repositoryProvider);
    final backend = ref.watch(sharedBackendProvider);
    if (backend != null && backend.auth.currentUser != null) {
      return OnlineHome(
        backend: backend,
        user: backend.auth.currentUser!,
        spaceOnly: true,
        spaceId: state.spaceId,
        onSpaceSelected: (id) {
          if (id != null) {
            ref.read(demoProvider.notifier).switchSpace(id);
            context.go('/today');
          }
        },
      );
    }
    final space = repo.spaces.where((s) => s.id == state.spaceId).firstOrNull ??
        repo.spaces.firstOrNull;
    if (space == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PageBody(
      padding: EdgeInsets.fromLTRB(20, topControlsClearance(context), 20, 150),
      children: [
        const ClayArt('greeting', height: 140),
        Text(
          'Space',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: SoftPop.ink.withValues(alpha: .75),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          space.name,
          style: Theme.of(context).textTheme.headlineLarge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
                    member.id == repo.currentUserId
                        ? 'Your account · ${repo.isPlus ? 'Plus' : 'Basic'}'
                        : 'Member',
                  ),
                  trailing: member.id == repo.currentUserId && !repo.isPlus
                      ? FilledButton.tonal(
                          onPressed: () => showSoftPopPaywall(
                            context,
                            onPurchased: () => ref.read(demoProvider.notifier).refresh(),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: SoftPop.blueSoft,
                            foregroundColor: SoftPop.blue,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Upgrade'),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    if (member.id == repo.currentUserId) {
                      showSoftPopPaywall(
                        context,
                        onPurchased: () => ref.read(demoProvider.notifier).refresh(),
                      );
                      return;
                    }
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
