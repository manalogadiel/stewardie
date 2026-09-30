import 'package:flutter/material.dart';

import 'theme.dart';

DateTime clampCalendarMonth(DateTime date) {
  final now = DateTime.now();
  final first = DateTime(now.year - 100);
  final last = DateTime(now.year + 20, 12);
  final month = DateTime(date.year, date.month);
  return month.isBefore(first)
      ? first
      : month.isAfter(last)
      ? last
      : month;
}

DateTime calendarDayInMonth(DateTime month, int day) => DateTime(
  month.year,
  month.month,
  day.clamp(1, DateTime(month.year, month.month + 1, 0).day),
);

class MonthYearButton extends StatelessWidget {
  const MonthYearButton({
    super.key,
    required this.month,
    required this.onSelected,
  });
  final DateTime month;
  final ValueChanged<DateTime> onSelected;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      backgroundColor: SoftPop.surface,
      foregroundColor: SoftPop.ink,
      minimumSize: const Size(48, 48),
      shape: const StadiumBorder(),
    ),
    icon: const Icon(Icons.calendar_month_rounded, size: 20),
    label: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(MaterialLocalizations.of(context).formatMonthYear(month)),
        const Icon(Icons.expand_more_rounded),
      ],
    ),
    onPressed: () async {
      final chosen = await showModalBottomSheet<DateTime>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _MonthYearSheet(initial: month),
      );
      if (chosen != null && context.mounted) onSelected(chosen);
    },
  );
}

class _MonthYearSheet extends StatefulWidget {
  const _MonthYearSheet({required this.initial});
  final DateTime initial;
  @override
  State<_MonthYearSheet> createState() => _MonthYearSheetState();
}

class _MonthYearSheetState extends State<_MonthYearSheet> {
  late DateTime choice = clampCalendarMonth(widget.initial);
  static const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .8,
    ),
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose month and year',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: choice.year,
            decoration: const InputDecoration(labelText: 'Year'),
            menuMaxHeight: 280,
            items: List.generate(121, (index) {
              final year = DateTime.now().year - 100 + index;
              return DropdownMenuItem(value: year, child: Text('$year'));
            }),
            onChanged: (year) {
              if (year != null) {
                setState(() => choice = DateTime(year, choice.month));
              }
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, size) {
              final columns = MediaQuery.textScalerOf(context).scale(16) > 24
                  ? 2
                  : 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  12,
                  (index) => SizedBox(
                    width: (size.maxWidth - (columns - 1) * 8) / columns,
                    child: TextButton(
                      onPressed: () => setState(
                        () => choice = DateTime(choice.year, index + 1),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: choice.month == index + 1
                            ? SoftPop.blueSoft
                            : SoftPop.surface,
                        foregroundColor: choice.month == index + 1
                            ? SoftPop.blue
                            : SoftPop.ink,
                      ),
                      child: Text(months[index]),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context, choice),
            child: const Text('Show month'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}
