import '../features/onboarding/tutorial/tutorial_target_registry.dart';

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sembast/sembast.dart';

import 'external_launcher.dart';
import 'online_backend.dart';
import '../core/clay.dart';
import '../core/theme.dart';
import '../core/member_avatar.dart';
import '../features/media/camera_screen.dart';
import '../features/media/media_library.dart';
import '../features/media/photo_viewer.dart';
import '../features/media/store.dart';
import '../features/moments/moments_screen.dart' show ClayTelevision;

final _onlineMomentRecords = stringMapStoreFactory.store(
  'online-local-moments',
);

/// Device-only photos. This separate store never implies a Cloud Storage upload.
class OnlineMomentsStore extends ChangeNotifier {
  OnlineMomentsStore._(this.database, this._items);
  final Database database;
  final List<MediaAttachment> _items;
  int _serial = 0;

  static Future<OnlineMomentsStore> open() async {
    return fromDatabase(await openLocalDatabase());
  }

  static Future<OnlineMomentsStore> fromDatabase(Database db) async {
    final records = await _onlineMomentRecords.find(db);
    return OnlineMomentsStore._(db, [
      for (final record in records) MediaAttachment.fromMap(record.value),
    ]);
  }

  List<MediaAttachment> forSpace(String uid, String spaceId) =>
      _items
          .where((item) => item.uploaderId == uid && item.spaceId == spaceId)
          .toList()
        ..sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));

  Future<void> add(
    String uid,
    String spaceId,
    PhotoDraft photo,
    String caption,
  ) async {
    final now = DateTime.now().toUtc();
    final item = MediaAttachment(
      id: 'local-${now.microsecondsSinceEpoch}-${_serial++}',
      spaceId: spaceId,
      uploaderId: uid,
      caption: caption.trim(),
      createdAt: now,
      publishedAt: now,
      photo: photo,
    );
    await _onlineMomentRecords.record(item.id).put(database, item.toMap());
    _items.add(item);
    notifyListeners();
  }

  Future<void> remove(MediaAttachment item, String uid) async {
    if (item.uploaderId != uid) {
      throw StateError('Only the author can remove this photo.');
    }
    await _onlineMomentRecords.record(item.id).delete(database);
    _items.removeWhere((record) => record.id == item.id);
    notifyListeners();
  }
}

class OnlineMomentsScreen extends StatefulWidget {
  const OnlineMomentsScreen({
    super.key,
    required this.store,
    required this.spaceId,
    required this.spaceName,
    required this.myUid,
    required this.personUid,
    required this.members,
    required this.onPersonSelected,
    this.backend,
  });
  final OnlineMomentsStore store;
  final String spaceId, spaceName, myUid;
  final String? personUid;
  final Map<String, Map<String, dynamic>> members;
  final ValueChanged<String?> onPersonSelected;
  final OnlineBackend? backend;

  @override
  State<OnlineMomentsScreen> createState() => _OnlineMomentsScreenState();
}

class _OnlineMomentsScreenState extends State<OnlineMomentsScreen> {
  PageController pages = PageController();
  int index = 0;
  String scope = '';

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant OnlineMomentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_changed);
      widget.store.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.store.removeListener(_changed);
    pages.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => _OnlineMomentComposer(
          store: widget.store,
          uid: widget.myUid,
          spaceId: widget.spaceId,
          spaceName: widget.spaceName,
        ),
      ),
    );
  }

  Future<void> _remove(MediaAttachment item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove this photo?'),
        content: const Text('It will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep photo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.store.remove(item, widget.myUid);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove the photo. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = widget.store
        .forSpace(widget.myUid, widget.spaceId)
        .where(
          (item) =>
              widget.personUid == null || item.uploaderId == widget.personUid,
        )
        .toList();
    final nextScope =
        '${widget.spaceId}/${widget.personUid}/${posts.map((p) => p.id).join(',')}';
    if (scope != nextScope) {
      scope = nextScope;
      index = 0;
      final old = pages;
      pages = PageController();
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    final photo = posts.isEmpty
        ? null
        : posts[index.clamp(0, posts.length - 1)];
    final width = math.min(MediaQuery.sizeOf(context).width - 40, 600.0);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            96,
            20,
            148 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Text(
              'Little moments',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text('The good bits from ${widget.spaceName}.'),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip(null, 'Everyone'),
                  _chip(widget.myUid, 'Me'),
                  for (final entry in widget.members.entries)
                    if (entry.key != widget.myUid)
                      _chip(
                        entry.key,
                        entry.value['name'] as String? ?? 'Member',
                      ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: TutorialTargetRegistry.momentsTabTarget,
              onPressed: _add,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add moment'),
            ),
            const SizedBox(height: 24),
            if (photo == null)
              const ClayPanel(
                child: Column(
                  children: [
                    ClayArt('moments-selfie-group', height: 160),
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
                  onPageChanged: (value) => setState(() => index = value),
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
                    onPressed: index == 0
                        ? null
                        : () => pages.animateToPage(
                            index - 1,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 230),
                            curve: Curves.easeOut,
                          ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text('${index + 1} of ${posts.length}'),
                  IconButton.filledTonal(
                    tooltip: 'Next moment',
                    onPressed: index >= posts.length - 1
                        ? null
                        : () => pages.animateToPage(
                            index + 1,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 230),
                            curve: Curves.easeOut,
                          ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                photo.heading,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (photo.caption.contains(' • ')) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () {
                      final place = photo.caption.split(' • ').last.trim();
                      if (place.isNotEmpty) {
                        ExternalLauncher.openMapDirections(
                          context,
                          query: place,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '📍 ${photo.caption.split(' • ').last.trim()}',
                        style: const TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF244BFF),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'You · ${MaterialLocalizations.of(context).formatMediumDate(photo.publishedAt!.toLocal())}',
              ),
              const Text('Saved on this device'),
              const SizedBox(height: 8),
              if (widget.backend != null && photo.cloud)
                _ReactionPills(
                  backend: widget.backend,
                  spaceId: widget.spaceId,
                  momentId: photo.id,
                  myUid: widget.myUid,
                ),
              TextButton(
                onPressed: () => _remove(photo),
                child: const Text('Remove photo'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String? uid, String name) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      showCheckmark: false,
      avatar: uid == null
          ? null
          : MemberAvatar(
              uid: uid,
              name: name == 'Me'
                  ? (widget.members[uid]?['name'] as String? ??
                        widget.backend?.auth.currentUser?.displayName ??
                        widget.backend?.auth.currentUser?.email
                            ?.split('@')
                            .first ??
                        'Member')
                  : name,
            ),
      label: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: widget.personUid == uid,
      onSelected: (_) => widget.onPersonSelected(uid),
    ),
  );
}

class _OnlineMomentComposer extends StatefulWidget {
  const _OnlineMomentComposer({
    required this.store,
    required this.uid,
    required this.spaceId,
    required this.spaceName,
  });
  final OnlineMomentsStore store;
  final String uid, spaceId, spaceName;
  @override
  State<_OnlineMomentComposer> createState() => _OnlineMomentComposerState();
}

class _OnlineMomentComposerState extends State<_OnlineMomentComposer> {
  final caption = TextEditingController();
  PhotoDraft? draft;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  Future<void> acquire(bool camera) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final CapturedPhoto? photo = camera
          ? await Navigator.of(context).push<CapturedPhoto>(
              MaterialPageRoute(
                builder: (_) => CameraScreen(spaceName: widget.spaceName),
              ),
            )
          : await () async {
              final picked = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                requestFullMetadata: false,
              );
              return picked == null
                  ? null
                  : CapturedPhoto(await picked.readAsBytes(), 'library');
            }();
      if (photo != null) {
        final processed = await compute(processPhoto, {
          'bytes': photo.bytes,
          'source': photo.source,
        });
        if (mounted) setState(() => draft = processed);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not prepare that photo. Try another.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (draft == null || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.add(widget.uid, widget.spaceId, draft!, caption.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save this photo. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Add a moment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (draft == null)
              const ClayArt('greeting', height: 130)
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.memory(
                  draft!.bytes,
                  height: 260,
                  fit: BoxFit.contain,
                ),
              ),
            const SizedBox(height: 16),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => acquire(true),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take photo'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => acquire(false),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose photo'),
                ),
              ],
            ),
            if (draft != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: caption,
                maxLength: 300,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'A caption (optional)',
                ),
              ),
              const SizedBox(height: 12),
              ClayPanel(
                color: SoftPop.blueSoft,
                child: Text('Saved in ${widget.spaceName} on this device'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: const Text('Save moment'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ReactionPills extends StatefulWidget {
  const _ReactionPills({
    required this.backend,
    required this.spaceId,
    required this.momentId,
    required this.myUid,
  });

  final OnlineBackend? backend;
  final String spaceId;
  final String momentId;
  final String myUid;

  @override
  State<_ReactionPills> createState() => _ReactionPillsState();
}

class _ReactionPillsState extends State<_ReactionPills> {
  Future<void> _toggle(String type) async {
    if (widget.backend == null) return;
    try {
      await widget.backend!.call('toggleReaction', {
        'spaceId': widget.spaceId,
        'momentId': widget.momentId,
        'reactionType': type,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (widget.backend == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.backend!.reactions(widget.spaceId, widget.momentId),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        int hearts = 0;
        int prays = 0;
        bool myHeart = false;
        bool myPray = false;

        for (final doc in docs) {
          final data = doc.data();
          final type = data['type'] as String?;
          final uid = data['uid'] as String?;
          if (type == 'heart') {
            hearts++;
            if (uid == widget.myUid) myHeart = true;
          } else if (type == 'pray') {
            prays++;
            if (uid == widget.myUid) myPray = true;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pill(
                label: '❤️ ${hearts > 0 ? hearts : ''}',
                selected: myHeart,
                onTap: () => _toggle('heart'),
              ),
              const SizedBox(width: 8),
              _pill(
                label: '🙏 ${prays > 0 ? prays : ''}',
                selected: myPray,
                onTap: () => _toggle('pray'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8EEFF) : const Color(0xFFFFFEFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF244BFF) : const Color(0xFFE5E2DA),
          ),
        ),
        child: Text(
          label.trim(),
          style: TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? const Color(0xFF244BFF) : const Color(0xFF202633),
          ),
        ),
      ),
    );
  }
}
