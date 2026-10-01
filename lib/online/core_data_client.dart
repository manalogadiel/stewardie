import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

class CoreDataException implements Exception {
  const CoreDataException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

/// Firebase identity with Supabase persistence. Never silently falls back to
/// Firestore: one feature must have one authoritative writer during cutover.
class CoreDataClient {
  CoreDataClient({required this.idToken, http.Client? client})
    : _client = client ?? http.Client();
  final Future<String?> Function() idToken;
  final http.Client _client;
  final _reads =
      <
        ({
          String action,
          Map<String, dynamic> payload,
          Completer<Map<String, dynamic>> result,
        })
      >[];
  Timer? _readTimer;

  /// Coalesce simultaneous screen readers into one authenticated request.
  Future<Map<String, dynamic>> read(
    String action,
    Map<String, dynamic> payload,
  ) {
    final result = Completer<Map<String, dynamic>>();
    _reads.add((action: action, payload: payload, result: result));
    _readTimer ??= Timer(const Duration(milliseconds: 8), () async {
      final reads = List.of(_reads);
      _reads.clear();
      _readTimer = null;
      try {
        if (reads.length == 1) {
          reads.single.result.complete(
            await call(reads.single.action, reads.single.payload),
          );
          return;
        }
        for (var offset = 0; offset < reads.length; offset += 100) {
          final batch = reads.skip(offset).take(100).toList();
          final response = await call('docReadBatch', {
            'reads': [
              for (final r in batch) {'action': r.action, 'payload': r.payload},
            ],
          });
          final results = response['results'] as List;
          if (results.length != batch.length) {
            throw const CoreDataException('Invalid shared-data response.', 503);
          }
          for (var i = 0; i < batch.length; i++) {
            final row = results[i] as Map;
            if (row['error'] is String) {
              batch[i].result.completeError(
                CoreDataException(row['error'] as String, row['status'] as int),
              );
            } else {
              batch[i].result.complete(
                Map<String, dynamic>.from(row['data'] as Map),
              );
            }
          }
        }
      } catch (error, stack) {
        for (final r in reads) {
          if (!r.result.isCompleted) r.result.completeError(error, stack);
        }
      }
    });
    return result.future;
  }

  static const endpoint = String.fromEnvironment(
    'SUPABASE_CORE_URL',
    defaultValue:
        'https://ulexhxfxatzlobabitpr.supabase.co/functions/v1/core-data',
  );

  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> payload = const {},
  ]) async {
    final token = await idToken();
    if (token == null || token.isEmpty) {
      throw const CoreDataException('Sign in again.', 401);
    }
    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'action': action, 'payload': payload}),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const CoreDataException(
        'Waiting for connection. Retry shortly.',
        503,
      );
    } on http.ClientException {
      throw const CoreDataException(
        'Waiting for connection. Retry shortly.',
        503,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const CoreDataException(
        'Shared data is temporarily unavailable.',
        503,
      );
    }
    if (response.statusCode != 200) {
      throw CoreDataException(
        decoded is Map && decoded['error'] is String
            ? decoded['error'] as String
            : 'Could not save. Please retry.',
        response.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const CoreDataException('Invalid shared-data response.', 503);
    }
    return decoded;
  }

  void close() => _client.close();
}
