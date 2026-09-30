import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'theme.dart';
import 'stewardie_map.dart';

/// A fixed, explicitly shared place. It never represents a live session.
class PlacePin {
  const PlacePin({
    required this.lat,
    required this.lng,
    required this.label,
    this.note = '',
    this.source = 'manual',
    this.accuracy,
    this.locatedAt,
  });
  final double lat, lng;
  final String label, note, source;
  final double? accuracy;
  final DateTime? locatedAt;

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'label': label.trim(),
    'note': note.trim(),
    'source': source,
    if (accuracy != null) 'accuracy': accuracy,
    if (locatedAt != null) 'locatedAt': locatedAt!.toUtc().toIso8601String(),
  };

  static PlacePin? fromMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final lat = raw['lat'], lng = raw['lng'];
    if (lat is! num || lng is! num) {
      return null;
    }
    if (!lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }
    return PlacePin(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      label: raw['label'] as String? ?? 'Pinned place',
      note: raw['note'] as String? ?? '',
      source: raw['source'] as String? ?? 'manual',
      accuracy: (raw['accuracy'] as num?)?.toDouble(),
      locatedAt: DateTime.tryParse(raw['locatedAt'] as String? ?? ''),
    );
  }
}

Future<PlacePin?> showPlacePicker(BuildContext context, {PlacePin? initial}) =>
    showModalBottomSheet<PlacePin>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _PlacePicker(initial: initial),
    );

class _PlacePicker extends StatefulWidget {
  const _PlacePicker({this.initial});
  final PlacePin? initial;
  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  final controller = MapController();
  bool _mapReady = false;
  bool _pendingCenter = false;
  late final label = TextEditingController(text: widget.initial?.label);
  late final note = TextEditingController(text: widget.initial?.note);
  LatLng? point;
  String? error;
  StewardieMapStyle style = mapTilerKey.isEmpty
      ? StewardieMapStyle.streets
      : StewardieMapStyle.satellite;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      point = LatLng(widget.initial!.lat, widget.initial!.lng);
    }
  }

  @override
  void dispose() {
    label.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> useCurrent() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission is off. Tap the map instead.');
      }
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() {
        point = LatLng(fix.latitude, fix.longitude);
        error = null;
      });
      if (_mapReady) {
        controller.move(point!, 15);
      } else {
        _pendingCenter = true;
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not find your location. Tap the map instead.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = point;
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final height =
        (media.size.height - media.viewInsets.bottom - media.padding.top - 56)
            .clamp(0.0, media.size.height * .77)
            .toDouble();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + media.viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Text(
              'Choose a place',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap the map to place a fixed pin. This will be visible to your space.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: keyboardOpen
                  ? 160
                  : (media.size.height * .38).clamp(180, 360).toDouble(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: StewardieMap(
                  controller: controller,
                  onReady: () {
                    _mapReady = true;
                    if (_pendingCenter && point != null) {
                      controller.move(point!, 15);
                      _pendingCenter = false;
                    }
                  },
                  center: p ?? const LatLng(12, 122),
                  zoom: p == null ? 5 : 14,
                  style: style,
                  onStyleChanged: (value) => setState(() => style = value),
                  onTap: (_, position) => setState(() {
                    point = position;
                    _pendingCenter = false;
                    error = null;
                  }),
                  markers: [
                    if (p != null)
                      Marker(
                        point: p,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.place_rounded,
                          color: SoftPop.blue,
                          size: 42,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: useCurrent,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Center on me'),
              ),
            ),
            TextField(
              controller: label,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Place name'),
            ),
            TextField(
              controller: note,
              maxLength: 180,
              decoration: const InputDecoration(
                labelText: 'Location note (optional)',
              ),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: p == null
                  ? null
                  : () {
                      if (label.text.trim().isEmpty) {
                        setState(() => error = 'Name this place.');
                        return;
                      }
                      Navigator.pop(
                        context,
                        PlacePin(
                          lat: p.latitude,
                          lng: p.longitude,
                          label: label.text.trim(),
                          note: note.text.trim(),
                        ),
                      );
                    },
              child: const Text('Use this place'),
            ),
          ],
        ),
      ),
    );
  }
}
