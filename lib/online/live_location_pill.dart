import 'package:flutter/material.dart';

import 'live_location_service.dart';

/// Floating pill strip rendered above the bottom navigation dock when location sharing is active.
class LiveLocationPill extends StatelessWidget {
  const LiveLocationPill({super.key});

  @override
  Widget build(BuildContext context) {
    final service = LiveLocationService.instance;

    return ValueListenableBuilder<bool>(
      valueListenable: service.isSharing,
      builder: (context, sharing, _) {
        if (!sharing) return const SizedBox.shrink();

        return ValueListenableBuilder<int>(
          valueListenable: service.remainingMinutes,
          builder: (context, minutes, _) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202633),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF244BFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sharing location • ${minutes}m',
                        style: const TextStyle(
                          fontFamily: 'NunitoSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => service.stopSharing(),
                        child: const Text(
                          'Stop',
                          style: TextStyle(
                            fontFamily: 'NunitoSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF8A80),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
