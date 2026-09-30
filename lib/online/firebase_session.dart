import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../app.dart';
import '../core/sound_feedback.dart';
import '../core/invite_links.dart';
import '../features/subscription/revenuecat_service.dart';
import '../core/backend_provider.dart';
import '../core/demo_state.dart';
import '../core/theme.dart';
import '../core/profile_photo.dart';
import '../features/calendar/calendar_state.dart';
import '../features/media/media_library.dart';
import '../features/onboarding/tutorial/tutorial_coordinator.dart';
import '../features/media/camera_screen.dart';
import '../features/media/picker_recovery.dart';
import 'firebase_repository.dart';
import 'edit_outbox.dart';
import 'cloud_media_library.dart';
import 'online_backend.dart';
import 'online_home.dart';
import 'live_location_service.dart';
import 'push_service.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/onboarding/onboarding_store.dart';

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

class _FirebaseSessionAppState extends State<FirebaseSessionApp>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _soundAccount;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SoundFeedback.foreground(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    unawaited(
      SoundFeedback.bind(widget.database, widget.backend.auth.currentUser?.uid),
    );
    _soundAccount = widget.backend.auth.authStateChanges().listen((user) {
      unawaited(SoundFeedback.bind(widget.database, user?.uid));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    SoundFeedback.foreground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_soundAccount?.cancel());
    SoundFeedback.foreground(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: widget.backend.auth.userChanges(),
    builder: (context, snapshot) {
      final user = widget.backend.auth.currentUser ?? snapshot.data;
      if (snapshot.connectionState == ConnectionState.waiting) {
        return MaterialApp(
          title: 'Stewardie',
          debugShowCheckedModeBanner: false,
          theme: SoftPop.theme,
          home: const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      if (user == null) {
        return MaterialApp(
          title: 'Stewardie',
          debugShowCheckedModeBanner: false,
          theme: SoftPop.theme,
          home: OnboardingFlow(
            backend: widget.backend,
            database: widget.database,
            onCompleted: () => setState(() {}),
          ),
        );
      }
      if (!user.emailVerified) {
        return MaterialApp(
          title: 'Stewardie',
          debugShowCheckedModeBanner: false,
          theme: SoftPop.theme,
          home: OnboardingFlow(
            backend: widget.backend,
            database: widget.database,
            initialStep: OnboardingStep.verifyEmail,
            initialUser: user,
            onCompleted: () => setState(() {}),
          ),
        );
      }
      return FutureBuilder<bool>(
        future: OnboardingStore(widget.database)
            .isCompleted(user.uid, backend: widget.backend),
        builder: (context, completedSnapshot) {
          if (completedSnapshot.connectionState == ConnectionState.waiting) {
            return MaterialApp(
              title: 'Stewardie',
              debugShowCheckedModeBanner: false,
              theme: SoftPop.theme,
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          final completed = completedSnapshot.data ?? false;
          if (!completed) {
            return MaterialApp(
              title: 'Stewardie',
              debugShowCheckedModeBanner: false,
              theme: SoftPop.theme,
              home: OnboardingFlow(
                backend: widget.backend,
                database: widget.database,
                initialStep: OnboardingStep.permissions,
                initialUser: user,
                onCompleted: () => setState(() {}),
              ),
            );
          }
          return _SignedInApp(
            key: ValueKey(user.uid),
            backend: widget.backend,
            user: user,
            database: widget.database,
          );
        },
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

class _SignedInAppState extends State<_SignedInApp>
    with WidgetsBindingObserver {
  late final outbox = EditOutbox(
    widget.database,
    widget.backend,
    widget.user.uid,
  );
  late final timeline = FirebaseTimelineRepository(
    widget.backend,
    widget.user.uid,
    outbox,
  );
  late final calendar = FirebaseCalendarRepository(timeline);
  late final Future<MediaLibrary> library = _loadLibrary();
  MediaLibrary? _loadedLibrary;
  CapturedPhoto? _recovered;
  bool _checkedInvite = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LiveLocationService.instance.init(widget.backend);
    unawaited(LiveLocationService.instance.restore());
    unawaited(PushService.instance.init(widget.user.uid).catchError((_) {}));
    unawaited(
      () async {
        final store = OnboardingStore(widget.database);
        final pending = await store.pendingAvatar(widget.user.uid);
        if (pending == null) return;
        await ProfilePhoto.save(pending);
        await store.clearPendingAvatar(widget.user.uid);
      }().catchError((_) {}),
    );
    unawaited(outbox.start());
    timeline.start();
    unawaited(RevenueCatService.instance.init(userId: widget.user.uid));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PushService.instance.syncPermission().catchError((_) {}));
      unawaited(outbox.flush());
      unawaited(_loadedLibrary?.retryPending());
    }
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
        final preview = await widget.backend.call('previewInvite', {
          'token': token,
        });
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
          if (preview['requireApproval'] == true) {
            final approved = await widget.backend.requestJoinSpace(
              preview['spaceId'] as String,
              token,
            );
            if (!approved) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Request sent. Open the invite again after approval.',
                    ),
                  ),
                );
              }
              return;
            }
          }
          final result = await widget.backend.call('redeemInvite', {
            'token': token,
          });
          final joinedSpaceId = result['spaceId'] as String?;
          if (joinedSpaceId != null && context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Joined $spaceName!')));
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
    WidgetsBinding.instance.removeObserver(this);
    unawaited(TutorialCoordinator.cancelForAccount(widget.user.uid));
    unawaited(LiveLocationService.instance.stopSharing(userInitiated: false));
    unawaited(PushService.instance.logOut());
    unawaited(timeline.dispose());
    outbox.close();
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
          if (!photoSnapshot.hasData ||
              (timeline.loading && timeline.spaces.isEmpty)) {
            return _standalone(
              const Center(child: CircularProgressIndicator()),
            );
          }
          if (timeline.spaces.isEmpty) {
            return MaterialApp(
              title: 'Stewardie',
              debugShowCheckedModeBanner: false,
              theme: SoftPop.theme,
              home: OnlineHome(
                backend: widget.backend,
                user: widget.user,
                spaceOnly: false,
                database: widget.database,
              ),
            );
          }
          return ProviderScope(
            key: ValueKey(widget.user.uid),
            overrides: [
              sharedBackendProvider.overrideWithValue(widget.backend),
              tutorialDatabaseProvider.overrideWithValue(widget.database),
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
