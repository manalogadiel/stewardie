import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend_provider.dart';
import 'tutorial_coordinator.dart';
import 'tutorial_state.dart';

/// Lives in the real member shell, which replaces the no-space home on joining.
class TutorialEntryGate extends ConsumerStatefulWidget {
  const TutorialEntryGate({super.key, required this.onTabRequested});
  final ValueChanged<int> onTabRequested;
  @override
  ConsumerState<TutorialEntryGate> createState() => _TutorialEntryGateState();
}

class _TutorialEntryGateState extends ConsumerState<TutorialEntryGate> {
  bool awaiting = false, busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final db = ref.read(tutorialDatabaseProvider);
      final uid = ref.read(sharedBackendProvider)?.auth.currentUser?.uid;
      if (db == null || uid == null || !mounted) return;
      await TutorialCoordinator(db).checkAndPromptTour(
        context,
        uid: uid,
        onTabRequested: (tab) => widget.onTabRequested(tab),
      );
      if (!mounted) return;
      final status = await TutorialStore(db).getStatus(uid);
      if (mounted)
        setState(() => awaiting = status == TutorialStatus.awaitingSpace);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!awaiting) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          145 + MediaQuery.paddingOf(context).bottom,
        ),
        child: FilledButton.icon(
          icon: const Icon(Icons.explore_outlined),
          label: const Text('Continue tour'),
          onPressed: busy
              ? null
              : () async {
                  final uid = ref
                      .read(sharedBackendProvider)
                      ?.auth
                      .currentUser
                      ?.uid;
                  if (uid == null) return;
                  setState(() {
                    busy = true;
                    awaiting = false;
                  });
                  await TutorialCoordinator(ref.read(tutorialDatabaseProvider))
                      .continueTour(
                        context,
                        uid: uid,
                        onTabRequested: (tab) => widget.onTabRequested(tab),
                      );
                  if (mounted) setState(() => busy = false);
                },
        ),
      ),
    );
  }
}
