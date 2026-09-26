import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'external_launcher.dart';
import 'live_location_service.dart';
import 'online_backend.dart';

/// Modal bottom sheet with native Soft Pop clay radar canvas and live location sharing.
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
  int _selectedDuration = 15; // 15, 30, 60
  Map<String, dynamic>? _selectedMember;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final locationService = LiveLocationService.instance;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + media.viewInsets.bottom),
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
              const SizedBox(height: 20),
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF596171)),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Live member locations and radar view',
                style: TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 14,
                  color: Color(0xFF596171),
                ),
              ),
              const SizedBox(height: 20),
              // Radar Canvas Stream
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: widget.backend.locationSessions(widget.spaceId),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  final sessions = docs.map((d) => d.data()).toList();

                  return Center(
                    child: SizedBox(
                      width: 240,
                      height: 240,
                      child: GestureDetector(
                        onTapUp: (details) {
                          // Tap interaction on radar
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
              const SizedBox(height: 24),
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
                              'Sharing your location (${remaining}m left)',
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

      final name = sessions[i]['name'] as String? ?? 'M';
      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'M';

      final textSpan = TextSpan(
        text: initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'NunitoSans',
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(pinPos.dx - textPainter.width / 2, pinPos.dy - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ClayRadarPainter oldDelegate) =>
      oldDelegate.sessions != sessions;
}
