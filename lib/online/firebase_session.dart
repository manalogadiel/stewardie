import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../app.dart';
import '../core/invite_links.dart';
import '../features/subscription/revenuecat_service.dart';
import '../core/backend_provider.dart';
import '../core/demo_state.dart';
import '../core/theme.dart';
import '../features/calendar/calendar_state.dart';
import '../features/calendar/google_calendar_import.dart';
import '../features/media/media_library.dart';
import '../features/media/camera_screen.dart';
import '../features/media/picker_recovery.dart';
import 'firebase_repository.dart';
import 'cloud_media_library.dart';
import 'online_app.dart';
import 'online_backend.dart';
import 'online_home.dart';
import 'live_location_service.dart';
import 'push_service.dart';

class FirebaseSessionApp extends StatefulWidget {
  const FirebaseSessionApp({
    super.key,
    required this.backend,
    required this.database,
  });
  final OnlineBackend backend;
  final Database database;

  @override
  State<FirebaseSessionApp> createState() => _FirebaseSessionAppState();
}

class _FirebaseSessionAppState extends State<FirebaseSessionApp> {
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: widget.backend.auth.userChanges(),
    builder: (context, snapshot) {
      final user = widget.backend.auth.currentUser ?? snapshot.data;
      if (user != null && user.emailVerified) {
        return _SignedInApp(
          key: ValueKey(user.uid),
          backend: widget.backend,
          user: user,
          database: widget.database,
        );
      }
      return MaterialApp(
        title: 'Stewardie',
        debugShowCheckedModeBanner: false,
        theme: SoftPop.theme,
        home: snapshot.connectionState == ConnectionState.waiting
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : user == null
            ? OnlineAccountEntry(
                backend: widget.backend,
                database: widget.database,
              )
            : OnlineVerifyEmail(
                backend: widget.backend,
                user: user,
                onRefresh: () => setState(() {}),
              ),
      );
    },
  );
}

class _SignedInApp extends StatefulWidget {
  const _SignedInApp({
    super.key,
    required this.backend,
    required this.user,
    required this.database,
  });
  final OnlineBackend backend;
  final User user;
  final Database database;
  @override
  State<_SignedInApp> createState() => _SignedInAppState();
}

class _SignedInAppState extends State<_SignedInApp> {
  late final timeline = FirebaseTimelineRepository(
    widget.backend,
    widget.user.uid,
  );
  late final calendar = FirebaseCalendarRepository(timeline);
  late final Future<MediaLibrary> library = _loadLibrary();
  MediaLibrary? _loadedLibrary;
  CapturedPhoto? _recovered;
  bool _checkedInvite = false;
  @override
  void initState() {
    super.initState();
    LiveLocationService.instance.init(widget.backend);
    unawaited(LiveLocationService.instance.restore());
    PushService.instance.init(widget.user.uid);
    timeline.start();
    unawaited(() async {
      if (timeline.spaces.isEmpty) {
        await timeline.changes.firstWhere((_) => timeline.spaces.isNotEmpty);
      }
      if (await GoogleCalendarImport.instance.restore()) {
        for (final space in timeline.spaces) {
          try {
            await GoogleCalendarImport.instance.refreshSpace(widget.backend, space.id);
          } catch (_) {
            // Calendar remains usable; the member can reconnect on opening it.
          }
        }
      }
    }());
    unawaited(RevenueCatService.instance.init(userId: widget.user.uid));
  }

  void _checkInviteOnLaunch(BuildContext context) {
    if (_checkedInvite) return;
    _checkedInvite = true;
    final token = InviteLinks.sanitize(
      kIsWeb
          ? (Uri.base.queryParameters['invite'] ??
              Uri.base.queryParameters['token'] ??
              Uri.base.queryParameters['code'] ??
              '')
          : '',
    );
    if (token.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      try {
        final preview =
            await widget.backend.call('previewInvite', {'token': token});
        if (!context.mounted) return;
        final spaceName = preview['spaceName'] as String? ?? 'this space';
        final shouldJoin = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Join space?'),
            content: Text('You were invited to join $spaceName.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Join'),
              ),
            ],
          ),
        );
        if (shouldJoin == true && context.mounted) {
          await widget.backend.auth.currentUser?.reload();
          await widget.user.getIdToken(true);
          final result =
              await widget.backend.call('redeemInvite', {'token': token});
          final joinedSpaceId = result['spaceId'] as String?;
          if (joinedSpaceId != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Joined $spaceName!')),
            );
          }
        }
      } catch (_) {}
    });
  }

  Future<MediaLibrary> _loadLibrary() async {
    final records = stringMapStoreFactory.store(
      'signed-in-photos-${widget.user.uid}',
    );
    final photos = await records.find(widget.database);
    try {
      _recovered = await restorePickerResult(
        widget.database,
        accountId: widget.user.uid,
      );
    } catch (_) {
      /* Picker recovery must not prevent access to saved work. */
    }
    final queue = await stringMapStoreFactory
        .store('shared-photo-outbox')
        .find(widget.database);
    final result = CloudMediaLibrary(
      timeline,
      user: widget.user,
      pending: queue
          .where((r) => r.value['uid'] == widget.user.uid)
          .map((r) => r.value['id'] as String)
          .toSet(),
      database: widget.database,
      records: records,
      initial: photos
          .map((r) => MediaAttachment.fromMap(r.value))
          .where((p) => p.uploaderId == widget.user.uid)
          .toList(),
    );
    _loadedLibrary = result;
    if (!mounted) result.dispose();
    return result;
  }

  @override
  void dispose() {
    unawaited(LiveLocationService.instance.stopSharing());
    PushService.instance.logOut();
    unawaited(timeline.dispose());
    _loadedLibrary?.dispose();
    super.dispose();
  }

  Widget _standalone(Widget body) => MaterialApp(
    title: 'Stewardie',
    debugShowCheckedModeBanner: false,
    theme: SoftPop.theme,
    home: Scaffold(body: body),
  );
  @override
  Widget build(BuildContext context) {
    _checkInviteOnLaunch(context);
    return FutureBuilder<MediaLibrary>(
      future: library,
      builder: (context, photoSnapshot) => StreamBuilder<void>(
        stream: timeline.changes,
        builder: (context, _) {
          if (photoSnapshot.hasError) {
            return _standalone(
              const Center(
                child: Text(
                  'Your saved photos could not be opened. Restart the app to try again.',
                ),
              ),
            );
          }
          if (!photoSnapshot.hasData || timeline.loading) {
            return _standalone(const Center(child: CircularProgressIndicator()));
          }
          if (timeline.spaces.isEmpty) {
            return _standalone(
              OnlineHome(
                backend: widget.backend,
                user: widget.user,
                spaceOnly: true,
              ),
            );
          }
          return ProviderScope(
            key: ValueKey(widget.user.uid),
            overrides: [
              sharedBackendProvider.overrideWithValue(widget.backend),
              repositoryProvider.overrideWithValue(timeline),
              calendarRepositoryProvider.overrideWithValue(calendar),
              mediaLibraryProvider.overrideWithValue(photoSnapshot.data!),
              recoveredPhotoInitialProvider.overrideWithValue(_recovered),
            ],
            child: const StewardieApp(),
          );
        },
      ),
    );
  }
}
