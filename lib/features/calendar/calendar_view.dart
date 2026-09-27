import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clay.dart';
import '../../core/backend_provider.dart';
import '../../core/place_pin.dart';
import '../../online/external_launcher.dart';
import '../../core/demo_state.dart';
import '../../core/people_filter.dart';
import '../../core/person_labels.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../timeline/domain/models.dart';
import 'calendar_state.dart';
import 'google_calendar_import.dart';

String monthLabel(BuildContext context, DateTime month) =>
    MaterialLocalizations.of(context).formatMonthYear(month);

class CalendarTile extends ConsumerWidget {
  const CalendarTile(this.space, {super.key});
  final Space space;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final person = ref.watch(demoProvider.select((s) => s.personId));
    final days = DateTime(state.month.year, state.month.month + 1, 0).day;
    final offset = state.month.weekday - 1;
    final scope = calendarScope(space, person);
    return Semantics(
      button: true,
      label: '${monthLabel(context, state.month)}. $scope. Open calendar',
      child: Material(
        color: const Color(0xFFF0F2FE),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            final backend = ref.read(sharedBackendProvider);
            if (backend != null) {
              GoogleCalendarImport.instance.refreshSpace(backend, space.id)
                  .then((_) => ref.read(calendarProvider.notifier).refresh())
                  .catchError((Object _) {});
            }
            showCalendar(context, space);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CompactPersonTitle(
                        space: space,
                        personId: person,
                        noun: 'calendar',
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
                ExcludeSemantics(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cell = (constraints.maxWidth - 18) / 7;
                      return Wrap(
                        spacing: 3,
                        runSpacing: 3,
                        children: List.generate(
                          ((days + offset) / 7).ceil() * 7,
                          (index) {
                            final day = index - offset + 1;
                            final date = DateTime(
                              state.month.year,
                              state.month.month,
                              day,
                            );
                            final count = state
                                .forDay(space.id, person, date)
                                .length;
                            final today = dateOnly(DateTime.now()) == date;
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
                                    ? Border.all(
                                        color: SoftPop.blue,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  monthLabel(context, state.month),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  scope,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showCalendar(BuildContext context, Space space) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .92,
        child: CalendarSheet(space),
      ),
    );

class CalendarSheet extends ConsumerWidget {
  const CalendarSheet(this.space, {super.key});
  final Space space;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarProvider);
    final person = ref.watch(demoProvider.select((s) => s.personId));
    final days = DateTime(state.month.year, state.month.month + 1, 0).day;
    final offset = state.month.weekday - 1;
    final plans = state.forDay(space.id, person, state.selectedDay);
    final controller = ref.read(calendarProvider.notifier);
    final large = MediaQuery.textScalerOf(context).scale(16) > 22;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
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
                      Text(space.name),
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
            PeopleFilter(space),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => controller.changeMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    monthLabel(context, state.month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => controller.changeMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => controller.selectDay(DateTime.now()),
                child: const Text('Back to today'),
              ),
            ),
            if (large)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(days, (index) {
                    final day = DateTime(
                      state.month.year,
                      state.month.month,
                      index + 1,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${index + 1}'),
                        selected: day == state.selectedDay,
                        onSelected: (_) => controller.selectDay(day),
                      ),
                    );
                  }),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth < 336
                      ? 336.0
                      : constraints.maxWidth;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              for (final label in [
                                'M',
                                'T',
                                'W',
                                'T',
                                'F',
                                'S',
                                'S',
                              ])
                                Expanded(child: Center(child: Text(label))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                ),
                            itemCount: ((days + offset) / 7).ceil() * 7,
                            itemBuilder: (context, index) {
                              final number = index - offset + 1;
                              if (number < 1 || number > days) {
                                return const SizedBox.shrink();
                              }
                              final date = DateTime(
                                state.month.year,
                                state.month.month,
                                number,
                              );
                              final count = state
                                  .forDay(space.id, person, date)
                                  .length;
                              final selected = date == state.selectedDay;
                              final today = date == dateOnly(DateTime.now());
                              return Semantics(
                                selected: selected,
                                button: true,
                                onTap: () => controller.selectDay(date),
                                label:
                                    '${MaterialLocalizations.of(context).formatFullDate(date)}, $count plans',
                                child: ExcludeSemantics(
                                  child: InkWell(
                                    onTap: () => controller.selectDay(date),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      margin: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: selected
                                            ? SoftPop.blue
                                            : count > 0
                                            ? SoftPop.blueSoft
                                            : SoftPop.surface,
                                        border: today
                                            ? Border.all(color: SoftPop.blue)
                                            : null,
                                        boxShadow: selected
                                            ? const [
                                                BoxShadow(
                                                  color: Color(0x33244BFF),
                                                  blurRadius: 6,
                                                  offset: Offset(0, 3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '$number',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: selected
                                                  ? Colors.white
                                                  : SoftPop.ink,
                                            ),
                                          ),
                                          if (count > 0)
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: selected
                                                    ? Colors.white
                                                    : SoftPop.blue,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
            Text(
              MaterialLocalizations.of(context)
                  .formatFullDate(state.selectedDay),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              calendarScope(space, person),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            if (plans.isEmpty)
              const Paper(
                child: Text(
                  'A little space in the day. Add something to look forward to.',
                ),
              ),
            for (final plan in plans)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Paper(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: MemberAvatar(space.member(plan.ownerId)),
                    title: Text(plan.title),
                    subtitle: Text(
                      '${personName(space, plan.ownerId)} · ${planTime(context, plan)}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showPlanDetails(context, ref, space, plan),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final now = DateTime.now();
                final isPast = dateOnly(state.selectedDay).isBefore(
                  dateOnly(now),
                );
                return FilledButton.icon(
                  onPressed: isPast
                      ? null
                      : () => showPlanEditor(context, space, state.selectedDay),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    isPast
                        ? 'Plans closed for past days'
                        : (person != null && person != space.currentUserId
                            ? 'Add my plan'
                            : 'Add plan'),
                  ),
                );
              },
            ),
            if (ref.read(sharedBackendProvider) case final backend?) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showGoogleCalendarImport(context, backend, space),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Import selected Google events'),
              ),
              if (GoogleCalendarImport.instance.lastRefreshed case final refreshed?)
                Text('Google refreshed ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(refreshed))}'),
            ],
          ],
        ),
      ),
    );
  }
}

String planTime(BuildContext context, CalendarPlan plan) {
  if (plan.allDay) return 'All day';
  final local = MaterialLocalizations.of(context);
  return '${local.formatTimeOfDay(TimeOfDay.fromDateTime(plan.localStart))} – ${local.formatTimeOfDay(TimeOfDay.fromDateTime(plan.localEnd))}';
}

String planDates(BuildContext context, CalendarPlan plan) {
  final local = MaterialLocalizations.of(context);
  final last = plan.allDay
      ? DateTime(plan.end.year, plan.end.month, plan.end.day - 1)
      : plan.localEnd;
  final firstLabel = local.formatMediumDate(plan.localStart);
  return dateOnly(plan.localStart) == dateOnly(last)
      ? firstLabel
      : '$firstLabel – ${local.formatMediumDate(last)}';
}

Future<void> showPlanDetails(
  BuildContext context,
  WidgetRef ref,
  Space space,
  CalendarPlan plan,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    title: Text(plan.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${personName(space, plan.ownerId)} · ${space.name}'),
          if (plan.isImported)
            const Text('Shared from Google Calendar · read-only here'),
          const SizedBox(height: 12),
          Text('${planDates(context, plan)} · ${planTime(context, plan)}'),
          if (plan.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(plan.note),
            ),
          if (plan.pin != null) ...[
            const SizedBox(height: 12),
            Text('At ${plan.pin!.label}'),
            if (plan.pin!.note.isNotEmpty) Text(plan.pin!.note),
            TextButton.icon(
              onPressed: () => ExternalLauncher.openMapDirections(
                dialogContext,
                query: plan.pin!.label,
                lat: plan.pin!.lat,
                lng: plan.pin!.lng,
              ),
              icon: const Icon(Icons.directions_outlined),
              label: const Text('Get directions'),
            ),
          ],
          if (plan.participants.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'With ${plan.participants.map((id) => personName(space, id)).join(', ')}',
              ),
            ),
        ],
      ),
    ),
    actions: [
      if (plan.ownerId == space.currentUserId && !plan.isImported)
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            showPlanEditor(context, space, plan.localStart, existing: plan);
          },
          child: const Text('Edit plan'),
        ),
      if (plan.ownerId == space.currentUserId)
        TextButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: dialogContext,
              builder: (c) => AlertDialog(
                title: const Text('Remove this plan?'),
                content: const Text(
                  'It will be removed from this space’s calendar.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Keep plan'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              try {
                await ref
                    .read(calendarRepositoryProvider)
                    .remove(plan.id, space.currentUserId);
                ref.read(calendarProvider.notifier).refresh();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (_) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Could not remove this plan. Try again.'),
                    ),
                  );
                }
              }
            }
          },
          child: Text(plan.isImported ? 'Unshare event' : 'Remove plan'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Close'),
      ),
    ],
  ),
);

Future<void> showPlanEditor(
  BuildContext context,
  Space space,
  DateTime day, {
  CalendarPlan? existing,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => PlanEditor(space: space, day: day, existing: existing),
);

class PlanEditor extends ConsumerStatefulWidget {
  const PlanEditor({
    super.key,
    required this.space,
    required this.day,
    this.existing,
  });
  final Space space;
  final DateTime day;
  final CalendarPlan? existing;
  @override
  ConsumerState<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends ConsumerState<PlanEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, note;
  late DateTime start, end;
  late bool allDay;
  late Set<String> participants;
  PlacePin? pin;
  String? error;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    title = TextEditingController(text: p?.title);
    note = TextEditingController(text: p?.note);
    allDay = p?.allDay ?? false;
    final today = dateOnly(DateTime.now());
    final dayDate = dateOnly(widget.day);
    final initialDay = p != null
        ? p.localStart
        : dayDate.isBefore(today)
            ? today
            : widget.day;
    start =
        p?.localStart ??
        DateTime(initialDay.year, initialDay.month, initialDay.day, 10);
    end = p == null
        ? start.add(const Duration(hours: 1))
        : p.allDay
        ? p.localEnd.subtract(const Duration(days: 1))
        : p.localEnd;
    participants = {...?p?.participants};
    pin = p?.pin;
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> pick(bool begin, bool time) async {
    final current = begin ? start : end;
    if (time) {
      final result = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (result != null && mounted) {
        setState(() {
          final value = DateTime(
            current.year,
            current.month,
            current.day,
            result.hour,
            result.minute,
          );
          if (begin) {
            start = value;
          } else {
            end = value;
          }
        });
      }
    } else {
      final today = dateOnly(DateTime.now());
      final result = await showDatePicker(
        context: context,
        initialDate: current.isBefore(today) ? today : current,
        firstDate: widget.existing == null ? today : DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (result != null && mounted) {
        setState(() {
          final value = DateTime(
            result.year,
            result.month,
            result.day,
            current.hour,
            current.minute,
          );
          if (begin) {
            start = value;
          } else {
            end = value;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SafeArea(
            top: false,
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.existing == null
                        ? 'Make a little plan'
                        : 'Edit your plan',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('Your calendar · ${widget.space.name}'),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: title,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Plan name'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Give your plan a name.'
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('All day'),
                    value: allDay,
                    onChanged: (v) => setState(() => allDay = v),
                  ),
                  for (final begin in [true, false]) ...[
                    Text(
                      begin ? 'Starts' : 'Ends',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    OutlinedButton.icon(
                      onPressed: () => pick(begin, false),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(local.formatMediumDate(begin ? start : end)),
                    ),
                    if (!allDay)
                      OutlinedButton.icon(
                        onPressed: () => pick(begin, true),
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text(
                          local.formatTimeOfDay(
                            TimeOfDay.fromDateTime(begin ? start : end),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (!allDay)
                    Text(
                      'Times shown in ${DateTime.now().timeZoneName} (this device).',
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Who’s joining? (optional)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final member in widget.space.members.where(
                    (m) => m.id != widget.space.currentUserId,
                  ))
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(member.name),
                      value: participants.contains(member.id),
                      onChanged: (v) => setState(() {
                        if (v!) {
                          participants.add(member.id);
                        } else {
                          participants.remove(member.id);
                        }
                      }),
                    ),
                  TextField(
                    controller: note,
                    maxLength: 300,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'A note (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: saving ? null : () async {
                      final selected = await showPlacePicker(context, initial: pin);
                      if (selected != null && mounted) setState(() => pin = selected);
                    },
                    icon: const Icon(Icons.place_outlined),
                    label: Text(pin?.label ?? 'Add place (optional)'),
                  ),
                  if (pin != null)
                    TextButton(
                      onPressed: () => setState(() => pin = null),
                      child: const Text('Remove place'),
                    ),
                  Paper(
                    color: SoftPop.blueSoft,
                    child: Text(
                      'Sharing with ${widget.space.name} · ${widget.space.members.length} members',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(liveRegion: true, child: Text(error!)),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            if (widget.existing == null &&
                                dateOnly(start).isBefore(
                                  dateOnly(DateTime.now()),
                                )) {
                              setState(
                                () => error =
                                    'Plans cannot be created in the past.',
                              );
                              return;
                            }
                            setState(() {
                              saving = true;
                              error = null;
                            });
                            try {
                              await ref
                                  .read(calendarRepositoryProvider)
                                  .save(
                                    id: widget.existing?.id,
                                    spaceId: widget.space.id,
                                    actorId: widget.space.currentUserId,
                                    title: title.text,
                                    start: start,
                                    end: allDay
                                        ? DateTime(
                                            end.year,
                                            end.month,
                                            end.day + 1,
                                          )
                                        : end,
                                    allDay: allDay,
                                    note: note.text,
                                    participants: participants.toList(),
                                    pin: pin,
                                  );
                              if (!context.mounted) return;
                              ref.read(calendarProvider.notifier).refresh();
                              Navigator.pop(context);
                            } on ArgumentError catch (e) {
                              if (mounted) {
                                setState(() => error = e.message.toString());
                              }
                            } on StateError catch (e) {
                              if (mounted) setState(() => error = e.message);
                            } catch (_) {
                              if (mounted) {
                                setState(
                                  () => error =
                                      'Could not save this plan. Try again.',
                                );
                              }
                            } finally {
                              if (mounted) setState(() => saving = false);
                            }
                          },
                    child: Text(
                      widget.existing == null ? 'Save plan' : 'Save changes',
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
