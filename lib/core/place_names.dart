import 'dart:convert';

import 'package:http/http.dart' as http;

import 'stewardie_map.dart';

/// Names only the fixed point the member selected, never a live-sharing session.
Future<String> nameForPlace(double lat, double lng) async {
  if (mapTilerKey.isNotEmpty) {
    try {
      final response = await http
          .get(
            Uri.https('api.maptiler.com', '/geocoding/$lng,$lat.json', {
              'key': mapTilerKey,
              'language': 'en',
              'limit': '1',
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final features = body['features'] as List? ?? [];
        if (features.isNotEmpty) {
          final value = features.first['place_name'] ?? features.first['text'];
          if (value is String && value.trim().isNotEmpty)
            return String.fromCharCodes(value.trim().runes.take(80));
        }
      }
    } catch (_) {
      /* A fixed pin remains usable offline, honestly named by coordinates. */
    }
  }
  return 'Pinned location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
}
