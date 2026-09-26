import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'external_launcher.dart';
import 'live_location_service.dart';
import 'online_backend.dart';

/// Modal bottom sheet featuring an interactive live map (flutter_map) and clay radar view
/// with real-time member locations and GPS sharing.
class SpaceMapSheet extends StatefulWidget {
  const SpaceMapSheet({
    super.key,
    required this.backend,
    required this.spaceId,
  });

  final OnlineBackend backend;
  final String spaceId;

  static Future<void> show(
    BuildContext context, {
    required OnlineBackend backend,
    required String spaceId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF9F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SpaceMapSheet(
        backend: backend,
        spaceId: spaceId,
      ),
    );
  }

  @override
  State<SpaceMapSheet> createState() => _SpaceMapSheetState();
}

class _SpaceMapSheetState extends State<SpaceMapSheet> {
  final MapController _mapController = MapController();
  int _selectedDuration = 15; // 15, 30, 60
  Map<String, dynamic>? _selectedMember;
  bool _showRadarView = false;
  LatLng _lastKnownCenter = const LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    _initUserLocation();
  }

  Future<void> _initUserLocation() async {
    final pos = await LiveLocationService.instance.determinePosition();
    if (pos != null && mounted) {
      final userLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _lastKnownCenter = userLatLng;
      });
      try {
        _mapController.move(userLatLng, 14.5);
      } catch (_) {}
    }
  }

  Future<void> _recenterOnUser() async {
    final pos = await LiveLocationService.instance.determinePosition();
    if (pos != null && mounted) {
      final userLatLng = LatLng(pos.latitude, pos.longitude);
      _mapController.move(userLatLng, 15.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final locationService = LiveLocationService.instance;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + media.viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4D0C8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Space map',
                    style: TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF202633),
                    ),
                  ),
                  Row(
                    children: [
                      // View mode toggle (Live Map / Radar)
                      IconButton(
                        onPressed: () {
                          setState(() => _showRadarView = !_showRadarView);
                        },
                        icon: Icon(
                          _showRadarView ? Icons.map_outlined : Icons.radar_rounded,
                          color: const Color(0xFF244BFF),
                          size: 22,
                        ),
                        tooltip: _showRadarView ? 'Switch to Map' : 'Switch to Radar',
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Color(0xFF596171)),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _showRadarView
                    ? 'Pastel clay radar view'
                    : 'Interactive live map with member pins',
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 14,
                  color: Color(0xFF596171),
                ),
              ),
              const SizedBox(height: 16),
              // Map or Radar View
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.backend.locationSessions(widget.spaceId),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  final sessions = docs.map((d) => d.data()).toList();

                  if (_showRadarView) {
                    return Center(
                      child: SizedBox(
                        width: 260,
                        height: 260,
                        child: GestureDetector(
                          onTapUp: (details) {
                            if (sessions.isNotEmpty) {
                              setState(() => _selectedMember = sessions.first);
                            }
                          },
                          child: CustomPaint(
                            painter: _ClayRadarPainter(sessions: sessions),
                          ),
                        ),
                      ),
                    );
                  }

                  // Build markers for all active sessions
                  final markers = <Marker>[];
                  for (final s in sessions) {
                    final lat = (s['lat'] as num?)?.toDouble();
                    final lng = (s['lng'] as num?)?.toDouble();
                    if (lat == null || lng == null) continue;

                    final name = s['name'] as String? ?? 'Member';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'M';
                    final isSelected = _selectedMember?['uid'] == s['uid'];

                    markers.add(
                      Marker(
                        point: LatLng(lat, lng),
                        width: 56,
                        height: 60,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedMember = s);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF244BFF)
                                      : const Color(0xFFFFFEFB),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF244BFF),
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      fontFamily: 'NunitoSans',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF202633),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF202633),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  name.length > 7 ? '${name.substring(0, 7)}..' : name,
                                  style: const TextStyle(
                                    fontFamily: 'NunitoSans',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Also show user's current GPS pin if available
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      height: 280,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E5DF),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE5E2DA), width: 1.5),
                      ),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: sessions.isNotEmpty &&
                                      sessions.first['lat'] != null
                                  ? LatLng(
                                      (sessions.first['lat'] as num).toDouble(),
                                      (sessions.first['lng'] as num).toDouble(),
                                    )
                                  : _lastKnownCenter,
                              initialZoom: 14.0,
                              minZoom: 3.0,
                              maxZoom: 18.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.stewardie.app',
                              ),
                              MarkerLayer(markers: markers),
                            ],
                          ),
                          // Recenter button
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Material(
                              color: const Color(0xFFFFFEFB),
                              shape: const CircleBorder(),
                              elevation: 3,
                              child: InkWell(
                                onTap: _recenterOnUser,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    Icons.my_location_rounded,
                                    color: Color(0xFF244BFF),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (_selectedMember != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFEFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E2DA)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMember!['name'] as String? ?? 'Member',
                            style: const TextStyle(
                              fontFamily: 'NunitoSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF202633),
                            ),
                          ),
                          const Text(
                            'Active now',
                            style: TextStyle(
                              fontFamily: 'NunitoSans',
                              fontSize: 12,
                              color: Color(0xFF244BFF),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          final lat = (_selectedMember!['lat'] as num?)?.toDouble();
                          final lng = (_selectedMember!['lng'] as num?)?.toDouble();
                          ExternalLauncher.openMapDirections(
                            context,
                            query: 'Member location',
                            lat: lat,
                            lng: lng,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF244BFF),
                        ),
                        child: const Text(
                          'Directions',
                          style: TextStyle(
                            fontFamily: 'NunitoSans',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ValueListenableBuilder<bool>(
                valueListenable: locationService.isSharing,
                builder: (context, sharing, _) {
                  if (sharing) {
                    return ValueListenableBuilder<int>(
                      valueListenable: locationService.remainingMinutes,
                      builder: (context, remaining, _) {
                        return Column(
                          children: [
                            Text(
                              'Sharing your live location (${remaining}m left)',
                              style: const TextStyle(
                                fontFamily: 'NunitoSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF202633),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () => locationService.stopSharing(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFD32F2F),
                                  side: const BorderSide(color: Color(0xFFD32F2F)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Stop sharing',
                                  style: TextStyle(
                                    fontFamily: 'NunitoSans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          for (final d in [15, 30, 60])
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Center(
                                    child: Text(
                                      '${d}m',
                                      style: TextStyle(
                                        fontFamily: 'NunitoSans',
                                        fontSize: 13,
                                        fontWeight: _selectedDuration == d
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _selectedDuration == d
                                            ? Colors.white
                                            : const Color(0xFF202633),
                                      ),
                                    ),
                                  ),
                                  selected: _selectedDuration == d,
                                  selectedColor: const Color(0xFF244BFF),
                                  backgroundColor: const Color(0xFFFFFEFB),
                                  side: BorderSide(
                                    color: _selectedDuration == d
                                        ? const Color(0xFF244BFF)
                                        : const Color(0xFFE5E2DA),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedDuration = d);
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () {
                            locationService.startSharing(
                              spaceId: widget.spaceId,
                              durationMinutes: _selectedDuration,
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF244BFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Start sharing',
                            style: TextStyle(
                              fontFamily: 'NunitoSans',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClayRadarPainter extends CustomPainter {
  const _ClayRadarPainter({required this.sessions});
  final List<Map<String, dynamic>> sessions;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Pastel concentric clay rings
    final ringColors = [
      const Color(0xFFF8E7B0).withValues(alpha: 0.35),
      const Color(0xFFA9CDE8).withValues(alpha: 0.35),
      const Color(0xFFEAB8C5).withValues(alpha: 0.35),
    ];

    for (var i = 3; i >= 1; i--) {
      final r = maxRadius * (i / 3);
      final fillPaint = Paint()
        ..color = ringColors[i - 1]
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, r, fillPaint);

      final strokePaint = Paint()
        ..color = const Color(0xFFE5E2DA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, r, strokePaint);
    }

    // Crosshairs
    final linePaint = Paint()
      ..color = const Color(0xFFD4D0C8)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), linePaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), linePaint);

    // Center home dot
    final centerPaint = Paint()..color = const Color(0xFF244BFF);
    canvas.drawCircle(center, 5, centerPaint);

    // Member avatar pins
    for (var i = 0; i < sessions.length; i++) {
      final angle = (i * (2 * pi / max(1, sessions.length))) - (pi / 2);
      final dist = maxRadius * 0.65;
      final pinPos = Offset(
        center.dx + cos(angle) * dist,
        center.dy + sin(angle) * dist,
      );

      final pinBg = Paint()..color = const Color(0xFF202633);
      canvas.drawCircle(pinPos, 14, pinBg);

      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(pinPos, 14, borderPaint);

      final s = sessions[i];
      final name = s['name'] as String? ?? 'M';
      final letter = name.isNotEmpty ? name[0].toUpperCase() : 'M';
      final tp = TextPainter(
        text: TextSpan(
          text: letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pinPos.dx - tp.width / 2, pinPos.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ClayRadarPainter oldDelegate) {
    return oldDelegate.sessions != sessions;
  }
}
