# Stewardie repository handoff

October 1, 2026. Scope: source-code submission, as confirmed by the owner. This is not a store release or a guarantee that every native device condition has been tested.

## Run and review

Supabase now provides new cloud spaces, tasks and media access, with Firebase Authentication retained. The owner verified space creation and automatic selection on the phone. Historical Firebase data remains preserved for a later reviewed import; see [Supabase cutover and verification](supabase-core-migration.md).

Use the Flutter/Dart SDK matching `pubspec.yaml` (Dart 3.13 or later within the declared SDK range).

```sh
flutter pub get
flutter test
flutter analyze --no-fatal-infos
flutter run
```

The default entry point uses the configured Firebase/Supabase services. MapTiler's public pilot key is already configured; a Dart define can override it. Sign in with a real verified account to exercise shared data. For an offline visual review, use the separate fixture entry point:

```sh
flutter run -t lib/main_fixture.dart
```

Fixture behavior does not verify cloud synchronization, permissions, purchases, GPS or notifications. Never supply server secrets or administrator keys to a client build.

## Final polish

- Shortened permission, reminder, purchase and tour copy while retaining important sharing/privacy distinctions.
- Fixed the calendar card's stale height when its month/content changes. Equal-height cards now remain responsive to child size changes; the date grid has an explicit seven-column layout.
- Account tour/sign-out controls grow with text rather than forcing it into a 50-pixel box. Long sharing status is bounded, with its space name retained.
- Notification listeners do not start for a different or signed-out account.
- Preserved the preceding task acceptance/completion repair, normal-card Synced removal, one-page moment viewer, form spacing and edge-to-edge iPhone safe-area changes.
- Updated tests that still expected retired invitation copy, mascot assets, purchase labels and sharing labels. Permission tests now mock location-service status instead of calling a native API; place-picker tests scroll the sheet independently of map gestures.
- Added ignores for Kotlin build cache, Android signing properties and private upload keystores. A filename-based tracked-file check found no service-account JSON, environment file, signing properties or private keystore matches; this is not a comprehensive secret audit.

## Verification

- Full Flutter suite: **204 tests passed**. This includes onboarding/tour, task actions, media/reactions, calendars, maps, notifications, sound feedback, narrow/enlarged-text layouts and simulated iPhone insets.
- After replacing sealed Firestore mocks with a narrow operation-ID seam, the affected task suite passed again: **7 tests**.
- Final whole-project analysis: **0 errors, 0 warnings**, with **90 informational style diagnostics**. The `--no-fatal-infos` command above keeps those informational notes visible without treating them as a failed handoff check.
- `git diff --check` passed. No deployment, new paid service, release signing, publication or remote push was performed by this handoff pass.

## Verification boundaries

Layout tests catch the exercised overlaps; they cannot prove every combination of content, device and accessibility setting. Physical Android/iOS tests remain necessary for GPS/background sharing, camera orientation, native saving, sound/silent-mode behavior and notification delivery. No iOS compilation or new native build was run during this Dart/UI finalization.

Live multi-account authorization, shared photo/task delivery and account-deletion operations retain the gates in the existing deployment records. RevenueCat purchases remain disabled until the approved store configuration is ready. Those limits do not prevent a source-code submission, but should not be represented as completed store-release validation.

Submit the current source files and this README/documentation together. Do not include generated `build/`, `.dart_tool/`, local signing files or administrator secrets. If submitting through a Git hosting URL, ensure these local changes are included in the submitted commit; this pass does not push them remotely.
