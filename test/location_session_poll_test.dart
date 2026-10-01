import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stewardie/online/location_session_poll.dart';

void main() {
  test(
    'closing during a request prevents further polling and delivery',
    () async {
      final pending = Completer<List<Map<String, dynamic>>>();
      int reads = 0;
      final values = <List<Map<String, dynamic>>>[];
      final sub = pollLocationSessions(() {
        reads++;
        return pending.future;
      }, interval: const Duration(milliseconds: 5)).listen(values.add);
      await sub.cancel();
      pending.complete([
        {'uid': 'alice'},
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(reads, 1);
      expect(values, isEmpty);
    },
  );
  test('revoked access ends polling rather than repeatedly retrying', () async {
    int reads = 0;
    final errors = <Object>[];
    final sub = pollLocationSessions(
      () async {
        reads++;
        throw StateError('Space access ended.');
      },
      interval: const Duration(milliseconds: 5),
      stopOnError: (_) => true,
    ).listen((_) {}, onError: errors.add);
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(reads, 1);
    expect(errors, hasLength(1));
    await sub.cancel();
  });
}
