import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stewardie/online/core_data_client.dart';

void main() {
  test('offline transport remains retryable without another backend', () async {
    final client = CoreDataClient(
      idToken: () async => 'token',
      client: MockClient((_) async => throw http.ClientException('Offline')),
    );
    await expectLater(
      client.call('createSpace', {'operationId': 'stable-retry'}),
      throwsA(
        isA<CoreDataException>().having((e) => e.statusCode, 'status', 503),
      ),
    );
    client.close();
  });
  test(
    'simultaneous reads share one request and keep access errors isolated',
    () async {
      var count = 0;
      final client = CoreDataClient(
        idToken: () async => 'token',
        client: MockClient((r) async {
          count++;
          expect(jsonDecode(r.body)['action'], 'docReadBatch');
          return http.Response(
            '{"results":[{"data":{"data":{"name":"Home"}}},{"error":"Access ended","status":403}]}',
            200,
          );
        }),
      );
      final first = client.read('docRead', {'path': 'spaces/s'});
      final denied = client.read('docRead', {'path': 'spaces/other'});
      await expectLater(denied, throwsA(isA<CoreDataException>()));
      expect((await first)['data']['name'], 'Home');
      expect(count, 1);
      client.close();
    },
  );
  test('core transport uses Firebase token, preserves operation and server space ID', () async {
    final client = CoreDataClient(
      idToken: () async => 'verified-token',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer verified-token');
        final body = jsonDecode(request.body) as Map;
        expect(body.containsKey('uid'), isFalse);
        expect(body['payload']['operationId'], 'stable-operation');
        return http.Response('{"spaceId":"existing-space-id"}', 200);
      }),
    );
    expect(
      (await client.call('createSpace', {
        'name': 'Home',
        'operationId': 'stable-operation',
      }))['spaceId'],
      'existing-space-id',
    );
    client.close();
  });
  test('access failure is surfaced without another backend or retry', () async {
    var calls = 0;
    final client = CoreDataClient(
      idToken: () async => 'token',
      client: MockClient((_) async {
        calls++;
        return http.Response('{"error":"Space access ended"}', 403);
      }),
    );
    await expectLater(
      client.call('listTasks', {'spaceId': 'private'}),
      throwsA(
        isA<CoreDataException>().having((e) => e.statusCode, 'status', 403),
      ),
    );
    expect(calls, 1);
    client.close();
  });
  test('signed-out requests never reach the gateway', () async {
    final client = CoreDataClient(
      idToken: () async => null,
      client: MockClient((_) async => throw StateError('Must not call')),
    );
    await expectLater(
      client.call('listSpaces'),
      throwsA(
        isA<CoreDataException>().having((e) => e.statusCode, 'status', 401),
      ),
    );
    client.close();
  });
}
