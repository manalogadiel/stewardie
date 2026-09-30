import 'dart:async';

import 'package:flutter/material.dart';

import '../core/sound_feedback.dart';
import '../features/onboarding/permission_adapter.dart';
import 'push_service.dart';

class AppSoundSettings extends StatefulWidget {
  const AppSoundSettings({super.key});
  @override
  State<AppSoundSettings> createState() => _AppSoundSettingsState();
}

class _AppSoundSettingsState extends State<AppSoundSettings> {
  bool saving = false;
  double? draftVolume;
  String? error;
  Future<void> save(SoundSettings value) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await SoundFeedback.update(value);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save sound settings. Please retry.');
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
          draftVolume = null;
        });
      }
    }
  }

  SoundSettings changed(
    SoundSettings p, {
    bool? enabled,
    double? volume,
    bool? reactions,
    bool? attention,
  }) => SoundSettings(
    enabled: enabled ?? p.enabled,
    volume: volume ?? p.volume,
    reactions: reactions ?? p.reactions,
    attention: attention ?? p.attention,
  );
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: SoundFeedback.ready,
    builder: (context, ready, _) => ValueListenableBuilder<SoundSettings>(
      valueListenable: SoundFeedback.settings,
      builder: (context, prefs, _) {
        final editable = ready && !saving;
        return Material(
          color: const Color(0xFFFFFEFB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E2DA)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                title: const Text('App sounds'),
                value: prefs.enabled,
                onChanged: editable
                    ? (v) => unawaited(save(changed(prefs, enabled: v)))
                    : null,
              ),
              if (prefs.enabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_up_outlined),
                      Expanded(
                        child: Slider(
                          value: draftVolume ?? prefs.volume,
                          divisions: 10,
                          semanticFormatterCallback: (v) =>
                              '${(v * 100).round()} percent',
                          label:
                              '${((draftVolume ?? prefs.volume) * 100).round()}%',
                          onChanged: editable
                              ? (v) => setState(() => draftVolume = v)
                              : null,
                          onChangeEnd: editable
                              ? (v) =>
                                    unawaited(save(changed(prefs, volume: v)))
                              : null,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Preview app sound',
                        icon: const Icon(Icons.play_arrow_rounded),
                        onPressed: editable && prefs.volume > 0
                            ? () =>
                                  unawaited(SoundFeedback.emit(SoundCue.saved))
                            : null,
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('Reaction pops'),
                  value: prefs.reactions,
                  onChanged: editable
                      ? (v) => unawaited(save(changed(prefs, reactions: v)))
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Failed-save sounds'),
                  value: prefs.attention,
                  onChanged: editable
                      ? (v) => unawaited(save(changed(prefs, attention: v)))
                      : null,
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Color(0xFFB42318)),
                  ),
                ),
              TextButton.icon(
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Device notification settings'),
                onPressed: () async {
                  try {
                    if (Theme.of(context).platform == TargetPlatform.android) {
                      await PushService.instance.openSystemSettings();
                    } else {
                      await const PermissionAdapter().openSettings();
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open device settings.'),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
