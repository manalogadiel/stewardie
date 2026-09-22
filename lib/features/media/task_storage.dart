import '../timeline/domain/models.dart';

Map<String, Object?> taskToMap(Task t) => {
  'id': t.id,
  'spaceId': t.spaceId,
  'title': t.title,
  'day': t.day.toIso8601String(),
  'hour': t.hour,
  'minute': t.minute,
  'ownerId': t.ownerId,
  'requestedId': t.requestedId,
  'offeredId': t.offeredId,
  'creatorId': t.creatorId,
  'status': t.status.name,
  'notes': t.notes,
  'place': t.place,
  'participants': t.participants,
  'activity': t.activity,
  'completedAt': t.completedAt?.toIso8601String(),
};
Task taskFromMap(Map<String, Object?> m) => Task(
  id: m['id'] as String,
  spaceId: m['spaceId'] as String,
  title: m['title'] as String,
  day: DateTime.parse(m['day'] as String),
  hour: m['hour'] as int?,
  minute: m['minute'] as int,
  ownerId: m['ownerId'] as String?,
  requestedId: m['requestedId'] as String?,
  offeredId: m['offeredId'] as String?,
  creatorId: m['creatorId'] as String,
  status: Responsibility.values.byName(m['status'] as String),
  notes: m['notes'] as String,
  place: m['place'] as String?,
  participants: (m['participants'] as List).cast<String>(),
  activity: (m['activity'] as List).cast<String>(),
  completedAt: m['completedAt'] == null
      ? null
      : DateTime.parse(m['completedAt'] as String),
);
