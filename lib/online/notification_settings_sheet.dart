import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'online_backend.dart';
import 'push_service.dart';

class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({
    super.key,
    required this.backend,
    required this.spaceId,
  });
  final OnlineBackend backend;
  final String spaceId;

  static Future<void> show(
    BuildContext context,
    OnlineBackend backend,
    String spaceId,
  ) => showModalBottomSheet<void>(
    // Use the root navigator so the sheet appears above the floating dock.
    context: Navigator.of(context, rootNavigator: true).context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFAF9F6),
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        NotificationSettingsSheet(backend: backend, spaceId: spaceId),
  );

  @override
  State<NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  bool enabled = false, spaceEnabled = true, busy = false;
  bool photos = false, reactions = false, moods = false;
  int quietStart = 22 * 60, quietEnd = 7 * 60;
  String timeZone = 'Asia/Manila';
  String? error;

  DocumentReference<Map<String, dynamic>> pref(
    String id,
  ) => widget.backend.firestore.doc(
    'accounts/${widget.backend.auth.currentUser!.uid}/notificationPrefs/$id',
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final docs = await Future.wait([
        pref('global').get(),
        pref(widget.spaceId).get(),
      ]);
      if (!mounted) return;
      setState(() {
        enabled = docs[0].data()?['enabled'] == true;
        quietStart = docs[0].data()?['quietStart'] as int? ?? quietStart;
        quietEnd = docs[0].data()?['quietEnd'] as int? ?? quietEnd;
        timeZone = docs[0].data()?['timeZone'] as String? ?? timeZone;
        spaceEnabled = docs[1].data()?['enabled'] != false;
        photos = docs[1].data()?['photos'] == true;
        reactions = docs[1].data()?['reactions'] == true;
        moods = docs[1].data()?['moods'] == true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not load notification settings.');
      }
    }
  }

  String display(int minute) =>
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context);

  Future<void> chooseTime(bool start) async {
    final current = start ? quietStart : quietEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked != null && mounted) {
      setState(() {
        if (start) {
          quietStart = picked.hour * 60 + picked.minute;
        } else {
          quietEnd = picked.hour * 60 + picked.minute;
        }
      });
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (enabled && !await PushService.instance.requestPermission()) {
        if (mounted) {
          setState(
            () => error =
                'Allow notifications in device settings to enable push.',
          );
        }
        return;
      }
      final batch = widget.backend.firestore.batch();
      batch.set(pref('global'), {
        'enabled': enabled,
        'quietStart': quietStart,
        'quietEnd': quietEnd,
        'timeZone': timeZone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(pref(widget.spaceId), {
        'enabled': spaceEnabled,
        'photos': photos,
        'reactions': reactions,
        'moods': moods,
        'quietStart': quietStart,
        'quietEnd': quietEnd,
        'timeZone': timeZone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not save notification settings.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + media.viewInsets.bottom + media.viewPadding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Reminders', style: Theme.of(context).textTheme.titleLarge),
              const Text('Your activity inbox works even without push alerts.'),
              if (!PushService.instance.available)
                const Text('Push is not configured in this build yet.'),
              SwitchListTile.adaptive(
                title: const Text('Push reminders'),
                value: enabled,
                onChanged: PushService.instance.available
                    ? (value) => setState(() => enabled = value)
                    : null,
              ),
              SwitchListTile.adaptive(
                title: const Text('Alerts from this space'),
                value: spaceEnabled,
                onChanged: enabled
                    ? (value) => setState(() => spaceEnabled = value)
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Optional activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SwitchListTile.adaptive(
                title: const Text('New photos'),
                value: photos,
                onChanged: (value) => setState(() => photos = value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Reactions to my photos'),
                value: reactions,
                onChanged: (value) => setState(() => reactions = value),
              ),
              SwitchListTile.adaptive(
                title: const Text('Mood check-ins in my inbox'),
                subtitle: const Text('No mood push alerts'),
                value: moods,
                onChanged: (value) => setState(() => moods = value),
              ),
              const SizedBox(height: 8),
              Text(
                'Quiet hours',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => chooseTime(true),
                      child: Text('From ${display(quietStart)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => chooseTime(false),
                      child: Text('Until ${display(quietEnd)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: timeZone,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Quiet-hours time zone',
                ),
                items: const [
                  DropdownMenuItem(value: 'Asia/Manila', child: Text('Manila')),
                  DropdownMenuItem(
                    value: 'Asia/Singapore',
                    child: Text('Singapore'),
                  ),
                  DropdownMenuItem(
                    value: 'Europe/London',
                    child: Text('London'),
                  ),
                  DropdownMenuItem(
                    value: 'America/New_York',
                    child: Text('New York'),
                  ),
                  DropdownMenuItem(
                    value: 'America/Los_Angeles',
                    child: Text('Los Angeles'),
                  ),
                  DropdownMenuItem(value: 'UTC', child: Text('UTC')),
                ],
                onChanged: (value) =>
                    setState(() => timeZone = value ?? timeZone),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: const Text('Save reminder settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
