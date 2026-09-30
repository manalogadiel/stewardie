import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/sound_feedback.dart';
import '../../online/cloud_media_library.dart';
import 'media_library.dart';

const photoReactionLabels = {
  'like': 'Like',
  'cheer': 'Cheer',
  'haha': 'Haha',
  'sad': 'Sad',
  'heart': 'Heart',
  'mad': 'Mad',
};

/// Immediate local feedback; serialized canonical mutations reconcile or roll back.
class PhotoReactions extends ConsumerStatefulWidget {
  const PhotoReactions({super.key, required this.photo});
  final MediaAttachment photo;
  @override
  ConsumerState<PhotoReactions> createState() => _PhotoReactionsState();
}

class _PhotoReactionsState extends ConsumerState<PhotoReactions>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> confirmed = [];
  bool reading = false;
  bool saving = false;
  int revision = 0;
  String? desired;
  String? retryType;
  bool retryMutation = false;
  String? error;
  Timer? timer;
  CloudMediaLibrary? get library =>
      ref.read(mediaLibraryProvider) is CloudMediaLibrary
      ? ref.read(mediaLibraryProvider) as CloudMediaLibrary
      : null;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
    timer = Timer.periodic(const Duration(seconds: 30), (_) => load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(load());
      timer ??= Timer.periodic(const Duration(seconds: 30), (_) => load());
    } else {
      timer?.cancel();
      timer = null;
    }
  }

  Future<void> load() async {
    if (reading || saving || library == null) return;
    reading = true;
    final started = revision;
    try {
      final result = await library!.reactions(widget.photo);
      if (mounted && started == revision) {
        setState(() {
          rows = result;
          confirmed = result;
          error = null;
        });
      }
    } catch (_) {
      if (mounted && started == revision) {
        setState(() => error = 'Could not load reactions.');
      }
    } finally {
      reading = false;
    }
  }

  Future<void> react(String id) async {
    if (library == null) return;
    final selected = rows.any(
      (row) => row['uid'] == library!.user.uid && row['type'] == id,
    );
    unawaited(SoundFeedback.emit(SoundCue.reactionPop));
    _choose(selected ? null : id);
  }

  List<Map<String, dynamic>> _withChoice(
    List<Map<String, dynamic>> source,
    String? type,
  ) => [
    ...source.where((r) => r['uid'] != library!.user.uid),
    if (type != null) {'uid': library!.user.uid, 'type': type},
  ];

  void _choose(String? type) {
    setState(() {
      desired = type;
      revision++;
      rows = _withChoice(rows, type);
      error = null;
      retryMutation = false;
    });
    unawaited(_save());
  }

  Future<void> _save() async {
    if (saving || library == null) return;
    setState(() => saving = true);
    while (mounted) {
      final sentRevision = revision;
      final sentType = desired;
      try {
        final result = await library!.reactions(
          widget.photo,
          change: true,
          type: sentType,
        );
        if (!mounted) return;
        confirmed = result;
        setState(
          () => rows = sentRevision == revision
              ? result
              : _withChoice(result, desired),
        );
      } catch (_) {
        if (!mounted) return;
        if (sentRevision == revision) {
          setState(() {
            rows = confirmed;
            error = 'Could not save your reaction.';
            retryType = sentType;
            retryMutation = true;
          });
        }
      }
      if (sentRevision == revision) break;
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (library == null || !widget.photo.cloud) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final entry in photoReactionLabels.entries)
                Builder(
                  builder: (context) {
                    final selected = rows.any(
                      (r) =>
                          r['uid'] == library!.user.uid &&
                          r['type'] == entry.key,
                    );
                    final count = rows
                        .where((r) => r['type'] == entry.key)
                        .length;
                    return Semantics(
                      selected: selected,
                      button: true,
                      label: '${entry.value}, $count reactions',
                      child: Material(
                        color: selected ? SoftPop.lightButter : SoftPop.surface,
                        elevation: 2,
                        shadowColor: SoftPop.ink.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(26),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(26),
                          onTap: () => react(entry.key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/illustrations/reaction-${entry.key}.png',
                                    width: 30,
                                    height: 30,
                                    excludeFromSemantics: true,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('$count'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          if (saving)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Semantics(
                label: 'Syncing reactions',
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (error != null)
            TextButton(
              onPressed: () {
                if (retryMutation) {
                  _choose(retryType);
                } else {
                  unawaited(load());
                }
              },
              child: Text('$error Retry'),
            ),
        ],
      ),
    );
  }
}
