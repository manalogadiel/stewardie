import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/demo_state.dart';
import 'core/theme.dart';
import 'features/spaces/space_screen.dart';
import 'features/timeline/domain/models.dart';
import 'features/timeline/presentation/task_detail.dart';
import 'features/timeline/presentation/today_screen.dart';

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
    final space = repo.spaces.firstWhere((s) => s.id == state.spaceId);
    final index = path == '/moments'
        ? 1
        : path == '/space'
        ? 2
        : 0;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 72,
        leading: const SizedBox(width: 48),
        leadingWidth: 48,
        titleSpacing: 0,
        title: TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            useSafeArea: true,
            builder: (sheet) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Text(
                    'Your spaces',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final choice in repo.spaces)
                    ListTile(
                      title: Text(choice.name),
                      subtitle: Text(choice.kind),
                      trailing: choice.id == space.id
                          ? const Icon(Icons.check_rounded, color: SoftPop.blue)
                          : null,
                      onTap: () {
                        Navigator.pop(sheet);
                        ref.read(demoProvider.notifier).switchSpace(choice.id);
                        context.go('/today');
                      },
                    ),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: SoftPop.ink),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Inbox',
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () {
              final requests = state.tasks
                  .where(
                    (t) =>
                        t.spaceId == space.id &&
                        ((t.requestedId == 'me' &&
                                t.status == Responsibility.requested) ||
                            (t.ownerId == 'me' && t.offeredId != null)),
                  )
                  .toList();
              showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                useSafeArea: true,
                builder: (sheet) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      Text(
                        'Inbox · ${space.name}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (requests.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('You’re all caught up.'),
                        ),
                      for (final task in requests)
                        ListTile(
                          title: Text(task.title),
                          subtitle: Text(
                            task.offeredId == null
                                ? 'Awaiting your acceptance'
                                : 'Review a handoff offer',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.pop(sheet);
                            context.push('/task/${task.id}');
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(top: false, bottom: false, child: child),
      bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.textScalerOf(context).scale(14) > 20 ? 12 : 20,
                  8,
                  MediaQuery.textScalerOf(context).scale(14) > 20 ? 12 : 20,
                  12,
                ),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: GlassDock(index: index),
                  ),
                ),
              ),
            ),
    );
  }
}

class GlassDock extends StatelessWidget {
  const GlassDock({super.key, required this.index});
  final int index;
  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
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
            for (var i = 0; i < 3; i++)
              Expanded(
                flex: largeText && i == 1 ? 4 : 3,
                child: Semantics(
                  selected: i == index,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () =>
                          context.go(['/today', '/moments', '/space'][i]),
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
