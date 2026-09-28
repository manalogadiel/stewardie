import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public tile key supplied at build time. The free key is not an account secret.
const mapTilerKey = String.fromEnvironment('MAPTILER_KEY');

enum StewardieMapStyle { satellite, streets }

class StewardieMap extends StatefulWidget {
  const StewardieMap({
    super.key,
    required this.center,
    required this.zoom,
    this.controller,
    this.markers = const [],
    this.onTap,
    this.onReady,
    this.onUserInteraction,
    this.style = StewardieMapStyle.satellite,
  });

  final LatLng center;
  final double zoom;
  final MapController? controller;
  final List<Marker> markers;
  final void Function(TapPosition, LatLng)? onTap;
  final VoidCallback? onReady;
  final VoidCallback? onUserInteraction;
  final StewardieMapStyle style;

  @override
  State<StewardieMap> createState() => _StewardieMapState();
}

class _StewardieMapState extends State<StewardieMap> {
  bool failed = false;
  int retry = 0;

  bool get satellite =>
      widget.style == StewardieMapStyle.satellite && mapTilerKey.isNotEmpty;

  String get url => satellite
      ? 'https://api.maptiler.com/maps/satellite/256/{z}/{x}/{y}.jpg?key=$mapTilerKey'
      : mapTilerKey.isNotEmpty
      ? 'https://api.maptiler.com/maps/streets-v4/256/{z}/{x}/{y}.png?key=$mapTilerKey'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  void didUpdateWidget(covariant StewardieMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style) failed = false;
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Listener(
        onPointerDown: (_) => widget.onUserInteraction?.call(),
        child: FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
            minZoom: 2,
            maxZoom: 18,
            onTap: widget.onTap,
            onMapReady: widget.onReady,
          ),
          children: [
            TileLayer(
              key: ValueKey('$url-$retry'),
              urlTemplate: url,
              userAgentPackageName: 'dev.stewardie.app',
              errorTileCallback: (_, __, ___) {
                if (!failed && mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => failed = true);
                  });
                }
              },
            ),
            MarkerLayer(markers: widget.markers),
          ],
        ),
      ),
      Positioned(
        left: 8,
        bottom: 8,
        child: InkWell(
          onTap: () => launchUrl(
            Uri.parse(
              mapTilerKey.isEmpty
                  ? 'https://www.openstreetmap.org/copyright'
                  : 'https://www.maptiler.com/copyright/',
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              child: Text(
                mapTilerKey.isEmpty
                    ? '© OpenStreetMap contributors'
                    : 'MapTiler · © OpenStreetMap contributors',
                style: const TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ),
          ),
        ),
      ),
      if (failed)
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Map tiles unavailable. Check connection or try Streets.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() { failed = false; retry++; }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
