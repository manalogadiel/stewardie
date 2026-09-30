import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend_provider.dart';
import 'tutorial_coordinator.dart';

/// Offers continuation after membership is ready, once per account session.
class TutorialEntryGate extends ConsumerStatefulWidget {
  const TutorialEntryGate({super.key, required this.onTabRequested});
  final ValueChanged<int> onTabRequested;
  @override
  ConsumerState<TutorialEntryGate> createState() => _TutorialEntryGateState();
}

class _TutorialEntryGateState extends ConsumerState<TutorialEntryGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final db = ref.read(tutorialDatabaseProvider);
      final backend = ref.read(sharedBackendProvider);
      final uid = backend?.auth.currentUser?.uid;
      if (db == null || uid == null) return;
      final coordinator = TutorialCoordinator(db, backend: backend);
      await coordinator.checkAndPromptTour(
        context,
        uid: uid,
        onTabRequested: widget.onTabRequested,
      );
      if (!mounted) return;
      await coordinator.offerContinuation(
        context,
        uid: uid,
        onTabRequested: widget.onTabRequested,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
