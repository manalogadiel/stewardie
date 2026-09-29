import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public tile key supplied at build time. The free key is not an account secret.
// MapTiler client keys are public. Keep the pilot key as the plain flutter run
// default; release builds can override it with --dart-define=MAPTILER_KEY=... .
const mapTilerKey = String.fromEnvironment(
  'MAPTILER_KEY',
  defaultValue: '7uwMZ6Idub8CZM4AXzAR',
);

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
    this.onStyleChanged,
    this.style = StewardieMapStyle.satellite,
  });

  final LatLng center;
  final double zoom;
  final MapController? controller;
  final List<Marker> markers;
  final void Function(TapPosition, LatLng)? onTap;
  final VoidCallback? onReady;
  final VoidCallback? onUserInteraction;
  final ValueChanged<StewardieMapStyle>? onStyleChanged;
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
      if (widget.onStyleChanged != null)
        Positioned(
          top: 12,
          right: 12,
          child: MapLayersButton(
            selected: widget.style,
            onSelected: widget.onStyleChanged!,
          ),
        ),
      if (mapTilerKey.isNotEmpty)
        Positioned(
          left: 8,
          bottom: 8,
          child: InkWell(
            onTap: () => launchUrl(Uri.parse('https://www.maptiler.com/')),
            child: Semantics(
              label: 'MapTiler logo',
              link: true,
              child: Image.network(
                'https://media.maptiler.com/old/mediakit/logo/maptiler-logo.png',
                width: 72,
                height: 22,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'MapTiler',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      Positioned(
        right: 8,
        bottom: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mapTilerKey.isNotEmpty)
                InkWell(
                  onTap: () => launchUrl(
                    Uri.parse('https://www.maptiler.com/copyright/'),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Text('© MapTiler', style: TextStyle(fontSize: 9)),
                  ),
                ),
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Text('© OpenStreetMap', style: TextStyle(fontSize: 9)),
                ),
              ),
            ],
          ),
        ),
      ),
      if (failed)
        Positioned(
          top: 8,
          left: 8,
          right: widget.onStyleChanged == null ? 8 : 72,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    satellite
                        ? 'Satellite tiles unavailable. Try Streets or retry.'
                        : 'Map tiles unavailable. Check connection and retry.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() {
                        failed = false;
                        retry++;
                      }),
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class MapLayersButton extends StatelessWidget {
  const MapLayersButton({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final StewardieMapStyle selected;
  final ValueChanged<StewardieMapStyle> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<StewardieMapStyle>(
    tooltip: 'Map layers, ${selected.name} selected',
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    onSelected: onSelected,
    itemBuilder: (context) => [
      PopupMenuItem(
        value: StewardieMapStyle.satellite,
        enabled: mapTilerKey.isNotEmpty,
        child: _styleOption(
          Icons.satellite_alt_outlined,
          mapTilerKey.isEmpty ? 'Satellite needs a map key' : 'Satellite',
          selected == StewardieMapStyle.satellite,
        ),
      ),
      PopupMenuItem(
        value: StewardieMapStyle.streets,
        child: _styleOption(
          Icons.map_outlined,
          'Streets',
          selected == StewardieMapStyle.streets,
        ),
      ),
    ],
    child: Material(
      color: const Color(0xFFFFFEFB),
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: const SizedBox(
        width: 48,
        height: 48,
        child: Icon(Icons.layers_rounded, semanticLabel: 'Map layers'),
      ),
    ),
  );

  Widget _styleOption(IconData icon, String label, bool selected) => Semantics(
    selected: selected,
    child: SizedBox(
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (selected) const Icon(Icons.check_rounded, size: 20),
        ],
      ),
    ),
  );
}
