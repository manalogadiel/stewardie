import '../../../core/place_pin.dart';
import '../../../core/sync_state.dart';

enum Responsibility { unclaimed, requested, accepted, needsHelp, completed }

enum TaskAction {
  accept,
  decline,
  complete,
  needHelp,
  offerHelp,
  confirmHandoff,
}

enum DemoOutcome { success, failure, conflict }

class Member {
  const Member(
    this.id,
    this.name,
    this.initials,
    this.colorIndex, {
    this.preferredName,
  });
  final String id, name, initials;
  final String? preferredName;
  final int colorIndex;
}

class Space {
  const Space(
    this.id,
    this.name,
    this.kind,
    this.members, {
    this.currentUserId = 'me',
    this.timeZone = 'UTC',
  });
  final String id, name, kind;
  final String currentUserId;
  final String timeZone;
  final List<Member> members;
  Member member(String id) => members.firstWhere(
    (member) => member.id == id,
    orElse: () => Member(id, 'Former member', '?', 0),
  );
}

class Task {
  const Task({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.day,
    this.hour,
    this.minute = 0,
    this.ownerId,
    this.requestedId,
    this.offeredId,
    this.creatorId = 'me',
    this.status = Responsibility.unclaimed,
    this.notes = '',
    this.place,
    this.pin,
    this.participants = const [],
    this.activity = const [],
    this.completedAt,
    this.completedLocalDay,
    this.syncState = SyncState.synced,
  });
  final String id, spaceId, title, creatorId, notes;
  final DateTime day;
  final int? hour;
  final int minute;
  final String? ownerId, requestedId, offeredId, place;
  final PlacePin? pin;
  final Responsibility status;
  final List<String> participants, activity;
  final DateTime? completedAt;
  final DateTime? completedLocalDay;
  final SyncState syncState;
  bool get isEvent => participants.isNotEmpty;
  bool get isDone => status == Responsibility.completed;
  bool matchesPerson(String? id) =>
      id == null ||
      ownerId == id ||
      requestedId == id ||
      participants.contains(id);

  Task transition({
    required Responsibility status,
    String? ownerId,
    String? requestedId,
    String? offeredId,
    required String entry,
    DateTime? completedAt,
  }) => Task(
    id: id,
    spaceId: spaceId,
    title: title,
    day: day,
    hour: hour,
    minute: minute,
    creatorId: creatorId,
    notes: notes,
    place: place,
    pin: pin,
    participants: participants,
    status: status,
    ownerId: ownerId,
    requestedId: requestedId,
    offeredId: offeredId,
    completedAt: completedAt,
    activity: [...activity, entry],
  );
}

enum Mood { happy, calm, tired, overwhelmed, sad, excited }

enum MoodColor { sky, butter, rose }

extension MoodColorLabel on MoodColor {
  String get label => switch (this) {
    MoodColor.sky => 'Sky',
    MoodColor.butter => 'Butter',
    MoodColor.rose => 'Rose',
  };
}

extension MoodLabel on Mood {
  String get label => switch (this) {
    Mood.happy => 'Happy',
    Mood.calm => 'Calm',
    Mood.tired => 'Tired',
    Mood.overwhelmed => 'Overwhelmed',
    Mood.sad => 'Sad',
    Mood.excited => 'Excited',
  };
}

class CheckIn {
  const CheckIn(
    this.mood,
    this.note,
    this.sharedAt,
    this.expiresAt, {
    this.color = MoodColor.sky,
  });
  final Mood mood;
  final MoodColor color;
  final String note;
  final DateTime sharedAt, expiresAt;
  bool isCurrent(DateTime now) => now.isBefore(expiresAt);
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

// Demo uses the device's local day. Production needs a named space time zone.
bool visibleToBasic(Task task, DateTime now) =>
    !task.isDone ||
    (task.completedAt != null &&
        !dateOnly(task.completedAt!)
            .isBefore(DateTime(now.year, now.month, now.day - 3)));
