import 'dart:convert';

import 'package:http/http.dart' as http;

const geoapifyKey = String.fromEnvironment('GEOAPIFY_API_KEY');

class PlaceSearchResult {
  const PlaceSearchResult(this.name, this.address, this.lat, this.lng);
  final String name, address;
  final double lat, lng;
}

Future<List<PlaceSearchResult>> searchPlaces(
  String text, {
  double? lat,
  double? lng,
  http.Client? client,
}) async {
  if (geoapifyKey.isEmpty || text.trim().length < 3) return [];
  final owned = client == null;
  final connection = client ?? http.Client();
  try {
    final response = await connection
        .get(
          Uri.https('api.geoapify.com', '/v1/geocode/autocomplete', {
            'text': text.trim(),
            'apiKey': geoapifyKey,
            'limit': '5',
            'lang': 'en',
            if (lat != null && lng != null) 'bias': 'proximity:$lng,$lat',
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Search unavailable. Tap the map instead.');
    }
    return parsePlaceResults(jsonDecode(response.body));
  } finally {
    if (owned) connection.close();
  }
}

List<PlaceSearchResult> parsePlaceResults(Object? body) {
  if (body is! Map || body['features'] is! List) return [];
  final results = <PlaceSearchResult>[];
  for (final feature in body['features'] as List) {
    if (feature is! Map || feature['properties'] is! Map) continue;
    final p = feature['properties'] as Map;
    final lat = p['lat'], lon = p['lon'];
    final name = p['name'] ?? p['address_line1'] ?? p['formatted'];
    if (lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        name is! String ||
        name.trim().isEmpty) {
      continue;
    }
    results.add(
      PlaceSearchResult(
        name.trim(),
        p['formatted'] as String? ?? name.trim(),
        lat.toDouble(),
        lon.toDouble(),
      ),
    );
  }
  return results;
}

Future<List<PlaceSearchResult>> nearbyPlaces(double lat, double lng) async {
  if (geoapifyKey.isEmpty) return [];
  final response = await http
      .get(
        Uri.https('api.geoapify.com', '/v2/places', {
          'apiKey': geoapifyKey,
          'categories':
              'commercial,catering,education,healthcare,accommodation',
          'filter': 'circle:$lng,$lat,60',
          'bias': 'proximity:$lng,$lat',
          'limit': '5',
          'lang': 'en',
        }),
      )
      .timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) return [];
  return parsePlaceResults(jsonDecode(response.body))
      .where((p) => p.name.isNotEmpty)
      .toList();
}
