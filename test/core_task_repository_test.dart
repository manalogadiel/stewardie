import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stewardie/online/core_data_client.dart';
import 'package:stewardie/online/core_task_repository.dart';

void main() {
  test(
    'full task page carries cursor and metadata cannot replace trusted columns',
    () async {
      var requests = 0;
      final client = CoreDataClient(
        idToken: () async => 'token',
        client: MockClient((request) async {
          final payload = (jsonDecode(request.body) as Map)['payload'] as Map;
          if (++requests == 2) {
            expect(payload['beforeId'], 'real-id');
            expect(payload['beforeTime'], '2026-10-01T00:00:00Z');
            return http.Response('{"tasks":[]}', 200);
          }
          return http.Response(
            jsonEncode({
              'tasks': [
                {
                  'id': 'real-id',
                  'spaceId': 'space',
                  'version': 7,
                  'updatedAt': '2026-10-01T00:00:00Z',
                  'status': 'requested',
                  'details': {
                    'id': 'fake',
                    'version': 999,
                    'status': 'completed',
                    'note': 'Keep me',
                    'pin': {'lat': 13, 'lng': 121},
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      final repo = CoreTaskRepository(client);
      final first = await repo.list('space', limit: 1);
      expect(first.tasks.single['id'], 'real-id');
      expect(first.tasks.single['version'], 7);
      expect(first.tasks.single['status'], 'requested');
      expect(first.tasks.single['notes'], 'Keep me');
      expect(first.tasks.single['pin']['lat'], 13);
      final second = await repo.list(
        'space',
        limit: 1,
        beforeId: first.nextId,
        beforeTime: first.nextTime,
      );
      expect(second.tasks, isEmpty);
      expect(second.nextId, isNull);
      client.close();
    },
  );
  test(
    'edits carry version and stable operation; conflicts are surfaced',
    () async {
      var attempts = 0;
      final client = CoreDataClient(
        idToken: () async => 'token',
        client: MockClient((request) async {
          attempts++;
          final body = jsonDecode(request.body) as Map;
          expect(body['action'], 'updateTask');
          expect(body['payload']['expectedVersion'], 7);
          expect(body['payload']['operationId'], 'same-retry');
          expect(body['payload']['patch']['subtasks'][0]['done'], true);
          return http.Response(
            '{"error":"This task changed. Refresh before retrying"}',
            409,
          );
        }),
      );
      await expectLater(
        CoreTaskRepository(client).update(
          spaceId: 'space',
          taskId: 'task',
          expectedVersion: 7,
          operationId: 'same-retry',
          patch: {
            'subtasks': [
              {'title': 'Rinse', 'done': true},
            ],
          },
        ),
        throwsA(
          isA<CoreDataException>().having((e) => e.statusCode, 'status', 409),
        ),
      );
      expect(attempts, 1);
      client.close();
    },
  );
  test(
    'malformed task response is rejected instead of inventing task identity',
    () async {
      final client = CoreDataClient(
        idToken: () async => 'token',
        client: MockClient(
          (_) async => http.Response('{"task":{"title":"Broken"}}', 200),
        ),
      );
      await expectLater(
        CoreTaskRepository(client).get('space', 'task'),
        throwsA(isA<CoreDataException>()),
      );
      client.close();
    },
  );
}
