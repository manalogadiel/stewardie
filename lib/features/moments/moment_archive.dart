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
    final date = SpaceTime.localDate(zone, photo.publishedAt!);
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
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(demoProvider);
    if (!ref
        .read(repositoryProvider)
        .spaces
        .any((space) => space.id == spaceId)) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This space is no longer available.')),
      );
    }
    final allowedIds = photos.map((p) => p.id).toSet();
    final current = ref
        .read(mediaLibraryProvider)
        .items
        .where((p) => p.spaceId == spaceId && allowedIds.contains(p.id));
    final groups = groupMomentDates(current, timeZone);
    final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return Scaffold(
      backgroundColor: SoftPop.canvas,
      appBar: AppBar(
        title: Text(
          '$spaceName archive',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: dates.isEmpty
          ? const Center(child: Text('Your past moments will appear here.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index], items = groups[dates[index]]!;
                return _ArchiveTile(
                  photo: items.first,
                  label: date,
                  count: items.length,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ArchiveDay(
                        spaceId: spaceId,
                        date: date,
                        timeZone: timeZone,
                        allowedIds: allowedIds,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ArchiveDay extends ConsumerWidget {
  const _ArchiveDay({
    required this.spaceId,
    required this.date,
    required this.timeZone,
    required this.allowedIds,
  });
  final String spaceId, date, timeZone;
  final Set<String> allowedIds;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(demoProvider);
    final allowed = ref
        .read(repositoryProvider)
        .spaces
        .any((space) => space.id == spaceId);
    final items = allowed
        ? ref
              .read(mediaLibraryProvider)
              .items
              .where(
                (p) =>
                    p.spaceId == spaceId &&
                    allowedIds.contains(p.id) &&
                    p.publishedAt != null &&
                    SpaceTime.localDate(timeZone, p.publishedAt!) == date,
              )
              .toList()
        : <MediaAttachment>[];
    return Scaffold(
      backgroundColor: SoftPop.canvas,
      appBar: AppBar(title: Text(date)),
      body: !allowed
          ? const Center(child: Text('This space is no longer available.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) => _ArchiveTile(
                photo: items[index],
                onTap: () => viewPhoto(context, items[index]),
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
