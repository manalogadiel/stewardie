import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stewardie/online/core_data_client.dart';
import 'package:stewardie/online/core_space_repository.dart';

void main() {
  for (final action in ['createSpace', 'joinSpace']) {
    test(
      '$action selects exactly the server-returned space after success',
      () async {
        var selected = 'old-space';
        final client = CoreDataClient(
          idToken: () async => 'token',
          client: MockClient((request) async {
            expect(selected, 'old-space');
            final body = jsonDecode(request.body) as Map;
            expect(body['action'], action);
            expect(body['payload']['operationId'], 'stable');
            return http.Response('{"spaceId":"new-space"}', 200);
          }),
        );
        final repo = CoreSpaceRepository(client);
        final id = action == 'createSpace'
            ? await repo.createAndSelect(
                name: 'Home',
                displayName: 'Diel',
                operationId: 'stable',
                selectSpace: (id) {
                  selected = id;
                },
              )
            : await repo.joinAndSelect(
                code: 'ABCDEFGHJK',
                displayName: 'Diel',
                operationId: 'stable',
                selectSpace: (id) {
                  selected = id;
                },
              );
        expect(id, 'new-space');
        expect(selected, 'new-space');
        client.close();
      },
    );
  }
  test(
    'failed create never changes selection; retry uses the same operation',
    () async {
      var attempt = 0;
      var selected = 'old';
      final client = CoreDataClient(
        idToken: () async => 'token',
        client: MockClient((request) async {
          expect(
            (jsonDecode(request.body) as Map)['payload']['operationId'],
            'retry-id',
          );
          return ++attempt == 1
              ? http.Response('{"error":"Retry"}', 503)
              : http.Response('{"spaceId":"new"}', 200);
        }),
      );
      final repo = CoreSpaceRepository(client);
      Future<String> create() => repo.createAndSelect(
        name: 'Home',
        displayName: 'Diel',
        operationId: 'retry-id',
        selectSpace: (id) {
          selected = id;
        },
      );
      await expectLater(create(), throwsA(isA<CoreDataException>()));
      expect(selected, 'old');
      await create();
      expect(selected, 'new');
      client.close();
    },
  );
  test(
    'approval request stays pending and does not use the direct join action',
    () async {
      final client = CoreDataClient(
        idToken: () async => 'token',
        client: MockClient((request) async {
          expect([
            'requestJoin',
            'joinSpace',
          ], contains((jsonDecode(request.body) as Map)['action']));
          return http.Response(
            '{"spaceId":"pending-space","pending":true}',
            200,
          );
        }),
      );
      final repo = CoreSpaceRepository(client);
      expect(
        (await repo.requestJoin(
          code: 'ABCDEFGHJK',
          displayName: 'Diel',
          operationId: 'request',
        ))['pending'],
        true,
      );
      await expectLater(
        repo.joinAndSelect(
          code: 'ABCDEFGHJK',
          displayName: 'Diel',
          operationId: 'direct',
          selectSpace: (_) => fail('Must not select'),
        ),
        throwsA(isA<CoreDataException>()),
      );
      client.close();
    },
  );
}
