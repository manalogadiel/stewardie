import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
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

/// Canonical photo mutations are acknowledged by the trusted media gateway.
class PhotoReactions extends ConsumerStatefulWidget {
  const PhotoReactions({super.key, required this.photo});
  final MediaAttachment photo;
  @override
  ConsumerState<PhotoReactions> createState() => _PhotoReactionsState();
}

class _PhotoReactionsState extends ConsumerState<PhotoReactions>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> rows = [];
  bool busy = false;
  bool saving = false;
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
    if (busy || library == null) return;
    busy = true;
    try {
      final result = await library!.reactions(widget.photo);
      if (mounted)
        setState(() {
          rows = result;
          error = null;
        });
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load reactions.');
    } finally {
      busy = false;
    }
  }

  Future<void> react(String id) async {
    if (busy || library == null) return;
    final selected = rows.any(
      (row) => row['uid'] == library!.user.uid && row['type'] == id,
    );
    setState(() {
      busy = true;
      saving = true;
      error = null;
    });
    try {
      final result = await library!.reactions(
        widget.photo,
        change: true,
        type: selected ? null : id,
      );
      if (mounted) setState(() => rows = result);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Could not save your reaction. Try again.');
    } finally {
      if (mounted)
        setState(() {
          busy = false;
          saving = false;
        });
    }
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
                          onTap: busy ? null : () => react(entry.key),
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
                                  Text(
                                    '${entry.value}${count > 0 ? ' $count' : ''}',
                                  ),
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
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Saving…'),
            ),
          if (error != null)
            TextButton(onPressed: load, child: Text('$error Retry')),
        ],
      ),
    );
  }
}
