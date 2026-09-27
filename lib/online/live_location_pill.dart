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
        if (!sharing) {
          return ValueListenableBuilder<bool>(
            valueListenable: service.stopPending,
            builder: (context, pending, _) => pending
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Center(child: Text('Location stopped here · waiting for server confirmation')),
                  )
                : const SizedBox.shrink(),
          );
        }

        return ValueListenableBuilder<int>(
          valueListenable: service.remainingMinutes,
          builder: (context, minutes, _) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: Container(
                  height: 44,
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32),
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
                      Flexible(child: ValueListenableBuilder<bool>(
                        valueListenable: service.updatesUnavailable,
                        builder: (_, unavailable, _) => Text(
                          unavailable
                              ? 'Location updates unavailable • ${minutes}m'
                              : 'Sharing location • ${minutes}m',
                          style: const TextStyle(
                            fontFamily: 'NunitoSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => service.stopSharing(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFFB4A8),
                          minimumSize: const Size(48, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: const Text('Stop'),
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
