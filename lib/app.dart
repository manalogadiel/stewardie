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
    title: 'Stewardie · Local demo',
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
    final state = ref.watch(demoProvider);
    final spaces = ref.read(repositoryProvider).spaces;
    final space = spaces.firstWhere((space) => space.id == state.spaceId);
    final index = path == '/moments'
        ? 1
        : path == '/space'
        ? 2
        : 0;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Semantics(
          label: 'Switch space',
          child: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              useRootNavigator: true,
              context: context,
              useSafeArea: true,
              builder: (sheetContext) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your spaces',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      for (final choice in spaces)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(choice.name),
                          subtitle: Text('${choice.kind} · Demo'),
                          trailing: choice.id == space.id
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: SoftPop.blue,
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            ref
                                .read(demoProvider.notifier)
                                .switchSpace(choice.id);
                            context.go('/today');
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SoftPop.butter,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.cottage_outlined,
                    size: 23,
                    color: SoftPop.ink,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    space.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded, color: SoftPop.ink),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Inbox',
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () {
              final requests = state.tasks
                  .where(
                    (task) =>
                        task.spaceId == space.id &&
                        ((task.status == Responsibility.requested &&
                                task.requestedId == 'me') ||
                            (task.ownerId == 'me' && task.offeredId != null)),
                  )
                  .toList();
              showModalBottomSheet<void>(
                useRootNavigator: true,
                context: context,
                useSafeArea: true,
                builder: (sheetContext) => SafeArea(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'Inbox · ${space.name}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      const Text('Local demo requests'),
                      if (requests.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('You’re all caught up.'),
                        ),
                      for (final task in requests)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(task.title),
                          subtitle: Text(
                            task.offeredId == null
                                ? 'Awaiting your acceptance'
                                : 'Review a handoff offer',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            context.push('/task/${task.id}');
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(top: false, bottom: false, child: child),
      floatingActionButton: index == 0
          ? FloatingActionButton.extended(
              elevation: 0,
              highlightElevation: 0,
              onPressed: () => showAddTask(context, space),
              backgroundColor: SoftPop.blue,
              foregroundColor: SoftPop.surface,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add task'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            context.go(['/today', '/moments', '/space'][value]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded, color: SoftPop.blue),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(
              Icons.photo_library_rounded,
              color: SoftPop.blue,
            ),
            label: 'Moments',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: SoftPop.blue),
            label: 'Space',
          ),
        ],
      ),
    );
  }
}
