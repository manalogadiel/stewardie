import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../mascot_stage.dart';
import '../permission_adapter.dart';
import '../staggered_entrance.dart';

/// Screen 5: Make it yours
/// Three optional permission cards (Camera, Location, Notifications).
/// Each capability has its own isolated Allow and Not now actions.
/// Never queues all prompts automatically.
/// Continue is always usable.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({
    super.key,
    required this.adapter,
    required this.onContinue,
  });

  final PermissionAdapter adapter;
  final VoidCallback onContinue;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  final Map<PermissionCapability, PermissionStatusState> _statuses = {
    PermissionCapability.camera: PermissionStatusState.notDetermined,
    PermissionCapability.location: PermissionStatusState.notDetermined,
    PermissionCapability.notifications: PermissionStatusState.notDetermined,
  };

  final Set<PermissionCapability> _skipped = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInitialStatuses();
    }
  }

  Future<void> _checkInitialStatuses() async {
    for (final capability in PermissionCapability.values) {
      final status = await widget.adapter.checkStatus(capability);
      if (mounted) {
        setState(() => _statuses[capability] = status);
      }
    }
  }

  Future<void> _requestCapability(PermissionCapability capability) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.adapter.requestPermission(capability);
      if (mounted) {
        setState(() {
          _statuses[capability] = result;
          _skipped.remove(capability);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _skipCapability(PermissionCapability capability) {
    setState(() {
      _skipped.add(capability);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MascotStage(pose: MascotPose.makeItYours),
              const SizedBox(height: 16),
              const StaggeredEntrance(
                order: 1,
                child: Text(
                  'Make it yours',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: SoftPop.ink,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const StaggeredEntrance(
                order: 2,
                child: Text(
                  'Choose what Stewardie can help with. These are completely optional.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: SoftPop.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              StaggeredEntrance(
                order: 3,
                child: Column(
                  children: [
                    _buildPermissionCard(
                      capability: PermissionCapability.camera,
                      icon: Icons.camera_alt_outlined,
                      title: 'Camera',
                      description: 'Scan invitations and take photos for your space.',
                    ),
                    const SizedBox(height: 12),
                    _buildPermissionCard(
                      capability: PermissionCapability.location,
                      icon: Icons.location_on_outlined,
                      title: 'Location',
                      description: 'Center maps on you when you choose.',
                    ),
                    const SizedBox(height: 12),
                    _buildPermissionCard(
                      capability: PermissionCapability.notifications,
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      description: 'Get reminders and updates from your spaces.',
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: widget.onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: SoftPop.blue,
                        foregroundColor: SoftPop.surface,
                        minimumSize: const Size(48, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required PermissionCapability capability,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final status = _statuses[capability] ?? PermissionStatusState.notDetermined;
    final isSkipped = _skipped.contains(capability);
    final isGranted = status == PermissionStatusState.granted;
    final isPermanentlyDenied =
        status == PermissionStatusState.permanentlyDenied;
    final isUnavailable = status == PermissionStatusState.unavailable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SoftPop.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted ? SoftPop.blue : const Color(0xFFE8E5DF),
          width: isGranted ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08202633),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isGranted ? SoftPop.blueSoft : const Color(0xFFF2F4F7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isGranted ? SoftPop.blue : SoftPop.ink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: SoftPop.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: SoftPop.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isGranted)
            Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                SizedBox(width: 6),
                Text(
                  'Allowed',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.green,
                  ),
                ),
              ],
            )
          else if (isUnavailable)
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: SoftPop.secondary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    capability == PermissionCapability.notifications
                        ? 'Set up later · updates remain in your in-app inbox'
                        : 'Unavailable on this device',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SoftPop.secondary,
                    ),
                  ),
                ),
              ],
            )
          else if (isPermanentlyDenied)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Permission denied in settings',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SoftPop.secondary,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.adapter.openSettings(),
                  child: const Text('Open Settings'),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isSkipped)
                  TextButton(
                    onPressed: () => _skipCapability(capability),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 44),
                    ),
                    child: const Text(
                      'Not now',
                      style: TextStyle(
                        fontSize: 13,
                        color: SoftPop.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Skipped',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: SoftPop.secondary,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _requestCapability(capability),
                  style: FilledButton.styleFrom(
                    backgroundColor: SoftPop.blue,
                    foregroundColor: SoftPop.surface,
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Allow',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
