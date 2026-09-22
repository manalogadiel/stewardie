import '../domain/models.dart';

abstract interface class TimelineRepository {
  List<Space> get spaces;
  List<Task> get tasks;
  Future<Task> act(String taskId, TaskAction action, String actorId);
  Task addTask(String spaceId, String title, DateTime day, bool assignToMe);
  CheckIn? checkIn(String spaceId, String memberId);
  void shareCheckIn(String spaceId, String memberId, Mood mood, String note);
  void removeCheckIn(String spaceId, String memberId);
}

class DemoException implements Exception {
  const DemoException(this.message);
  final String message;
}

/// In-memory fixtures only: no authentication, durable writes or remote sync.
class DemoRepository implements TimelineRepository {
  DemoRepository({
    DateTime Function()? clock,
    this.delay = const Duration(milliseconds: 500),
  }) : clock = clock ?? DateTime.now {
    _seed();
  }
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
        notes: 'An older unfinished task stays available on Basic.',
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
        throw const DemoException('The demo is signed in as Jamie only.');
      }
      if (outcome == DemoOutcome.failure) {
        throw const DemoException(
          'Simulated failure. Nothing changed. Try again.',
        );
      }
      if (outcome == DemoOutcome.conflict &&
          action == TaskAction.accept &&
          task.status == Responsibility.unclaimed) {
        _tasks[taskId] = task.transition(
          status: Responsibility.accepted,
          ownerId: 'alex',
          entry: 'Demo conflict: Alex claimed this task first.',
        );
        throw const DemoException(
          'Demo conflict: Alex claimed this first. The current owner is shown below.',
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
          entry: 'Jamie accepted responsibility in this demo.',
        ),
        TaskAction.decline => task.transition(
          status: Responsibility.unclaimed,
          entry: 'Jamie declined. The task is available to everyone.',
        ),
        TaskAction.complete => task.transition(
          status: Responsibility.completed,
          ownerId: task.ownerId,
          completedAt: clock(),
          entry: 'Jamie marked the task done in this demo.',
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
          entry:
              'Jamie confirmed the handoff to ${task.offeredId} in this demo.',
        ),
      };
      _tasks[taskId] = updated;
      return updated;
    } finally {
      _busy.remove(taskId);
    }
  }

  @override
  Task addTask(String spaceId, String title, DateTime day, bool assignToMe) {
    if (title.trim().isEmpty) {
      throw const DemoException('Give your task a name.');
    }
    final task = Task(
      id: 'local-${_nextId++}',
      spaceId: spaceId,
      title: title.trim(),
      day: dateOnly(day),
      ownerId: assignToMe ? 'me' : null,
      status: assignToMe ? Responsibility.accepted : Responsibility.unclaimed,
      activity: ['Jamie added this task in the local demo.'],
    );
    _tasks[task.id] = task;
    return task;
  }

  @override
  CheckIn? checkIn(String spaceId, String memberId) {
    final mood = _moods['$spaceId/$memberId'];
    return mood != null && mood.isCurrent(clock()) ? mood : null;
  }

  @override
  void shareCheckIn(String spaceId, String memberId, Mood mood, String note) {
    final now = clock();
    _moods['$spaceId/$memberId'] = CheckIn(
      mood,
      note.trim(),
      now,
      DateTime(now.year, now.month, now.day + 1),
    );
  }

  @override
  void removeCheckIn(String spaceId, String memberId) =>
      _moods.remove('$spaceId/$memberId');
}
