import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import 'tutorial_state.dart';

/// Renders a small, self-contained, deterministic visual preview for each tutorial stop
/// using authentic app tokens and styling. Clearly labeled "Example", read-only, and
/// free of automatic cycling timers.
class TutorialExampleCard extends StatefulWidget {
  const TutorialExampleCard({
    super.key,
    required this.stopId,
  });

  final TutorialStopId stopId;

  @override
  State<TutorialExampleCard> createState() => _TutorialExampleCardState();
}

class _TutorialExampleCardState extends State<TutorialExampleCard> {
  // Deterministic task progression step for Stop 3 (Tasks)
  int _taskStep = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E5DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: SoftPop.blueSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Example',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: SoftPop.blue,
                  ),
                ),
              ),
              const Spacer(),
              if (widget.stopId == TutorialStopId.askCoverFinish)
                InkWell(
                  onTap: () {
                    setState(() => _taskStep = (_taskStep + 1) % 3);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded, size: 14, color: SoftPop.blue),
                        const SizedBox(width: 4),
                        Text(
                          _taskStep == 2 ? 'Replay' : 'Next state',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: SoftPop.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPreviewForStop(widget.stopId),
        ],
      ),
    );
  }

  Widget _buildPreviewForStop(TutorialStopId stopId) {
    return switch (stopId) {
      TutorialStopId.spaces => _buildSpacesPreview(),
      TutorialStopId.dayTogether => _buildTodayPreview(),
      TutorialStopId.askCoverFinish => _buildTasksPreview(),
      TutorialStopId.keepMoment => _buildMomentsPreview(),
      TutorialStopId.peopleRoutines => _buildSpacePreview(),
      TutorialStopId.placesSharing => _buildPlacesPreview(),
      TutorialStopId.updatesInbox => _buildNotificationsPreview(),
    };
  }

  /// 1. Spaces: mini selector preview with active space, and Create/Join actions.
  Widget _buildSpacesPreview() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SoftPop.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDDDE2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.radio_button_checked_rounded, color: SoftPop.blue, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Home',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: SoftPop.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SoftPop.blueSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SoftPop.blue),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: Color(0xFFEFEFEF)),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F5F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: SoftPop.ink),
                        SizedBox(width: 4),
                        Text('Create space', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F5F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_rounded, size: 14, color: SoftPop.ink),
                        SizedBox(width: 4),
                        Text('Join space', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Today: person chips (Everyone vs Alex) and actual mood & calendar mini cards.
  Widget _buildTodayPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SoftPop.blueSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SoftPop.blue),
              ),
              child: const Text(
                'Everyone',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: SoftPop.blue),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SoftPop.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDDDE2)),
              ),
              child: const Row(
                children: [
                  CircleAvatar(radius: 6, backgroundColor: SoftPop.rose),
                  SizedBox(width: 4),
                  Text('Alex', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SoftPop.ink)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SoftPop.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDDDE2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sentiment_satisfied_rounded, size: 14, color: SoftPop.blue),
                        SizedBox(width: 4),
                        Text('Alex · Calm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text('Shared mood (read-only)', style: TextStyle(fontSize: 9, color: SoftPop.secondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SoftPop.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDDDE2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 14, color: SoftPop.butter),
                        SizedBox(width: 4),
                        Text('Shared plans', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text('2 events scheduled', style: TextStyle(fontSize: 9, color: SoftPop.secondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 3. Tasks: Pending -> Covered -> Done sequence with explicit acceptance and photo option.
  Widget _buildTasksPreview() {
    final stateInfo = switch (_taskStep) {
      0 => (
        'Pending',
        'Needs someone',
        SoftPop.rose,
        Icons.radio_button_unchecked_rounded,
        "I'll do it",
        false,
      ),
      1 => (
        'Covered',
        'Covered by Alex',
        SoftPop.sky,
        Icons.schedule_rounded,
        'Mark done 📷',
        false,
      ),
      _ => (
        'Done',
        'Finished by Alex',
        const Color(0xFF2E7D32),
        Icons.check_circle_rounded,
        'Completed',
        true,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SoftPop.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDDDE2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(stateInfo.$4, size: 18, color: stateInfo.$3),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pick up groceries',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: stateInfo.$6 ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: stateInfo.$3.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  stateInfo.$1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: stateInfo.$3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                stateInfo.$2,
                style: const TextStyle(fontSize: 11, color: SoftPop.secondary),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stateInfo.$6 ? const Color(0xFFE8F5E9) : SoftPop.blue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  stateInfo.$5,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: stateInfo.$6 ? const Color(0xFF2E7D32) : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 4. Moments: authentic clay old-TV photo frame preview.
  Widget _buildMomentsPreview() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8EACF), Color(0xFFE4D3B4)],
        ),
        border: Border.all(color: const Color(0xFFFFF7EB), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x18202633), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF8B8378),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: SoftPop.ink,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_camera_rounded, color: Colors.white70, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Study session taco run · 2 ❤️',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              CircleAvatar(radius: 3, backgroundColor: SoftPop.blue),
              SizedBox(width: 6),
              Text(
                'Clay TV Moments Viewer',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SoftPop.ink),
              ),
              Spacer(),
              CircleAvatar(radius: 4, backgroundColor: Color(0xFF8B8378)),
            ],
          ),
        ],
      ),
    );
  }

  /// 5. Space: member card with Invite code and Routines action controls.
  Widget _buildSpacePreview() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SoftPop.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDDDE2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              CircleAvatar(radius: 12, backgroundColor: SoftPop.sky),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alex', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    Text('Space owner', style: TextStyle(color: SoftPop.secondary, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                  decoration: BoxDecoration(
                    color: SoftPop.blueSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_rounded, size: 14, color: SoftPop.blue),
                        SizedBox(width: 4),
                        Text('Invite code', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SoftPop.blue)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F4EE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.repeat_rounded, size: 14, color: SoftPop.ink),
                        SizedBox(width: 4),
                        Text('Routines', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SoftPop.ink)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 6. Map and places: visibly distinct fixed photo/task pin vs live sharing session.
  Widget _buildPlacesPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: SoftPop.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDDDE2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.place_rounded, color: SoftPop.blue, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Park picnic spot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    Text('Fixed photo/task pin', style: TextStyle(fontSize: 9, color: SoftPop.secondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: SoftPop.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDDDE2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.radar_rounded, color: Color(0xFFE65100), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live location session', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    Text('Explicit 15m · 30m · 60m manual sharing', style: TextStyle(fontSize: 9, color: SoftPop.secondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 7. Notifications: real inbox card for task updates.
  Widget _buildNotificationsPreview() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SoftPop.blueSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDDDE2)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: SoftPop.blue,
            child: Icon(Icons.check_rounded, color: Colors.white, size: 14),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task covered',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: SoftPop.ink),
                ),
                SizedBox(height: 1),
                Text(
                  'Home · Alex covered "Pick up groceries"',
                  style: TextStyle(fontSize: 10, color: SoftPop.secondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '10m',
            style: TextStyle(fontSize: 9, color: SoftPop.secondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
