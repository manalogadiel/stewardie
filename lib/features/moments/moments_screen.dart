import '../onboarding/tutorial/tutorial_target_registry.dart';

import 'dart:math' as math;
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'moments_loader.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clay.dart';
import '../../core/demo_state.dart';
import '../../core/people_filter.dart';
import '../../core/theme.dart';
import '../../online/safety_sheet.dart';
import '../../core/backend_provider.dart';
import '../../core/top_controls.dart';
import '../../core/widgets.dart';
import '../media/media_library.dart';
import '../media/photo_composer.dart';
import '../media/photo_viewer.dart';
import '../media/picker_recovery.dart';

class MomentsScreen extends ConsumerStatefulWidget {
  const MomentsScreen({super.key});
  @override
  ConsumerState<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends ConsumerState<MomentsScreen>
    with WidgetsBindingObserver {
  PageController pages = PageController();
  int index = 0;
  String scope = '';
  Timer? _refreshTimer;
  String? _cloudSpace;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _hiddenSub;
  Set<String> _hidden = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final backend = ref.read(sharedBackendProvider);
    if (backend != null && backend.auth.currentUser != null) {
      _hiddenSub = backend.firestore
          .collection('accounts')
          .doc(backend.auth.currentUser!.uid)
          .collection('hidden')
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              setState(() => _hidden = snapshot.docs.map((d) => d.id).toSet());
            }
          });
    }
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
          _cloudSpace != null) {
        unawaited(ref.read(mediaLibraryProvider).refresh(_cloudSpace!));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _cloudSpace != null) {
      unawaited(ref.read(mediaLibraryProvider).refresh(_cloudSpace!));
    }
  }

  Future<void> discardRecovery() async {
    try {
      await ref.read(recoveredPhotoProvider.notifier).dismiss();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not clear the recovered photo. Try again.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _hiddenSub?.cancel();
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(demoProvider);
    final repo = ref.read(repositoryProvider);
    final space = repo.spaces.firstWhere((s) => s.id == state.spaceId);
    final recovered = ref.watch(recoveredPhotoProvider);
    final posts =
        ref
            .watch(mediaProvider)
            .where(
              (p) =>
                  p.spaceId == space.id &&
                  !_hidden.contains('${space.id}_moment_${p.id}') &&
                  p.publishedAt != null &&
                  (state.personId == null || p.uploaderId == state.personId),
            )
            .toList()
          ..sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));
    final library = ref.read(mediaLibraryProvider);
    if (_cloudSpace != space.id) {
      _cloudSpace = space.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(library.refresh(space.id));
          unawaited(library.retryPending());
        }
      });
    }
    final newScope =
        '${space.id}/${state.personId}/${posts.map((p) => p.id).join(',')}';
    if (scope != newScope) {
      scope = newScope;
      index = 0;
      final old = pages;
      pages = PageController();
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    final photo = posts.isEmpty
        ? null
        : posts[index.clamp(0, posts.length - 1)];
    final task = photo?.taskId == null
        ? null
        : repo.tasks
              .where((t) => t.id == photo!.taskId && t.spaceId == space.id)
              .firstOrNull;
    final width = math.min(MediaQuery.sizeOf(context).width - 40, 600.0);
    void move(int direction) {
      pages.animateToPage(
        index + direction,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 230),
        curve: Curves.easeOut,
      );
    }

    return Stack(
      children: [
        PageBody(
          padding: EdgeInsets.fromLTRB(
            20,
            topControlsClearance(context),
            20,
            160,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Little moments',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('The good bits from ${space.name}.'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const ClayArt('moments-selfie-group', height: 88, width: 100),
              ],
            ),
            if (repo.isShared && !library.supportsSharing)
              const Text('Photos stay on this device.'),
            if (library.syncError != null)
              Text(
                library.syncError!,
                style: const TextStyle(color: SoftPop.secondary),
              ),
            if (library.syncError != null && library.supportsSharing)
              TextButton.icon(
                onPressed: library.syncing
                    ? null
                    : () => library.refresh(space.id),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry loading moments'),
              ),
            if (library.pendingIds.isNotEmpty)
              TextButton.icon(
                onPressed: library.syncing
                    ? null
                    : () => library.retryPending(),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text('Retry sharing (${library.pendingIds.length})'),
              ),
            if (photo != null &&
                !photo.cloud &&
                library.supportsSharing &&
                !library.pendingIds.contains(photo.id))
              TextButton.icon(
                onPressed: () => library.share(photo),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Share this photo to space'),
              ),
            if (photo != null && library.pendingIds.contains(photo.id))
              const Text('Saved on this device · waiting to share'),
            const SizedBox(height: 8),
            PeopleFilter(space),
            const SizedBox(height: 12),
            if (recovered != null)
              ClayPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your photo is ready to review'),
                    Text('Review it before sharing with ${space.name}.'),
                    TextButton(
                      onPressed: () async {
                        final saved = await showPhotoComposer(
                          context,
                          space,
                          recovered: recovered,
                        );
                        if (saved == true && mounted) {
                          await discardRecovery();
                        }
                      },
                      child: const Text('Review photo'),
                    ),
                    TextButton(
                      onPressed: discardRecovery,
                      child: const Text('Discard recovered photo'),
                    ),
                  ],
                ),
              ),
            FilledButton.icon(
              key: TutorialTargetRegistry.momentsTabTarget,
              onPressed: () => showPhotoComposer(context, space),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add moment'),
            ),
            const SizedBox(height: 24),
            if (photo == null)
              const ClayPanel(
                child: Column(
                  children: [
                    ClayArt('mascot-moments-camera', height: 160),
                    SizedBox(height: 16),
                    Text('Room for the good bits'),
                    SizedBox(height: 8),
                    Text(
                      'A meal made together. A tiny victory. A moment worth keeping.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else ...[
              SizedBox(
                height: (width - 32) * .75 + 70,
                child: PageView.builder(
                  key: ValueKey(scope),
                  controller: pages,
                  itemCount: posts.length,
                  onPageChanged: (i) => setState(() => index = i),
                  itemBuilder: (context, i) => ClayTelevision(
                    photo: posts[i],
                    onOpen: () => viewPhoto(context, posts[i]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Previous moment',
                    onPressed: index == 0 ? null : () => move(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text('${index + 1} of ${posts.length}'),
                  IconButton.filledTonal(
                    tooltip: 'Next moment',
                    onPressed: index >= posts.length - 1 ? null : () => move(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                photo.heading,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (photo.taskTitle != null && photo.caption.isNotEmpty)
                Text(photo.caption),
              const SizedBox(height: 8),
              Text(
                '${personName(space, photo.uploaderId)} · ${MaterialLocalizations.of(context).formatMediumDate(photo.publishedAt!.toLocal())}',
              ),
              if (photo.pin != null)
                ClayAction(
                  onPressed: () => showPhotoLocation(context, photo),
                  icon: const Icon(Icons.place_outlined),
                  label: Text(
                    photo.pin!.source == 'capture'
                        ? 'Taken here · view location'
                        : 'Place tag · view location',
                  ),
                ),
              if (task != null && repo.canView(task))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ClayAction(
                    onPressed: () => context.push('/task/${task.id}'),
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('View task'),
                  ),
                ),
              if (photo.uploaderId == repo.currentUserId)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ClayAction(
                    onPressed: () => removePhoto(context, ref, photo),
                    color: SoftPop.rose,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Remove photo'),
                  ),
                ),
              if (photo.uploaderId != repo.currentUserId &&
                  ref.read(sharedBackendProvider) != null)
                TextButton.icon(
                  onPressed: () => SafetySheet.report(
                    context,
                    ref.read(sharedBackendProvider)!,
                    spaceId: space.id,
                    kind: 'moment',
                    contentId: photo.id,
                    targetUid: photo.uploaderId,
                  ),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Report or hide moment'),
                ),
            ],
          ],
        ),
        if (library.syncing)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: MomentsLoader(sharing: library.pendingIds.isNotEmpty),
              ),
            ),
          ),
      ],
    );
  }
}

class ClayTelevision extends StatelessWidget {
  const ClayTelevision({super.key, required this.photo, required this.onOpen});
  final MediaAttachment photo;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(32),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF8EACF), Color(0xFFE4D3B4)],
      ),
      border: Border.all(color: const Color(0xFFFFF7EB), width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x25202633),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF8B8378),
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Material(
                color: SoftPop.ink,
                child: Semantics(
                  label: 'Expand photo',
                  button: true,
                  child: InkWell(
                    onTap: onOpen,
                    child: SizedBox.expand(
                      child: FramedPhoto(
                        bytes: photo.photo.bytes,
                        framing: photo.framing,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: SoftPop.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const Spacer(),
              for (var i = 0; i < 5; i++)
                Container(
                  width: 3,
                  height: 16,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B8F7E),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
