import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_state.dart';
import '../../core/clay.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'mood_presentation.dart';
import '../timeline/domain/models.dart';

Future<void> showMoodSheet(BuildContext context, Space space) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MoodSheet(space: space),
    );

class MoodSheet extends ConsumerStatefulWidget {
  const MoodSheet({super.key, required this.space});
  final Space space;
  @override
  ConsumerState<MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends ConsumerState<MoodSheet> {
  late final TextEditingController note;
  Mood? selected;
  MoodColor color = MoodColor.sky;
  bool updating = false;
  @override
  void initState() {
    super.initState();
    final current = ref.read(repositoryProvider).checkIn(widget.space.id, 'me');
    selected = current?.mood;
    color = current?.color ?? MoodColor.sky;
    updating = current != null;
    note = TextEditingController(text: current?.note ?? '');
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A moment for you',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'How are you feeling?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Every kind of day is welcome. Checking in is optional.',
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: Mood.values
                      .map(
                        (mood) => SizedBox(
                          width: MediaQuery.textScalerOf(context).scale(16) > 22
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 8) / 2,
                          child: Semantics(
                            selected: selected == mood,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: selected == mood
                                    ? SoftPop.blueSoft
                                    : SoftPop.surface,
                                side: BorderSide(
                                  color: selected == mood
                                      ? SoftPop.blue
                                      : SoftPop.controlBorder,
                                  width: selected == mood ? 2 : 1,
                                ),
                                padding: const EdgeInsets.all(12),
                              ),
                              onPressed: () => setState(() => selected = mood),
                              child: Column(
                                children: [
                                  ClayArt(moodArtName(mood, color), height: 84),
                                  const SizedBox(height: 8),
                                  Text(mood.label, textAlign: TextAlign.center),
                                  if (selected == mood)
                                    const Icon(Icons.check_rounded, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose your color',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MoodColor.values
                    .map(
                      (choice) => ChoiceChip(
                        label: Text(choice.label),
                        avatar: CircleAvatar(
                          backgroundColor: moodSwatch(choice),
                          radius: 12,
                        ),
                        selected: color == choice,
                        onSelected: (_) => setState(() => color = choice),
                      ),
                    )
                    .toList(),
              ),
              if (selected != null) ...[
                const SizedBox(height: 12),
                Paper(
                  color: moodSurface(color),
                  child: Row(
                    children: [
                      ClayArt(moodArtName(selected!, color), height: 72),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${selected!.label} · ${color.label}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 4,
                maxLength: 180,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'A little note (optional)',
                  hintText: 'Anything on your mind?',
                ),
              ),
              const SizedBox(height: 12),
              Paper(
                color: SoftPop.blueSoft,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sharing with ${widget.space.name}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.space.members.length} members · Until the end of today.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () {
                        ref
                            .read(repositoryProvider)
                            .shareCheckIn(
                              widget.space.id,
                              'me',
                              selected!,
                              note.text,
                              color: color,
                            );
                        ref.read(demoProvider.notifier).refresh();
                        Navigator.pop(context);
                      },
                child: Text(updating ? 'Update check-in' : 'Share check-in'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(updating ? 'Cancel' : 'Skip for now'),
              ),
              if (updating)
                TextButton(
                  onPressed: () {
                    ref
                        .read(repositoryProvider)
                        .removeCheckIn(widget.space.id, 'me');
                    ref.read(demoProvider.notifier).refresh();
                    Navigator.pop(context);
                  },
                  child: const Text('Remove my check-in'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showMemberMoodSheet(
  BuildContext context,
  Space space,
  Member member,
  CheckIn? mood,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  builder: (sheet) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(member.name, style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Shared with ${space.name}'),
            const SizedBox(height: 20),
            if (mood == null) ...[
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: SoftPop.secondary,
              ),
              const SizedBox(height: 12),
              const Text('No check-in yet', textAlign: TextAlign.center),
            ] else ...[
              ClayPanel(
                color: moodSurface(mood.color),
                child: Column(
                  children: [
                    ClayArt(moodArtName(mood.mood, mood.color), height: 112),
                    const SizedBox(height: 10),
                    Text(
                      mood.mood.label,
                      style: Theme.of(sheet).textTheme.titleLarge,
                    ),
                    Text(
                      '${mood.color.label} · ${MaterialLocalizations.of(sheet).formatMediumDate(mood.sharedAt)} · ${MaterialLocalizations.of(sheet).formatTimeOfDay(TimeOfDay.fromDateTime(mood.sharedAt))}',
                    ),
                    if (mood.note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(mood.note),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Current until ${MaterialLocalizations.of(sheet).formatMediumDate(mood.expiresAt)}',
              ),
            ],
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(sheet),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    ),
  ),
);
