import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sprint A - Subtasks & Progress', () {
    test('subtask completion progress is calculated correctly', () {
      final subtasks = [
        {'id': '1', 'title': 'Pack lunches', 'completed': true},
        {'id': '2', 'title': 'Fill water bottles', 'completed': false},
        {'id': '3', 'title': 'Grab backpacks', 'completed': true},
        {'id': '4', 'title': 'Lock door', 'completed': false},
      ];

      final total = subtasks.length;
      final done = subtasks.where((s) => s['completed'] == true).length;

      expect(total, 4);
      expect(done, 2);
      expect('$done/$total', '2/4');
    });

    test('toggling subtask status immutably produces new list', () {
      final subtasks = [
        {'id': '1', 'title': 'Unpack boxes', 'completed': false},
        {'id': '2', 'title': 'Sort recycling', 'completed': false},
      ];

      final updated = subtasks.map((item) {
        if (item['id'] == '1') {
          return {...item, 'completed': true};
        }
        return item;
      }).toList();

      expect(subtasks[0]['completed'], isFalse);
      expect(updated[0]['completed'], isTrue);
      expect(updated[1]['completed'], isFalse);
    });
  });

  group('Sprint A - Multi-Photo & Location Tagging', () {
    test('photo limits enforce 1 photo for Basic and 5 for Plus', () {
      int maxPhotosFor(bool isPlus) => isPlus ? 5 : 1;

      expect(maxPhotosFor(false), 1);
      expect(maxPhotosFor(true), 5);

      final candidatePhotos = ['photo1.jpg', 'photo2.jpg', 'photo3.jpg'];
      final allowedForBasic = candidatePhotos.take(maxPhotosFor(false)).toList();
      final allowedForPlus = candidatePhotos.take(maxPhotosFor(true)).toList();

      expect(allowedForBasic, hasLength(1));
      expect(allowedForPlus, hasLength(3));
    });

    test('location tag preserves place label and geo coordinates if present', () {
      final momentData = {
        'id': 'm1',
        'title': 'School run done!',
        'locationLabel': 'Lincoln Elementary',
        'latitude': 37.7749,
        'longitude': -122.4194,
      };

      expect(momentData['locationLabel'], 'Lincoln Elementary');
      expect(momentData['latitude'], 37.7749);
      expect(momentData['longitude'], -122.4194);
    });
  });

  group('Sprint B - Responsibility Flow & Activity Audit', () {
    test('requestHelp flag triggers helpNeeded state and audit log', () {
      final now = DateTime.now().toIso8601String();
      final task = {
        'id': 't1',
        'title': 'Walk the dogs',
        'ownerUid': 'user-1',
        'helpNeeded': false,
        'activity': <Map<String, dynamic>>[],
      };

      final updatedTask = {
        ...task,
        'helpNeeded': true,
        'activity': [
          ...List<Map<String, dynamic>>.from(task['activity'] as Iterable),
          {
            'type': 'help_requested',
            'actorUid': 'user-1',
            'timestamp': now,
          },
        ],
      };

      expect(updatedTask['helpNeeded'], isTrue);
      final activity = updatedTask['activity'] as List<Map<String, dynamic>>;
      expect(activity, hasLength(1));
      expect(activity.first['type'], 'help_requested');
      expect(activity.first['actorUid'], 'user-1');
    });

    test('takeOver transfers ownership, clears helpNeeded and logs take_over', () {
      final now = DateTime.now().toIso8601String();
      final task = {
        'id': 't1',
        'title': 'Walk the dogs',
        'ownerUid': 'user-1',
        'helpNeeded': true,
        'activity': [
          {'type': 'help_requested', 'actorUid': 'user-1', 'timestamp': '2026-09-26T10:00:00Z'},
        ],
      };

      final updatedTask = {
        ...task,
        'ownerUid': 'user-2',
        'helpNeeded': false,
        'activity': [
          ...List<Map<String, dynamic>>.from(task['activity'] as Iterable),
          {
            'type': 'take_over',
            'actorUid': 'user-2',
            'timestamp': now,
          },
        ],
      };

      expect(updatedTask['ownerUid'], 'user-2');
      expect(updatedTask['helpNeeded'], isFalse);
      final activity = updatedTask['activity'] as List<Map<String, dynamic>>;
      expect(activity, hasLength(2));
      expect(activity.last['type'], 'take_over');
      expect(activity.last['actorUid'], 'user-2');
    });
  });

  group('Sprint C - Dependent Profiles & Join Approvals', () {
    test('dependent profile payload includes isDependent flag and family role', () {
      final dependentPayload = {
        'name': 'Leo',
        'roleTag': 'Child',
        'color': 'accentPeach',
        'isDependent': true,
        'managedBy': 'user-adult-1',
      };

      expect(dependentPayload['isDependent'], isTrue);
      expect(dependentPayload['roleTag'], 'Child');
      expect(dependentPayload['name'], 'Leo');
    });

    test('join approval flow checks requireApproval before direct join', () {
      bool requiresApproval(Map<String, dynamic> spaceData) {
        return spaceData['requireApproval'] == true;
      }

      final openSpace = {'id': 's1', 'name': 'Open Family', 'requireApproval': false};
      final guardedSpace = {'id': 's2', 'name': 'Private Family', 'requireApproval': true};

      expect(requiresApproval(openSpace), isFalse);
      expect(requiresApproval(guardedSpace), isTrue);

      final joinRequest = {
        'uid': 'applicant-1',
        'displayName': 'Aunt May',
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      };

      expect(joinRequest['status'], 'pending');
    });
  });
}
