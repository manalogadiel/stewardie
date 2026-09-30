import 'package:flutter/material.dart';

import '../../../core/profile_photo.dart';
import '../../../core/theme.dart';
import '../mascot_stage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.name,
    this.initialPhoto,
    required this.onPhotoChanged,
    required this.onContinue,
  });
  final String name;
  final String? initialPhoto;
  final ValueChanged<String?> onPhotoChanged;
  final VoidCallback onContinue;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? photo;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    photo = widget.initialPhoto;
  }

  Future<void> choose() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await ProfilePhoto.choose(context);
      if (!mounted || next == null) return;
      setState(() => photo = next);
      widget.onPhotoChanged(next);
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Could not open that photo. You can try again or skip.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MascotStage(pose: MascotPose.profile),
            const SizedBox(height: 20),
            Text(
              "Let's add your profile, ${widget.name.trim().isEmpty ? 'friend' : widget.name.trim()}!",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontFamily: 'Fredoka'),
            ),
            const SizedBox(height: 8),
            const Text(
              'A little face for your spaces. You can change it later.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (ProfilePhoto.decode(photo) case final bytes?) ...[
              Center(
                child: ClipOval(
                  child: Image.memory(
                    bytes,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: busy ? null : choose,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(photo == null ? 'Add photo' : 'Change photo'),
            ),
            if (photo != null)
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        setState(() => photo = null);
                        widget.onPhotoChanged(null);
                      },
                child: const Text('Remove photo'),
              ),
            if (error != null)
              Text(error!, style: const TextStyle(color: SoftPop.secondary)),
            if (busy) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : widget.onContinue,
              child: const Text('Continue'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      setState(() => photo = null);
                      widget.onPhotoChanged(null);
                      widget.onContinue();
                    },
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    ),
  );
}
