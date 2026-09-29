import 'package:sembast/sembast.dart';

import '../mascot_stage.dart';
import 'tutorial_target_registry.dart';

enum TutorialStatus {
  notStarted,
  inProgress,
  skipped,
  completed,
}

enum TutorialStopId {
  spaces,
  dayTogether,
  askCoverFinish,
  keepMoment,
  peopleRoutines,
  placesSharing,
  updatesInbox,
}

class TutorialStopData {
  const TutorialStopData({
    required this.id,
    required this.title,
    required this.explanation,
    required this.pose,
    required this.targetKeyGetter,
    required this.destinationTab,
  });

  final TutorialStopId id;
  final String title;
  final String explanation;
  final MascotPose pose;
  final String Function() targetKeyGetter;
  final int destinationTab; // 0: Today, 1: Moments, 2: Space
}

class TutorialStops {
  const TutorialStops._();

  static const List<TutorialStopData> all = [
    TutorialStopData(
      id: TutorialStopId.spaces,
      title: 'Your spaces',
      explanation: 'Keep each group in its own space. Switch, create, or join here.',
      pose: MascotPose.butterWelcome,
      targetKeyGetter: TutorialTargetRegistry.spacesKey,
      destinationTab: 0,
    ),
    TutorialStopData(
      id: TutorialStopId.dayTogether,
      title: 'Your day, together',
      explanation: 'Everyone brings the space together. Choose a person to see their mood and plans.',
      pose: MascotPose.attentive,
      targetKeyGetter: TutorialTargetRegistry.dayTogetherKey,
      destinationTab: 0,
    ),
    TutorialStopData(
      id: TutorialStopId.askCoverFinish,
      title: 'Ask, cover, finish',
      explanation: 'Add something that needs doing. Members can accept it, ask for help, and mark it done.',
      pose: MascotPose.butterTask,
      targetKeyGetter: TutorialTargetRegistry.tasksKey,
      destinationTab: 0,
    ),
    TutorialStopData(
      id: TutorialStopId.keepMoment,
      title: 'Keep a moment',
      explanation: 'Share a photo, or add one when you finish a task. Completion photos appear here too.',
      pose: MascotPose.roseCamera,
      targetKeyGetter: TutorialTargetRegistry.momentsTabKey,
      destinationTab: 1,
    ),
    TutorialStopData(
      id: TutorialStopId.peopleRoutines,
      title: 'Your people and routines',
      explanation: 'Bring people in and organize repeating tasks.',
      pose: MascotPose.mintCalendar,
      targetKeyGetter: TutorialTargetRegistry.spaceTabKey,
      destinationTab: 2,
    ),
    TutorialStopData(
      id: TutorialStopId.placesSharing,
      title: 'Places and sharing',
      explanation: 'Photo pins mark a fixed place. Live location is separate: choose who can see it and for how long.',
      pose: MascotPose.skyKey,
      targetKeyGetter: TutorialTargetRegistry.mapButtonKey,
      destinationTab: 0,
    ),
    TutorialStopData(
      id: TutorialStopId.updatesInbox,
      title: 'Updates in one place',
      explanation: 'Find task requests and updates from your spaces here.',
      pose: MascotPose.makeItYours,
      targetKeyGetter: TutorialTargetRegistry.notificationBellKey,
      destinationTab: 0,
    ),
  ];
}

class TutorialStore {
  TutorialStore(this.database);

  final Database? database;
  static final _store = stringMapStoreFactory.store('tutorial_state_v1');

  static String _key(String uid) => 'tutorial_$uid';

  Future<TutorialStatus> getStatus(String uid) async {
    final db = database;
    if (db == null || uid.isEmpty) return TutorialStatus.skipped;
    final record = await _store.record(_key(uid)).get(db);
    final statusStr = record?['status'] as String?;
    return switch (statusStr) {
      'inProgress' => TutorialStatus.inProgress,
      'skipped' => TutorialStatus.skipped,
      'completed' => TutorialStatus.completed,
      _ => TutorialStatus.notStarted,
    };
  }

  Future<void> setStatus(String uid, TutorialStatus status) async {
    final db = database;
    if (db == null || uid.isEmpty) return;
    final existing = await _store.record(_key(uid)).get(db) ?? <String, dynamic>{};
    final updated = Map<String, dynamic>.from(existing);
    updated['status'] = status.name;
    updated['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await _store.record(_key(uid)).put(db, updated);
  }

  Future<int> getCurrentStopIndex(String uid) async {
    final db = database;
    if (db == null || uid.isEmpty) return 0;
    final record = await _store.record(_key(uid)).get(db);
    return record?['stopIndex'] as int? ?? 0;
  }

  Future<void> setCurrentStopIndex(String uid, int index) async {
    final db = database;
    if (db == null || uid.isEmpty) return;
    final existing = await _store.record(_key(uid)).get(db) ?? <String, dynamic>{};
    final updated = Map<String, dynamic>.from(existing);
    updated['stopIndex'] = index;
    await _store.record(_key(uid)).put(db, updated);
  }

  Future<void> clear(String uid) async {
    final db = database;
    if (db == null || uid.isEmpty) return;
    await _store.record(_key(uid)).delete(db);
  }
}
