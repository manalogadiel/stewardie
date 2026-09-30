import 'package:sembast/sembast.dart' hide FieldValue;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../online/online_backend.dart';

import '../mascot_stage.dart';
import 'tutorial_target_registry.dart';

enum TutorialStatus {
  notStarted,
  inProgress,
  awaitingSpace,
  skipped,
  completed,
}

enum TutorialStopId {
  spaces,
  dayTogether,
  mood,
  calendar,
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
      explanation:
          'Keep each group in its own space. Switch, create, or join here.',
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
      id: TutorialStopId.mood,
      title: 'How are you today?',
      explanation: 'Check in with your mood. Choose another person to see their mood without changing it.',
      pose: MascotPose.attentive,
      targetKeyGetter: TutorialTargetRegistry.moodKey,
      destinationTab: 0,
    ),
    TutorialStopData(
      id: TutorialStopId.calendar,
      title: 'Make room for your plans',
      explanation: 'See shared plans for everyone or one person. Open the calendar and choose a month or year to look ahead.',
      pose: MascotPose.mintCalendar,
      targetKeyGetter: TutorialTargetRegistry.calendarKey,
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
  TutorialStore(this.database, {this.backend});

  final Database? database;
  final OnlineBackend? backend;
  static final _store = stringMapStoreFactory.store('tutorial_state_v1');

  static String _key(String uid) => 'tutorial_$uid';

  Future<TutorialStatus> getStatus(String uid) async {
    final db = database;
    if (db == null || uid.isEmpty) return TutorialStatus.skipped;
    final record = await _store.record(_key(uid)).get(db);
    if (backend != null) {
      if (backend!.auth.currentUser?.uid != uid) return TutorialStatus.skipped;
      try {
        final remote = await backend!.firestore
            .doc('accounts/$uid/tutorial/state')
            .get(const GetOptions(source: Source.server));
        final remoteStatus = remote.data()?['status'] as String?;
        if (remoteStatus == 'completed' || remoteStatus == 'skipped') {
          final status = remoteStatus == 'completed'
              ? TutorialStatus.completed
              : TutorialStatus.skipped;
          await _store.record(_key(uid)).put(db, {
            ...?record,
            'status': status.name,
          });
          return status;
        }
        if (record?['status'] == 'completed' ||
            record?['status'] == 'skipped') {
          final status = record!['status'] == 'completed'
              ? TutorialStatus.completed
              : TutorialStatus.skipped;
          await setStatus(uid, status);
          return status;
        }
        if (remoteStatus != null)
          return TutorialStatus.values.firstWhere(
            (s) => s.name == remoteStatus,
            orElse: () => TutorialStatus.skipped,
          );
      } catch (_) {
        return TutorialStatus.skipped;
      }
    }
    final statusStr = record?['status'] as String?;
    return switch (statusStr) {
      'inProgress' => TutorialStatus.inProgress,
      'awaitingSpace' => TutorialStatus.awaitingSpace,
      'skipped' => TutorialStatus.skipped,
      'completed' => TutorialStatus.completed,
      _ => TutorialStatus.notStarted,
    };
  }

  Future<void> setStatus(String uid, TutorialStatus status) async {
    final db = database;
    if (db == null || uid.isEmpty) return;
    final existing =
        await _store.record(_key(uid)).get(db) ?? <String, dynamic>{};
    final updated = Map<String, dynamic>.from(existing);
    updated['status'] = status.name;
    updated['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await _store.record(_key(uid)).put(db, updated);
    if (backend?.auth.currentUser?.uid == uid) {
      try {
        await backend!.firestore.doc('accounts/$uid/tutorial/state').set({
          'status': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        /* Local terminal status still prevents repeat prompts. */
      }
    }
  }

  Future<int> getCurrentStopIndex(String uid) async {
    final db = database;
    if (db == null || uid.isEmpty) return 0;
    final record = await _store.record(_key(uid)).get(db);
    final id = record?['stopId'];
    if (id is String) {
      final index = TutorialStops.all.indexWhere((s) => s.id.name == id);
      return index < 0 ? 0 : index;
    }
    const legacy = [0, 1, 4, 5, 6, 7, 8];
    final old = record?['stopIndex'] as int? ?? 0;
    return legacy[old.clamp(0, legacy.length - 1)];
  }

  Future<void> setCurrentStopIndex(String uid, int index) async {
    final db = database;
    if (db == null || uid.isEmpty) return;
    final existing =
        await _store.record(_key(uid)).get(db) ?? <String, dynamic>{};
    final updated = Map<String, dynamic>.from(existing);
    updated['stopIndex'] = index;
    updated['stopId'] =
        TutorialStops.all[index.clamp(0, TutorialStops.all.length - 1)].id.name;
    await _store.record(_key(uid)).put(db, updated);
  }

  Future<void> clear(String uid) async {
    final db = database;
    if (db == null || uid.isEmpty) return;
    await _store.record(_key(uid)).delete(db);
  }
}
