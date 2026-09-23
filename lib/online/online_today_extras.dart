import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/clay.dart';
import '../core/equal_height_row.dart';
import '../core/theme.dart';
import '../features/moods/mood_presentation.dart';
import '../features/timeline/domain/models.dart';
import 'online_backend.dart';

class OnlineTodayExtras extends StatelessWidget {
  const OnlineTodayExtras({
    super.key,
    required this.backend,
    required this.spaceId,
    required this.spaceName,
    required this.myUid,
    required this.personUid,
    required this.members,
  });

  final OnlineBackend backend;
  final String spaceId, spaceName, myUid;
  final String? personUid;
  final Map<String, Map<String, dynamic>> members;

  @override
  Widget build(BuildContext context) {
    final subject = personUid ?? myUid;
    final me = subject == myUid;
    final mood = _OnlineMoodCard(
      backend: backend,
      spaceId: spaceId,
      spaceName: spaceName,
      subject: subject,
      me: me,
      name: members[subject]?['name'] as String? ?? 'Member',
      memberCount: members.length,
    );
    final calendar = _OnlineCalendarCard(
      backend: backend,
      spaceId: spaceId,
      spaceName: spaceName,
      myUid: myUid,
      personUid: personUid,
      members: members,
    );
    final large = MediaQuery.textScalerOf(context).scale(16) > 22;
    return large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [mood, const SizedBox(height: 12), calendar],
          )
        : EqualHeightRow(children: [mood, calendar]);
  }
}

String _firstName(String name) {
  final first = name.trim().split(RegExp(r'\s+')).first;
  return first.length > 12 ? '${first.substring(0, 11)}…' : first;
}

class _OnlineMoodCard extends StatelessWidget {
  const _OnlineMoodCard({
    required this.backend,
    required this.spaceId,
    required this.spaceName,
    required this.subject,
    required this.me,
    required this.name,
    required this.memberCount,
  });
  final OnlineBackend backend;
  final String spaceId, spaceName, subject, name;
  final bool me;
  final int memberCount;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: backend.checkIn(spaceId, subject),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final expires = data?['expiresAt'];
          final current =
              data != null &&
              expires is Timestamp &&
              expires.toDate().isAfter(DateTime.now());
          final mood = current
              ? Mood.values.where((m) => m.name == data['mood']).firstOrNull
              : null;
          final color = current
              ? MoodColor.values
                        .where((c) => c.name == data['color'])
                        .firstOrNull ??
                    MoodColor.sky
              : MoodColor.sky;
          return ClayPanel(
            color: moodSurface(color),
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => _OnlineMoodSheet(
                  backend: backend,
                  spaceId: spaceId,
                  spaceName: spaceName,
                  name: name,
                  memberCount: memberCount,
                  me: me,
                  current: current ? data : null,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      me ? 'Your mood' : '${_firstName(name)}’s mood',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Center(
                      child: mood == null && !me
                          ? const SizedBox(
                              height: 92,
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 52,
                                color: SoftPop.secondary,
                              ),
                            )
                          : ClayArt(
                              moodArtName(mood ?? Mood.calm, color),
                              height: 92,
                            ),
                    ),
                    Text(
                      mood?.label ?? (me ? 'How are you?' : 'No check-in yet'),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            me
                                ? mood == null
                                      ? 'Check in'
                                      : 'Update mood'
                                : 'View mood',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: SoftPop.blue),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: SoftPop.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _OnlineMoodSheet extends StatefulWidget {
  const _OnlineMoodSheet({
    required this.backend,
    required this.spaceId,
    required this.spaceName,
    required this.name,
    required this.memberCount,
    required this.me,
    required this.current,
  });
  final OnlineBackend backend;
  final String spaceId, spaceName, name;
  final int memberCount;
  final bool me;
  final Map<String, dynamic>? current;
  @override
  State<_OnlineMoodSheet> createState() => _OnlineMoodSheetState();
}

class _OnlineMoodSheetState extends State<_OnlineMoodSheet> {
  late final TextEditingController note = TextEditingController(
    text: widget.current?['note'] as String? ?? '',
  );
  late Mood? selected = Mood.values
      .where((m) => m.name == widget.current?['mood'])
      .firstOrNull;
  late MoodColor color =
      MoodColor.values
          .where((c) => c.name == widget.current?['color'])
          .firstOrNull ??
      MoodColor.sky;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> save({bool remove = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.backend.call(remove ? 'removeCheckIn' : 'setCheckIn', {
        'spaceId': widget.spaceId,
        if (!remove) ...{
          'mood': selected!.name,
          'color': color.name,
          'note': note.text.trim(),
        },
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not save. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.me ? 'How are you feeling?' : widget.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Shared with ${widget.spaceName} · ${widget.memberCount} members',
            ),
            const SizedBox(height: 20),
            if (!widget.me) ...[
              if (selected == null)
                const Text('No check-in yet.')
              else ...[
                ClayArt(moodArtName(selected!, color), height: 150),
                Text(
                  '${selected!.label} · ${color.label}',
                  textAlign: TextAlign.center,
                ),
                if (note.text.isNotEmpty) Text(note.text),
              ],
            ] else ...[
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mood in Mood.values)
                      SizedBox(
                        width: MediaQuery.textScalerOf(context).scale(16) > 22
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 8) / 2,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: selected == mood
                                ? SoftPop.blueSoft
                                : SoftPop.surface,
                            side: BorderSide(
                              color: selected == mood
                                  ? SoftPop.blue
                                  : SoftPop.controlBorder,
                            ),
                          ),
                          onPressed: () => setState(() => selected = mood),
                          child: Column(
                            children: [
                              ClayArt(moodArtName(mood, color), height: 76),
                              Text(mood.label),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose your color',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final choice in MoodColor.values)
                    ChoiceChip(
                      label: Text(choice.label),
                      avatar: CircleAvatar(
                        backgroundColor: moodSwatch(choice),
                        radius: 10,
                      ),
                      selected: color == choice,
                      onSelected: (_) => setState(() => color = choice),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: note,
                maxLength: 180,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'A little note (optional)',
                ),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              FilledButton(
                onPressed: selected == null || busy ? null : save,
                child: Text(
                  widget.current == null ? 'Share check-in' : 'Update check-in',
                ),
              ),
              if (widget.current != null)
                TextButton(
                  onPressed: busy ? null : () => save(remove: true),
                  child: const Text('Remove my check-in'),
                ),
            ],
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: Text(widget.me ? 'Skip for now' : 'Close'),
            ),
          ],
        ),
      ),
    ),
  );
}

class OnlinePlan {
  const OnlinePlan(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  String get title => data['title'] as String? ?? 'Plan';
  String get owner => data['ownerUid'] as String? ?? '';
  List<String> get participants =>
      List<String>.from(data['participants'] as List? ?? []);
  bool get allDay => data['allDay'] == true;
  DateTime get start => (data['startAt'] as Timestamp).toDate();
  DateTime get end => (data['endAt'] as Timestamp).toDate();
  DateTime get localStart => allDay
      ? DateTime.utc(start.toUtc().year, start.toUtc().month, start.toUtc().day)
      : start.toLocal();
  DateTime get localEnd => allDay
      ? DateTime.utc(end.toUtc().year, end.toUtc().month, end.toUtc().day)
      : end.toLocal();
  bool matches(String? person) =>
      person == null || owner == person || participants.contains(person);
  bool occursOn(DateTime date) {
    final d = allDay
        ? DateTime.utc(date.year, date.month, date.day)
        : DateTime(date.year, date.month, date.day);
    final next = allDay
        ? DateTime.utc(date.year, date.month, date.day + 1)
        : DateTime(date.year, date.month, date.day + 1);
    return localStart.isBefore(next) && localEnd.isAfter(d);
  }
}

class _OnlineCalendarCard extends StatelessWidget {
  const _OnlineCalendarCard({
    required this.backend,
    required this.spaceId,
    required this.spaceName,
    required this.myUid,
    required this.personUid,
    required this.members,
  });
  final OnlineBackend backend;
  final String spaceId, spaceName, myUid;
  final String? personUid;
  final Map<String, Map<String, dynamic>> members;

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: backend.plans(spaceId),
    builder: (context, snapshot) {
      final now = DateTime.now();
      final month = DateTime(now.year, now.month);
      final plans = [
        for (final doc in snapshot.data?.docs ?? [])
          OnlinePlan(doc.id, doc.data()),
      ];
      final name = personUid == null
          ? 'Shared'
          : personUid == myUid
          ? 'Your'
          : '${_firstName(members[personUid]?['name'] as String? ?? 'Member')}’s';
      return Semantics(
        button: true,
        label: '$name calendar. Open calendar',
        child: Material(
          color: const Color(0xFFF0F2FE),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => SizedBox(
                height: MediaQuery.sizeOf(context).height * .92,
                child: OnlineCalendarSheet(
                  backend: backend,
                  spaceId: spaceId,
                  spaceName: spaceName,
                  myUid: myUid,
                  personUid: personUid,
                  members: members,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$name calendar',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      const Icon(
                        Icons.north_east_rounded,
                        size: 18,
                        color: SoftPop.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StreakGrid(month: month, personUid: personUid, plans: plans),
                  const SizedBox(height: 10),
                  Text(
                    MaterialLocalizations.of(context).formatMonthYear(month),
                  ),
                  Text(
                    personUid == null
                        ? 'Everyone’s plans'
                        : personUid == myUid
                        ? 'You · Plans'
                        : '${_firstName(members[personUid]?['name'] as String? ?? 'Member')} · Plans',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _StreakGrid extends StatelessWidget {
  const _StreakGrid({
    required this.month,
    required this.personUid,
    required this.plans,
  });
  final DateTime month;
  final String? personUid;
  final List<OnlinePlan> plans;
  @override
  Widget build(BuildContext context) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = month.weekday - 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - 18) / 7;
        return Wrap(
          spacing: 3,
          runSpacing: 3,
          children: [
            for (
              var index = 0;
              index < ((days + offset) / 7).ceil() * 7;
              index++
            )
              Builder(
                builder: (_) {
                  final day = index - offset + 1;
                  final date = DateTime(month.year, month.month, day);
                  final count = plans
                      .where((p) => p.matches(personUid) && p.occursOn(date))
                      .length;
                  final today =
                      day > 0 &&
                      day <= days &&
                      date.year == DateTime.now().year &&
                      date.month == DateTime.now().month &&
                      date.day == DateTime.now().day;
                  return Container(
                    width: cell,
                    height: cell,
                    decoration: BoxDecoration(
                      color: day < 1 || day > days
                          ? Colors.transparent
                          : count == 0
                          ? const Color(0xFFDDE2F1)
                          : count == 1
                          ? SoftPop.sky
                          : count == 2
                          ? const Color(0xFF809AFB)
                          : SoftPop.blue,
                      borderRadius: BorderRadius.circular(3),
                      border: today
                          ? Border.all(color: SoftPop.blue, width: 1.5)
                          : null,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class OnlineCalendarSheet extends StatefulWidget {
  const OnlineCalendarSheet({
    super.key,
    required this.backend,
    required this.spaceId,
    required this.spaceName,
    required this.myUid,
    required this.personUid,
    required this.members,
  });
  final OnlineBackend backend;
  final String spaceId, spaceName, myUid;
  final String? personUid;
  final Map<String, Map<String, dynamic>> members;
  @override
  State<OnlineCalendarSheet> createState() => _OnlineCalendarSheetState();
}

class _OnlineCalendarSheetState extends State<OnlineCalendarSheet> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime selected = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: widget.backend.plans(widget.spaceId),
    builder: (context, snapshot) {
      final plans = [
        for (final doc in snapshot.data?.docs ?? [])
          OnlinePlan(doc.id, doc.data()),
      ];
      final visible =
          plans
              .where((p) => p.matches(widget.personUid) && p.occursOn(selected))
              .toList()
            ..sort((a, b) => a.localStart.compareTo(b.localStart));
      final days = DateTime(month.year, month.month + 1, 0).day;
      final offset = month.weekday - 1;
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Room for plans',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(widget.spaceName),
                      ],
                    ),
                  ),
                  const ClayArt('calendar', height: 68, width: 70),
                  IconButton(
                    tooltip: 'Close calendar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => setState(() {
                      month = DateTime(month.year, month.month - 1);
                      selected = month;
                    }),
                  ),
                  Expanded(
                    child: Text(
                      MaterialLocalizations.of(context).formatMonthYear(month),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => setState(() {
                      month = DateTime(month.year, month.month + 1);
                      selected = month;
                    }),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {
                    final now = DateTime.now();
                    month = DateTime(now.year, now.month);
                    selected = DateTime(now.year, now.month, now.day);
                  }),
                  child: const Text('Back to today'),
                ),
              ),
              Row(
                children: [
                  for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(child: Center(child: Text(label))),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                ),
                itemCount: ((days + offset) / 7).ceil() * 7,
                itemBuilder: (context, index) {
                  final number = index - offset + 1;
                  if (number < 1 || number > days) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime(month.year, month.month, number);
                  final count = plans
                      .where(
                        (p) => p.matches(widget.personUid) && p.occursOn(date),
                      )
                      .length;
                  final active = date == selected;
                  return Semantics(
                    selected: active,
                    button: true,
                    label:
                        '${MaterialLocalizations.of(context).formatFullDate(date)}, $count plans',
                    child: InkWell(
                      onTap: () => setState(() => selected = date),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: active
                              ? SoftPop.blue
                              : count > 0
                              ? SoftPop.blueSoft
                              : SoftPop.surface,
                          border:
                              date ==
                                  DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month,
                                    DateTime.now().day,
                                  )
                              ? Border.all(color: SoftPop.blue)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$number',
                              style: TextStyle(
                                color: active ? Colors.white : SoftPop.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (count > 0)
                              Icon(
                                Icons.circle,
                                size: 5,
                                color: active ? Colors.white : SoftPop.blue,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                MaterialLocalizations.of(context).formatFullDate(selected),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (visible.isEmpty) const Text('No plans for this day.'),
              for (final plan in visible)
                ClayPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        plan.allDay
                            ? 'All day'
                            : TimeOfDay.fromDateTime(plan.localStart)
                                  .format(context),
                      ),
                      if ((plan.data['note'] as String? ?? '').isNotEmpty)
                        Text(plan.data['note'] as String),
                      Text(
                        widget.members[plan.owner]?['name'] as String? ??
                            'Member',
                      ),
                      if (plan.owner == widget.myUid)
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: () => _edit(plan),
                              child: const Text('Edit'),
                            ),
                            TextButton(
                              onPressed: () => _remove(plan),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _edit(null),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a plan'),
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _edit(OnlinePlan? plan) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PlanEditor(
        backend: widget.backend,
        spaceId: widget.spaceId,
        spaceName: widget.spaceName,
        myUid: widget.myUid,
        members: widget.members,
        selected: selected,
        plan: plan,
      ),
    );
  }

  Future<void> _remove(OnlinePlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Remove this plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep'),
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
      await widget.backend.call('removePlan', {
        'spaceId': widget.spaceId,
        'planId': plan.id,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove this plan. Try again.'),
          ),
        );
      }
    }
  }
}

class _PlanEditor extends StatefulWidget {
  const _PlanEditor({
    required this.backend,
    required this.spaceId,
    required this.spaceName,
    required this.myUid,
    required this.members,
    required this.selected,
    required this.plan,
  });
  final OnlineBackend backend;
  final String spaceId, spaceName, myUid;
  final Map<String, Map<String, dynamic>> members;
  final DateTime selected;
  final OnlinePlan? plan;
  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  late final title = TextEditingController(text: widget.plan?.title ?? '');
  late final note = TextEditingController(
    text: widget.plan?.data['note'] as String? ?? '',
  );
  late DateTime day = widget.plan?.localStart ?? widget.selected;
  late DateTime endDay = widget.plan?.localEnd ?? widget.selected;
  late bool allDay = widget.plan?.allDay ?? true;
  late TimeOfDay startTime = widget.plan == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay.fromDateTime(widget.plan!.localStart);
  late TimeOfDay endTime = widget.plan == null
      ? const TimeOfDay(hour: 10, minute: 0)
      : TimeOfDay.fromDateTime(widget.plan!.localEnd);
  late final participants = <String>{...?widget.plan?.participants};
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.plan?.allDay == true) {
      endDay = endDay.subtract(const Duration(days: 1));
    }
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> pickDate({bool end = false}) async {
    final chosen = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: end ? endDay : day,
    );
    if (chosen != null) {
      setState(() {
        if (end) {
          endDay = chosen;
        } else {
          day = chosen;
        }
      });
    }
  }

  Future<void> save() async {
    final start = allDay
        ? DateTime.utc(day.year, day.month, day.day)
        : DateTime(
            day.year,
            day.month,
            day.day,
            startTime.hour,
            startTime.minute,
          );
    final end = allDay
        ? DateTime.utc(endDay.year, endDay.month, endDay.day + 1)
        : DateTime(
            endDay.year,
            endDay.month,
            endDay.day,
            endTime.hour,
            endTime.minute,
          );
    if (title.text.trim().isEmpty || !end.isAfter(start)) {
      setState(() => error = 'Add a name and an end after the start.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id =
          widget.plan?.id ??
          widget.backend.firestore.collection('planIds').doc().id;
      await widget.backend.call('savePlan', {
        'spaceId': widget.spaceId,
        'planId': id,
        'title': title.text.trim(),
        'note': note.text.trim(),
        'allDay': allDay,
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': end.millisecondsSinceEpoch,
        'participants': participants.toList(),
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save this plan. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.plan == null ? 'Add a plan' : 'Edit plan'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sharing with ${widget.spaceName}'),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Plan name'),
            ),
            SwitchListTile(
              title: const Text('All day'),
              value: allDay,
              onChanged: (value) => setState(() => allDay = value),
            ),
            TextButton(
              onPressed: () => pickDate(),
              child: Text(
                'Start: ${MaterialLocalizations.of(context).formatMediumDate(day)}',
              ),
            ),
            TextButton(
              onPressed: () => pickDate(end: true),
              child: Text(
                'End: ${MaterialLocalizations.of(context).formatMediumDate(endDay)}',
              ),
            ),
            if (!allDay) ...[
              TextButton(
                onPressed: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: startTime,
                  );
                  if (value != null) setState(() => startTime = value);
                },
                child: Text('Starts at ${startTime.format(context)}'),
              ),
              TextButton(
                onPressed: () async {
                  final value = await showTimePicker(
                    context: context,
                    initialTime: endTime,
                  );
                  if (value != null) setState(() => endTime = value);
                },
                child: Text('Ends at ${endTime.format(context)}'),
              ),
            ],
            TextField(
              controller: note,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            if (widget.members.length > 1) ...[
              const Text('People included'),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in widget.members.entries)
                    if (entry.key != widget.myUid)
                      FilterChip(
                        label: Text(entry.value['name'] as String? ?? 'Member'),
                        selected: participants.contains(entry.key),
                        onSelected: (value) => setState(() {
                          if (value) {
                            participants.add(entry.key);
                          } else {
                            participants.remove(entry.key);
                          }
                        }),
                      ),
                ],
              ),
            ],
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? 'Saving…' : 'Save plan'),
      ),
    ],
  );
}
