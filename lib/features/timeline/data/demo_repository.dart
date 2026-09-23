import 'dart:async';

import '../domain/models.dart';

abstract class TimelineRepository {
  String get currentUserId => 'me';
  bool get isShared => false;
  bool get isPlus => false;
  Stream<void> get changes => const Stream.empty();
  bool canView(Task task) => visibleToBasic(task, DateTime.now());
  DateTime todayInSpace(String spaceId) => dateOnly(DateTime.now());
  List<Space> get spaces;
  List<Task> get tasks;
  Future<Task> act(String taskId, TaskAction action, String actorId);
  Future<Task> addTask(
    String spaceId,
    String title,
    DateTime day,
    bool assignToMe,
  );
  CheckIn? checkIn(String spaceId, String memberId);
  FutureOr<void> shareCheckIn(
    String spaceId,
    String memberId,
    Mood mood,
    String note, {
    MoodColor color = MoodColor.sky,
  });
  FutureOr<void> removeCheckIn(String spaceId, String memberId);
}

class DemoException implements Exception {
  const DemoException(this.message);
  final String message;
}

/// Fixture spaces and identity with optional durable task writes; no remote sync.
class DemoRepository extends TimelineRepository {
  DemoRepository({
    DateTime Function()? clock,
    this.delay = const Duration(milliseconds: 500),
    this.persist,
    List<Task> restored = const [],
  }) : clock = clock ?? DateTime.now {
    _seed();
    _tasks.addEntries(restored.map((t) => MapEntry(t.id, t)));
  }
  final Future<void> Function(Task)? persist;
  final DateTime Function() clock;
  final Duration delay;
  DemoOutcome nextOutcome = DemoOutcome.success;
  final Map<String, CheckIn> _moods = {};
  final Map<String, Task> _tasks = {};
  final Set<String> _busy = {};
  int _nextId = 0;

  @override
  final List<Space> spaces = const [
    Space('home', 'Home crew', 'Housemates', [
      Member('me', 'Jamie (you)', 'J', 0),
      Member('alex', 'Alex', 'A', 1),
      Member('sam', 'Sam', 'S', 2),
      Member('jo', 'Jo María Santos', 'JM', 0),
    ]),
    Space('weekend', 'Weekend wandering crew', 'Friends', [
      Member('me', 'Jamie (you)', 'J', 0),
      Member('lee', 'Lee', 'L', 2),
    ]),
  ];

  void _seed() {
    final today = dateOnly(clock());
    final fixtures = [
      Task(
        id: 'supplies',
        spaceId: 'home',
        title: 'Pick up a few supplies',
        day: today,
        hour: 15,
        ownerId: 'alex',
        status: Responsibility.accepted,
        place: 'Corner store',
        notes: 'Dish soap and a fresh kitchen sponge.',
        activity: ['Jamie created the task.', 'Alex accepted responsibility.'],
      ),
      Task(
        id: 'groceries',
        spaceId: 'home',
        title: 'Groceries for the week',
        day: today,
        hour: 16,
        ownerId: 'sam',
        status: Responsibility.needsHelp,
        notes: 'Oats, tomatoes, rice, and something green. Running a little late today.',
        activity: ['Sam accepted responsibility.', 'Sam asked for help.'],
      ),
      Task(
        id: 'dinner',
        spaceId: 'home',
        title: 'Make something good',
        day: today,
        hour: 18,
        ownerId: 'me',
        status: Responsibility.accepted,
        notes: 'A simple dinner for four. There is pasta in the cupboard.',
        activity: ['Jamie accepted responsibility.'],
      ),
      Task(
        id: 'walk',
        spaceId: 'home',
        title: 'A little evening walk',
        day: today,
        hour: 19,
        participants: ['me', 'alex', 'jo'],
        notes: 'Meet by the gate. Come along if you feel like it.',
      ),
      Task(
        id: 'plants',
        spaceId: 'home',
        title: 'Water the balcony plants',
        day: today,
        requestedId: 'me',
        status: Responsibility.requested,
        creatorId: 'jo',
        activity: ['Jo requested Jamie. Awaiting acceptance.'],
      ),
      Task(
        id: 'recycling',
        spaceId: 'home',
        title: 'Take out the recycling',
        day: today.subtract(const Duration(days: 5)),
        notes: 'Rinse the bottles and leave the bag by the gate.',
      ),
      Task(
        id: 'laundry',
        spaceId: 'home',
        title: 'Bring in the laundry',
        day: today,
        ownerId: 'me',
        offeredId: 'alex',
        status: Responsibility.needsHelp,
        activity: [
          'Jamie asked for help.',
          'Alex offered to take over. Awaiting Jamie.',
        ],
      ),
      Task(
        id: 'breakfast',
        spaceId: 'home',
        title: 'Breakfast, all tidied up',
        day: today,
        hour: 8,
        ownerId: 'jo',
        status: Responsibility.completed,
        completedAt: today.add(const Duration(hours: 9)),
        activity: ['Jo marked the task done.'],
      ),
    ];
    _tasks.addEntries(fixtures.map((task) => MapEntry(task.id, task)));
    final now = clock();
    final expires = DateTime(now.year, now.month, now.day + 1);
    _moods['home/alex'] = CheckIn(
      Mood.calm,
      'Taking a quiet moment.',
      now,
      expires,
      color: MoodColor.rose,
    );
    _moods['home/sam'] = CheckIn(
      Mood.excited,
      'Looking forward to tonight.',
      now,
      expires,
      color: MoodColor.butter,
    );
  }

  @override
  List<Task> get tasks => List.unmodifiable(_tasks.values);

  @override
  Future<Task> act(String taskId, TaskAction action, String actorId) async {
    if (!_busy.add(taskId)) {
      throw const DemoException('This task already has a pending action.');
    }
    final outcome = nextOutcome;
    nextOutcome = DemoOutcome.success;
    try {
      await Future<void>.delayed(delay);
      final task = _tasks[taskId];
      if (task == null || task.isEvent) {
        throw const DemoException('This task is unavailable.');
      }
      if (actorId != 'me') {
        throw const DemoException('You can only act as yourself.');
      }
      if (outcome == DemoOutcome.failure) {
        throw const DemoException(
          'Could not save. Nothing changed. Try again.',
        );
      }
      if (outcome == DemoOutcome.conflict &&
          action == TaskAction.accept &&
          task.status == Responsibility.unclaimed) {
        final other = spaces
            .firstWhere((space) => space.id == task.spaceId)
            .members
            .firstWhere((member) => member.id != actorId);
        _tasks[taskId] = task.transition(
          status: Responsibility.accepted,
          ownerId: other.id,
          entry: '${other.name} claimed this task first.',
        );
        throw DemoException(
          '${other.name} claimed this first. The current owner is shown below.',
        );
      }
      final allowed = switch (action) {
        TaskAction.accept =>
          task.status == Responsibility.unclaimed ||
              (task.status == Responsibility.requested &&
                  task.requestedId == actorId),
        TaskAction.decline =>
          task.status == Responsibility.requested &&
              task.requestedId == actorId,
        TaskAction.complete =>
          task.ownerId == actorId &&
              (task.status == Responsibility.accepted ||
                  task.status == Responsibility.needsHelp),
        TaskAction.needHelp =>
          task.ownerId == actorId && task.status == Responsibility.accepted,
        TaskAction.offerHelp =>
          task.ownerId != actorId &&
              task.status == Responsibility.needsHelp &&
              task.offeredId == null,
        TaskAction.confirmHandoff =>
          task.ownerId == actorId &&
              task.status == Responsibility.needsHelp &&
              task.offeredId != null,
      };
      if (!allowed) {
        throw const DemoException(
          'This action is no longer available. Review the current responsibility.',
        );
      }
      final updated = switch (action) {
        TaskAction.accept => task.transition(
          status: Responsibility.accepted,
          ownerId: actorId,
          entry: 'Jamie accepted responsibility.',
        ),
        TaskAction.decline => task.transition(
          status: Responsibility.unclaimed,
          entry: 'Jamie declined. The task is available to everyone.',
        ),
        TaskAction.complete => task.transition(
          status: Responsibility.completed,
          ownerId: task.ownerId,
          completedAt: clock(),
          entry: 'Jamie marked the task done.',
        ),
        TaskAction.needHelp => task.transition(
          status: Responsibility.needsHelp,
          ownerId: task.ownerId,
          entry: 'Jamie asked for help. Responsibility stays with Jamie.',
        ),
        TaskAction.offerHelp => task.transition(
          status: Responsibility.needsHelp,
          ownerId: task.ownerId,
          offeredId: actorId,
          entry: 'Jamie offered help. Awaiting the current owner.',
        ),
        TaskAction.confirmHandoff => task.transition(
          status: Responsibility.accepted,
          ownerId: task.offeredId,
          entry: 'Jamie confirmed the handoff to ${task.offeredId}.',
        ),
      };
      await persist?.call(updated);
      _tasks[taskId] = updated;
      return updated;
    } finally {
      _busy.remove(taskId);
    }
  }

  @override
  Future<Task> addTask(
    String spaceId,
    String title,
    DateTime day,
    bool assignToMe,
  ) async {
    if (title.trim().isEmpty) {
      throw const DemoException('Give your task a name.');
    }
    final task = Task(
      id: 'local-${clock().microsecondsSinceEpoch}-${_nextId++}',
      spaceId: spaceId,
      title: title.trim(),
      day: dateOnly(day),
      requestedId: assignToMe ? 'me' : null,
      status: assignToMe ? Responsibility.requested : Responsibility.unclaimed,
      activity: ['Jamie added this task.'],
    );
    await persist?.call(task);
    _tasks[task.id] = task;
    return task;
  }

  @override
  CheckIn? checkIn(String spaceId, String memberId) {
    final mood = _moods['$spaceId/$memberId'];
    return mood != null && mood.isCurrent(clock()) ? mood : null;
  }

  @override
  void shareCheckIn(
    String spaceId,
    String memberId,
    Mood mood,
    String note, {
    MoodColor color = MoodColor.sky,
  }) {
    if (memberId != 'me' ||
        !spaces.any(
          (s) => s.id == spaceId && s.members.any((m) => m.id == 'me'),
        )) {
      throw const DemoException('You can only change your own check-in.');
    }
    final now = clock();
    _moods['$spaceId/$memberId'] = CheckIn(
      mood,
      note.trim(),
      now,
      DateTime(now.year, now.month, now.day + 1),
      color: color,
    );
  }

  @override
  void removeCheckIn(String spaceId, String memberId) {
    if (memberId != 'me') {
      throw const DemoException('You can only change your own check-in.');
    }
    _moods.remove('$spaceId/$memberId');
  }
}
