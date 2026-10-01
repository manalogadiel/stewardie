import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stewardie/online/core_data_client.dart';
import 'package:stewardie/online/core_firestore.dart';
import 'package:stewardie/online/live_location_service.dart';

void main() {
  test('sharing accepts both gateway ISO dates and SDK timestamps', () {
    final time = DateTime.utc(2026, 10, 1, 12);
    expect(sharingExpiry(time.toIso8601String()), time);
    expect(sharingExpiry(Timestamp.fromDate(time)), time);
    expect(sharingExpiry(null), isNull);
  });
  test(
    'document adapter decodes time and filters typed queries without Firestore',
    () async {
      final client = CoreDataClient(
        idToken: () async => 'token',
        client: MockClient((r) async {
          final request = jsonDecode(r.body);
          expect(request['action'], 'docList');
          return http.Response(
            jsonEncode({
              'rows': [
                {
                  'id': 'active',
                  'data': {
                    'status': 'accepted',
                    'updatedAt': '2026-10-01T00:00:00Z',
                  },
                },
                {
                  'id': 'done',
                  'data': {'status': 'completed'},
                },
              ],
            }),
            200,
          );
        }),
      );
      final store = CoreFirestore(client);
      final rows = await store
          .collection('spaces/s/tasks')
          .where('status', isNotEqualTo: 'completed')
          .get();
      expect(rows.docs.single.id, 'active');
      expect(rows.docs.single.data()['updatedAt'], isA<Timestamp>());
      client.close();
      await store.changes.close();
    },
  );
  test('batch keeps writes atomic and encodes SDK server timestamps', () async {
    final client = CoreDataClient(
      idToken: () async => 'token',
      client: MockClient((r) async {
        final request = jsonDecode(r.body);
        expect(request['action'], 'docBatch');
        expect(request['payload']['writes'][0]['data']['updatedAt'], {
          '_serverTime': true,
        });
        expect(request['payload']['writes'][1]['mode'], 'delete');
        return http.Response('{"ok":true}', 200);
      }),
    );
    final store = CoreFirestore(client), batch = CoreFirestore(client).batch();
    batch.set(store.doc('accounts/u/notificationPrefs/global'), {
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(store.doc('profiles/u'));
    await batch.commit();
    client.close();
    await store.changes.close();
  });
}
