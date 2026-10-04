import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_state.dart';

import '../../core/theme.dart';
import '../../core/space_time.dart';
import '../media/media_library.dart';
import '../media/photo_viewer.dart';

Map<String, List<MediaAttachment>> groupMomentDates(
  Iterable<MediaAttachment> photos,
  String zone,
) {
  final grouped = <String, List<MediaAttachment>>{};
  for (final photo in photos) {
    if (photo.publishedAt == null) continue;
    final date =
        photo.momentDate ?? SpaceTime.localDate(zone, photo.publishedAt!);
    (grouped[date] ??= []).add(photo);
  }
  return grouped;
}

class MomentArchive extends ConsumerWidget {
  const MomentArchive({
    super.key,
    required this.photos,
    required this.spaceId,
    required this.spaceName,
    required this.timeZone,
  });
  final List<MediaAttachment> photos;
  final String spaceName, timeZone, spaceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _ArchivePages<MomentDateSummary>(
        spaceId: spaceId,
        title: '$spaceName archive',
        empty: 'Your past moments will appear here.',
        load: (cursor) => ref
            .read(mediaLibraryProvider)
            .archiveDates(spaceId, cursor: cursor),
        tile: (context, entry) => _ArchiveTile(
          photo: entry.cover,
          label: entry.date,
          count: entry.count,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _ArchivePages<MediaAttachment>(
                spaceId: spaceId,
                title: entry.date,
                empty: 'No moments on this date.',
                load: (cursor) => ref
                    .read(mediaLibraryProvider)
                    .archiveDay(spaceId, entry.date, cursor: cursor),
                tile: (context, photo) => _ArchiveTile(
                  photo: photo,
                  onTap: () => viewPhoto(context, photo),
                ),
              ),
            ),
          ),
        ),
      );
}

class _ArchivePages<T> extends ConsumerStatefulWidget {
  const _ArchivePages({
    required this.spaceId,
    required this.title,
    required this.empty,
    required this.load,
    required this.tile,
  });
  final String spaceId, title, empty;
  final Future<MediaPage<T>> Function(Map<String, Object?>? cursor) load;
  final Widget Function(BuildContext, T) tile;
  @override
  ConsumerState<_ArchivePages<T>> createState() => _ArchivePagesState<T>();
}

class _ArchivePagesState<T> extends ConsumerState<_ArchivePages<T>> {
  List<T> _items = [];
  Map<String, Object?>? _cursor;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.load(reset ? null : _cursor);
      if (!mounted) return;
      setState(() {
        _items = reset ? result.items : [..._items, ...result.items];
        _cursor = result.cursor;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Could not load the archive. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(demoProvider);
    final allowed = ref
        .read(repositoryProvider)
        .spaces
        .any((s) => s.id == widget.spaceId);
    return Scaffold(
      backgroundColor: SoftPop.canvas,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Refresh archive',
            onPressed: _busy ? null : () => _load(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !allowed
            ? const Center(child: Text('This space is no longer available.'))
            : _busy && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _load(reset: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_items.isEmpty && _error == null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text(widget.empty)),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 260,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              widget.tile(context, _items[index]),
                          childCount: _items.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          children: [
                            if (_error != null)
                              Text(_error!, textAlign: TextAlign.center),
                            if (_error != null)
                              TextButton(
                                onPressed: () => _load(reset: _items.isEmpty),
                                child: const Text('Try again'),
                              ),
                            if (_busy && _items.isNotEmpty)
                              const CircularProgressIndicator(),
                            if (_cursor != null && !_busy)
                              ElevatedButton.icon(
                                onPressed: () => _load(),
                                icon: const Icon(Icons.expand_more_rounded),
                                label: const Text('More memories'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({
    required this.photo,
    required this.onTap,
    this.label,
    this.count,
  });
  final MediaAttachment photo;
  final VoidCallback onTap;
  final String? label;
  final int? count;
  @override
  Widget build(BuildContext context) => Material(
    color: SoftPop.surface,
    elevation: 2,
    shadowColor: SoftPop.ink.withValues(alpha: .12),
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            photo.photo.thumbnail,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
          if (label != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SoftPop.surface.withValues(alpha: .95),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$label · $count photos',
                  maxLines: 2,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: SoftPop.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
