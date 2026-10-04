import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stewardie/online/verification_email.dart';

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
  int legacySends = 0;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'test-token';
  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    legacySends++;
  }
}

void main() {
  test(
    'known disabled custom sender preserves Firebase verification',
    () async {
      final user = _User('disabled');
      await http.runWithClient(
        () => VerificationEmail.send(user, customEnabled: true),
        () => MockClient((request) async {
          expect(jsonDecode(request.body).keys, ['operation']);
          return http.Response('{"code":"custom-email-disabled"}', 503);
        }),
      );
      expect(user.legacySends, 1);
    },
  );

  test('ambiguous timeout does not double-send through Firebase; retry keeps receipt', () async {
    final user = _User('timeout');
    String? operation;
    await http.runWithClient(
      () async {
        await expectLater(
          VerificationEmail.send(user, customEnabled: true),
          throwsA(isA<TimeoutException>()),
        );
        await expectLater(
          VerificationEmail.send(user, customEnabled: true),
          throwsA(isA<FirebaseAuthException>()),
        );
      },
      () => MockClient((request) async {
        final current = jsonDecode(request.body)['operation'] as String;
        if (operation == null) {
          operation = current;
          throw TimeoutException('network');
        }
        expect(current, operation);
        return http.Response(
          '{"error":"Delivery confirmation is pending."}',
          409,
        );
      }),
    );
    expect(user.legacySends, 0);
  });

  test('simultaneous send actions share one request', () async {
    final user = _User('coalesced');
    var requests = 0;
    final response = Completer<http.Response>();
    await http.runWithClient(
      () async {
        final first = VerificationEmail.send(user, customEnabled: true);
        final second = VerificationEmail.send(user, customEnabled: true);
        response.complete(http.Response('{"sent":true}', 200));
        await Future.wait([first, second]);
      },
      () => MockClient((request) {
        requests++;
        return response.future;
      }),
    );
    expect(requests, 1);
    expect(user.legacySends, 0);
  });
}
