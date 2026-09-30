import 'features/onboarding/tutorial/tutorial_target_registry.dart';
import 'features/onboarding/tutorial/tutorial_entry_gate.dart';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/backend_provider.dart';
import 'core/demo_state.dart';
import 'core/theme.dart';
import 'core/soft_pop_backdrop.dart';
import 'features/spaces/space_screen.dart';
import 'features/moments/moments_screen.dart';
import 'features/timeline/domain/models.dart';
import 'features/timeline/presentation/task_detail.dart';
import 'features/timeline/presentation/today_screen.dart';
import 'online/space_map_sheet.dart';
import 'online/live_location_pill.dart';
import 'online/activity_inbox_sheet.dart';
import 'online/online_home.dart';
import 'online/qr_join_sheet.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/today',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/today', builder: (_, _) => const TodayScreen()),
          GoRoute(path: '/moments', builder: (_, _) => const MomentsScreen()),
          GoRoute(path: '/space', builder: (_, _) => const SpaceScreen()),
        ],
      ),
      GoRoute(
        path: '/task/:id',
        builder: (_, state) => TaskDetail(taskId: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class StewardieApp extends ConsumerWidget {
  const StewardieApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Stewardie',
    debugShowCheckedModeBanner: false,
    theme: SoftPop.theme,
    routerConfig: ref.watch(routerProvider),
  );
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoProvider), repo = ref.read(repositoryProvider);
    final availableSpaces = repo.spaces;
    final space =
        availableSpaces.where((s) => s.id == state.spaceId).firstOrNull ??
        availableSpaces.firstOrNull;
    if (space == null) {
      return const Scaffold(
        body: Center(child: Text('Your spaces are loading…')),
      );
    }
    if (space.id != state.spaceId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(demoProvider.notifier).switchSpace(space.id);
        }
      });
    }
    final index = path == '/moments'
        ? 1
        : path == '/space'
        ? 2
        : 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: SoftPop.canvas,
      ),
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            const Positioned.fill(child: SoftPopBackdrop()),
            Positioned.fill(
              child: SafeArea(top: false, bottom: false, child: child),
            ),
            Positioned.fill(
              child: TutorialEntryGate(
                onTabRequested: (tab) =>
                    context.go(['/today', '/moments', '/space'][tab]),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final backend = ref.watch(sharedBackendProvider);
                          if (backend != null) {
                            return SizedBox(
                              width: 48,
                              child: IconButton(
                                key: TutorialTargetRegistry.mapButtonTarget,
                                tooltip: 'Space map',
                                style: IconButton.styleFrom(
                                  backgroundColor: SoftPop.surface,
                                  shape: const CircleBorder(),
                                ),
                                onPressed: () => SpaceMapSheet.show(
                                  context,
                                  backend: backend,
                                  spaceId: space.id,
                                ),
                                icon: const Icon(
                                  Icons.map_outlined,
                                  color: SoftPop.ink,
                                  size: 22,
                                ),
                              ),
                            );
                          }
                          return const SizedBox(width: 48);
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: TextButton(
                            key: TutorialTargetRegistry.spaceSelectorTarget,
                            style: TextButton.styleFrom(
                              backgroundColor: SoftPop.surface,
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              useRootNavigator: true,
                              useSafeArea: true,
                              builder: (sheet) => SafeArea(
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    20,
                                  ),
                                  children: [
                                    Text(
                                      'Your spaces',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 12),
                                    for (final choice in repo.spaces)
                                      ListTile(
                                        title: Text(choice.name),
                                        subtitle: Text(choice.kind),
                                        trailing: choice.id == space.id
                                            ? const Icon(
                                                Icons
                                                    .radio_button_checked_rounded,
                                                color: SoftPop.blue,
                                              )
                                            : const Icon(
                                                Icons
                                                    .radio_button_unchecked_rounded,
                                                color: SoftPop.secondary,
                                              ),
                                        selected: choice.id == space.id,
                                        onTap: () {
                                          Navigator.pop(sheet);
                                          ref
                                              .read(demoProvider.notifier)
                                              .switchSpace(choice.id);
                                        },
                                      ),
                                    if (ref.read(sharedBackendProvider)
                                        case final backend?) ...[
                                      const Divider(),
                                      ListTile(
                                        leading: const Icon(Icons.add_rounded),
                                        title: const Text('Create a space'),
                                        enabled:
                                            repo.isPlus ||
                                            repo.spaces.length < 3,
                                        subtitle:
                                            !repo.isPlus &&
                                                repo.spaces.length >= 3
                                            ? const Text(
                                                '3 of 3 spaces · Basic limit',
                                              )
                                            : null,
                                        onTap: () async {
                                          Navigator.pop(sheet);
                                          try {
                                            final id =
                                                await OnlineHome.createSpace(
                                                  context,
                                                  backend,
                                                );
                                            if (!context.mounted ||
                                                id == null) {
                                              return;
                                            }
                                            ref
                                                .read(demoProvider.notifier)
                                                .switchSpace(id);
                                          } catch (_) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Could not create the space. Check your connection and try again.',
                                                      ),
                                                    ),
                                                  );
                                            }
                                          }
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.group_add_outlined,
                                        ),
                                        title: const Text('Join with a code'),
                                        enabled:
                                            repo.isPlus ||
                                            repo.spaces.length < 3,
                                        onTap: () {
                                          Navigator.pop(sheet);
                                          QrJoinSheet.show(
                                            context,
                                            backend: backend,
                                            onJoined: (id) {
                                              if (!context.mounted) return;
                                              ref
                                                  .read(demoProvider.notifier)
                                                  .switchSpace(id);
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    space.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                const Icon(
                                  Icons.expand_more_rounded,
                                  color: SoftPop.ink,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: SoftPop.surface,
                            shape: const CircleBorder(),
                          ),
                          key: TutorialTargetRegistry.notificationBellTarget,
                          tooltip: 'Inbox',
                          icon: const Icon(Icons.notifications_none_rounded),
                          onPressed: () {
                            final requests = state.tasks
                                .where(
                                  (t) =>
                                      t.spaceId == space.id &&
                                      ((t.requestedId == repo.currentUserId &&
                                              t.status ==
                                                  Responsibility.requested) ||
                                          (t.ownerId == repo.currentUserId &&
                                              t.offeredId != null)),
                                )
                                .toList();
                            final backend = ref.read(sharedBackendProvider);
                            if (backend == null) {
                              showModalBottomSheet<void>(
                                context: context,
                                builder: (_) => ListView(
                                  shrinkWrap: true,
                                  children: [
                                    const ListTile(title: Text('Inbox')),
                                    if (requests.isEmpty)
                                      const ListTile(
                                        title: Text('You’re all caught up.'),
                                      ),
                                    for (final task in requests)
                                      ListTile(title: Text(task.title)),
                                  ],
                                ),
                              );
                              return;
                            }
                            ActivityInboxSheet.show(
                              context,
                              backend: backend,
                              spaceNames: {space.id: space.name},
                              requests: [
                                for (final task in requests)
                                  ListTile(
                                    title: Text(task.title),
                                    subtitle: Text(
                                      task.offeredId == null
                                          ? 'Awaiting your acceptance'
                                          : 'Review a handoff offer',
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      context.push('/task/${task.id}');
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (MediaQuery.viewInsetsOf(context).bottom > 0)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: LiveLocationPill(),
              ),
          ],
        ),
        bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.textScalerOf(context).scale(14) > 20 ? 8 : 20,
                    8,
                    MediaQuery.textScalerOf(context).scale(14) > 20 ? 8 : 20,
                    12,
                  ),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.textScalerOf(context).scale(14) > 20
                            ? 440
                            : 360,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const LiveLocationPill(),
                          GlassDock(index: index),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class GlassDock extends StatelessWidget {
  const GlassDock({super.key, required this.index, this.onSelected});
  final int index;
  final ValueChanged<int>? onSelected;
  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    // Reserve each label's bold width even when it is not selected, so
    // changing destinations never makes an enlarged label wrap or jump.
    final labelWidths = ['Today', 'Moments', 'Space'].map((label) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = (painter.width + 6).ceil();
      painter.dispose();
      return width;
    }).toList();
    final opaque =
        MediaQuery.highContrastOf(context) ||
        MediaQuery.accessibleNavigationOf(context) ||
        const bool.fromEnvironment('REDUCE_TRANSPARENCY');
    final contents = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: opaque ? 1 : .92),
            const Color(0xFFF0EFEA).withValues(alpha: opaque ? 1 : .86),
          ],
        ),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                flex: largeText ? labelWidths[i] : 1,
                child: Semantics(
                  selected: i == index,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (onSelected != null) {
                          onSelected!(i);
                        } else {
                          context.go(['/today', '/moments', '/space'][i]);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: largeText ? 2 : 4,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: i == index ? SoftPop.blueSoft : null,
                          borderRadius: BorderRadius.circular(28),
                          border: i == index
                              ? Border.all(color: Colors.white)
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              [
                                Icons.today_rounded,
                                Icons.photo_library_outlined,
                                Icons.people_outline_rounded,
                              ][i],
                              color: i == index
                                  ? SoftPop.blue
                                  : SoftPop.secondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ['Today', 'Moments', 'Space'][i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: i == index
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: i == index
                                    ? SoftPop.blue
                                    : SoftPop.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18202633),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: opaque
            ? contents
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: contents,
              ),
      ),
    );
  }
}
