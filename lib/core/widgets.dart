import 'package:flutter/material.dart';

import '../features/timeline/domain/models.dart';
import 'theme.dart';

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 32),
  });
  final List<Widget> children;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(padding: padding, children: children),
    ),
  );
}

class Paper extends StatelessWidget {
  const Paper({
    super.key,
    required this.child,
    this.color = SoftPop.surface,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.member, {super.key, this.size = 32});
  final Member member;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SoftPop.members[member.colorIndex],
        borderRadius: BorderRadius.circular(size * .38),
      ),
      child: Text(
        member.initials,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: SoftPop.ink,
          fontWeight: FontWeight.w800,
          fontSize: size * .4,
        ),
      ),
    ),
  );
}

class StatusLabel extends StatelessWidget {
  const StatusLabel(this.task, {super.key});
  final Task task;
  @override
  Widget build(BuildContext context) {
    final (icon, label) = task.isEvent
        ? (Icons.people_outline_rounded, 'Shared event')
        : switch (task.status) {
            Responsibility.unclaimed => (
              Icons.person_add_alt_rounded,
              'Needs someone',
            ),
            Responsibility.requested => (
              Icons.schedule_rounded,
              'Awaiting acceptance',
            ),
            Responsibility.accepted => (
              Icons.check_circle_outline_rounded,
              'Accepted',
            ),
            Responsibility.needsHelp => (
              Icons.front_hand_outlined,
              task.offeredId == null ? 'Could use a hand' : 'Handoff pending',
            ),
            Responsibility.completed => (Icons.check_circle_rounded, 'Done'),
          };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: SoftPop.secondary),
        const SizedBox(width: 6),
        Flexible(child: Text(label)),
      ],
    );
  }
}

// Original scalable face placeholders. Replace with approved production vectors.
class MoodFace extends StatelessWidget {
  const MoodFace(this.mood, {super.key, this.size = 44});
  final Mood mood;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _FacePainter(mood)),
  );
}

class _FacePainter extends CustomPainter {
  const _FacePainter(this.mood);
  final Mood mood;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64);
    final fill = Paint()..color = SoftPop.members[mood.index % 3];
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 2, 60, 60),
        const Radius.circular(24),
      ),
      fill,
    );
    final line = Paint()
      ..color = SoftPop.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = SoftPop.ink;
    for (final x in [22.0, 42.0]) {
      if (mood == Mood.calm || mood == Mood.tired) {
        canvas.drawLine(Offset(x - 3, 28), Offset(x + 3, 28), line);
      } else if (mood == Mood.overwhelmed) {
        canvas.drawLine(Offset(x - 3, 25), Offset(x + 3, 31), line);
        canvas.drawLine(Offset(x - 3, 31), Offset(x + 3, 25), line);
      } else {
        canvas.drawCircle(Offset(x, 27), 2.5, dot);
      }
    }
    if (mood == Mood.excited) {
      canvas.drawOval(const Rect.fromLTWH(26, 37, 12, 13), dot);
    } else {
      final mouth = Path()
        ..moveTo(25, mood == Mood.sad ? 44 : 40)
        ..quadraticBezierTo(
          32,
          mood == Mood.sad
              ? 34
              : mood == Mood.tired || mood == Mood.overwhelmed
              ? 40
              : 49,
          39,
          mood == Mood.sad ? 44 : 40,
        );
      canvas.drawPath(mouth, line);
    }
  }

  @override
  bool shouldRepaint(_FacePainter oldDelegate) => oldDelegate.mood != mood;
}

String personName(Space space, String? id) => id == null
    ? 'Not claimed yet'
    : id == space.currentUserId
    ? 'You'
    : space.member(id).name;

String taskTime(BuildContext context, Task task) => task.hour == null
    ? 'Anytime'
    : MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay(hour: task.hour!, minute: task.minute));

Future<void> showFeatureNote(
  BuildContext context,
  String title,
  String message,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Got it'),
      ),
    ],
  ),
);
