import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'live_location_service.dart';

/// A presentation-only minimizer: GPS, audience and expiry stay in the service.
class LiveLocationPill extends StatefulWidget {
  const LiveLocationPill({super.key});
  @override
  State<LiveLocationPill> createState() => _LiveLocationPillState();
}

class _LiveLocationPillState extends State<LiveLocationPill> {
  bool minimized = false;
  String? session;
  @override
  Widget build(BuildContext context) {
    final service = LiveLocationService.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: service.isSharing,
      builder: (context, sharing, _) {
        if (!sharing) {
          session = null;
          return ValueListenableBuilder<bool>(
            valueListenable: service.stopPending,
            builder: (_, pending, _) => pending
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Location stopped here · waiting for server confirmation',
                      textAlign: TextAlign.center,
                    ),
                  )
                : const SizedBox.shrink(),
          );
        }
        if (session != service.presentationSessionKey) {
          session = service.presentationSessionKey;
          minimized = false;
        }
        return ValueListenableBuilder<int>(
          valueListenable: service.remainingMinutes,
          builder: (context, minutes, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AnimatedSize(
              duration: Duration(
                milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 240,
              ),
              curve: Curves.easeOutCubic,
              child: Material(
                color: SoftPop.surface,
                elevation: 5,
                shadowColor: SoftPop.ink.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(26),
                child: Padding(
                  padding: EdgeInsets.all(minimized ? 8 : 14),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: minimized
                            ? 'Expand sharing status'
                            : 'Minimize sharing status',
                        onPressed: () => setState(() => minimized = !minimized),
                        style: IconButton.styleFrom(
                          backgroundColor: SoftPop.lightSky,
                        ),
                        icon: Icon(
                          minimized
                              ? Icons.expand_more_rounded
                              : Icons.expand_less_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.location_on_rounded,
                        size: 20,
                        color: SoftPop.secondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: service.updatesUnavailable,
                          builder: (_, unavailable, _) => AnimatedSwitcher(
                            duration: Duration(
                              milliseconds:
                                  MediaQuery.disableAnimationsOf(context)
                                  ? 80
                                  : 200,
                            ),
                            child: Text(
                              minimized
                                  ? '${service.activeSpaceName} · ${minutes}m left'
                                  : unavailable
                                  ? '${service.activeSpaceName} · updates unavailable · ${minutes}m left'
                                  : 'Sharing in ${service.activeSpaceName} · ${minutes}m left',
                              key: ValueKey(minimized),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: SoftPop.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: service.stopSharing,
                        style: FilledButton.styleFrom(
                          backgroundColor: SoftPop.rose,
                          foregroundColor: SoftPop.ink,
                          minimumSize: const Size(48, 48),
                          elevation: 2,
                          shadowColor: SoftPop.ink.withValues(alpha: .16),
                        ),
                        child: const Text('End'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
