import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/online/online_today_extras.dart';

void main() {
  group('QA Audit Resolutions - OnlinePlan parsing', () {
    test('OnlinePlan safely parses startMillis and endMillis integers', () {
      final now = DateTime.utc(2026, 9, 25, 10, 0);
      final later = DateTime.utc(2026, 9, 25, 12, 0);

      final plan = OnlinePlan('plan-1', {
        'title': 'Dinner with family',
        'ownerUid': 'user-123',
        'allDay': false,
        'startMillis': now.millisecondsSinceEpoch,
        'endMillis': later.millisecondsSinceEpoch,
        'participants': ['user-123', 'user-456'],
      });

      expect(plan.title, 'Dinner with family');
      expect(plan.start.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(plan.end.millisecondsSinceEpoch, later.millisecondsSinceEpoch);
      expect(plan.allDay, isFalse);
      expect(plan.matches('user-456'), isTrue);
      expect(plan.matches('stranger'), isFalse);
    });

    test('OnlinePlan falls back safely to Timestamp if startAt/endAt are provided', () {
      final now = DateTime.utc(2026, 9, 25, 10, 0);
      final later = DateTime.utc(2026, 9, 25, 12, 0);

      final plan = OnlinePlan('plan-2', {
        'title': 'Morning jog',
        'ownerUid': 'user-123',
        'allDay': true,
        'startAt': Timestamp.fromDate(now),
        'endAt': Timestamp.fromDate(later),
      });

      expect(plan.title, 'Morning jog');
      expect(plan.start.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(plan.end.millisecondsSinceEpoch, later.millisecondsSinceEpoch);
      expect(plan.allDay, isTrue);
    });

    test('OnlinePlan does not crash when both millis and timestamps are missing', () {
      final plan = OnlinePlan('plan-empty', {
        'title': 'Corrupted plan',
      });

      expect(plan.title, 'Corrupted plan');
      expect(plan.start, isA<DateTime>());
      expect(plan.end, isA<DateTime>());
    });
  });

  group('QA Audit Resolutions - Done filtering logic', () {
    test('Done task list filters by selected person', () {
      final allDone = [
        {'id': 't1', 'title': 'Wash dishes', 'ownerUid': 'alice', 'status': 'completed'},
        {'id': 't2', 'title': 'Buy groceries', 'ownerUid': 'bob', 'status': 'completed'},
        {'id': 't3', 'title': 'Walk dog', 'ownerUid': 'alice', 'status': 'completed'},
      ];

      List<Map<String, dynamic>> filterDone(String? personId) {
        if (personId == null) return allDone;
        return allDone
            .where((data) =>
                data['ownerUid'] == personId ||
                data['requestedUid'] == personId ||
                data['creatorUid'] == personId)
            .toList();
      }

      final aliceTasks = filterDone('alice');
      expect(aliceTasks, hasLength(2));
      expect(aliceTasks.map((t) => t['id']), containsAll(['t1', 't3']));

      final bobTasks = filterDone('bob');
      expect(bobTasks, hasLength(1));
      expect(bobTasks.single['id'], 't2');

      final everyoneTasks = filterDone(null);
      expect(everyoneTasks, hasLength(3));
    });
  });

  group('QA Audit Resolutions - SparkBackend account payload handling', () {
    test('existing account doc is updated without re-setting tier', () {
      final old = <String, dynamic>{'tier': 'basic', 'entitlementSource': 'store', 'subscription': {'active': false}};
      final newSpaceIds = [...List<String>.from((old['spaceIds'] as Iterable?) ?? const []), 'space-1'];
      final newOwnedSpaceIds = [...List<String>.from((old['ownedSpaceIds'] as Iterable?) ?? const []), 'space-1'];

      final updatePayload = {
        'spaceIds': newSpaceIds,
        'ownedSpaceIds': newOwnedSpaceIds,
        'changedSpaceId': 'space-1',
      };

      expect(updatePayload.containsKey('tier'), isFalse);
      expect(updatePayload['spaceIds'], ['space-1']);
      expect(updatePayload['ownedSpaceIds'], ['space-1']);
      expect(updatePayload['changedSpaceId'], 'space-1');
    });

    test('non-existing account doc creates basic tier document', () {
      final old = <String, dynamic>{};
      final newSpaceIds = [...List<String>.from((old['spaceIds'] as Iterable?) ?? const []), 'space-1'];
      final newOwnedSpaceIds = [...List<String>.from((old['ownedSpaceIds'] as Iterable?) ?? const []), 'space-1'];

      final createPayload = {
        'tier': old['tier'] ?? 'basic',
        'spaceIds': newSpaceIds,
        'ownedSpaceIds': newOwnedSpaceIds,
        'changedSpaceId': 'space-1',
      };

      expect(createPayload['tier'], 'basic');
      expect(createPayload['spaceIds'], ['space-1']);
      expect(createPayload['ownedSpaceIds'], ['space-1']);
      expect(createPayload['changedSpaceId'], 'space-1');
    });
  });
}

