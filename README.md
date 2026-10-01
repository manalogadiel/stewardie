# Stewardie

A Flutter shared-life app for families, friends, housemates, dormmates, and crews.

Status: The normal Flutter app uses Firebase verified email/password identity with Supabase shared data and private photo storage. New cloud spaces are enabled by default; old Firebase data is preserved for a later reviewed import. Today / Moments / Space remains unchanged. See [live migration and verification](docs/supabase-core-migration.md); older Spark verification describes the previous backend.

## Start here

The Supabase cloud is deployed and enabled for new spaces. Run `flutter run` normally; see [migration progress and preserved data](docs/supabase-core-migration.md).

Repository handoff: [final review and verification](docs/repository-handoff.md). This is a source-code submission; device and store-release requirements are tracked separately.

Latest audio follow-up: [louder Soft Pop sounds and account controls](docs/soft-pop-sound-expansion-verification.md), with device listening and iOS compilation still open.

Latest implementation: [permissions, tour, Moments and notifications verification](docs/permissions-tour-moments-notifications-verification.md). Firebase rules and Supabase gateways/worker are deployed; native device delivery and GPS checks remain documented gates.

1. [Product plan](docs/shared-spaces-product-plan.md) — behavior and scope.
2. [UI and assets](docs/ui-plan.md) — screens, tokens, approved visual direction, and assets needed.
3. [Technical and launch plan](docs/technical-launch-plan.md) — proposed architecture and staged build.
4. [Subscription plan v1](docs/stewardie-subscription-plan.md) — Basic and personal Plus, approved pilot quotas, target pricing, and launch gates.
5. [Character reference](docs/soft-pop-character-reference.png) — visual reference, not production-ready assets.

The project-local [Soft Pop UI skill](.agents/skills/soft-pop-ui/SKILL.md) provides design guidance. Optional upstream skills are not bundled or installed by this setup.

This repository's plans are the working copies going forward. Earlier copies in the Codex output folder are historical snapshots. The technical plan's observations about the old Kalinga repository are historical, not descriptions of this repository.

## Run the app

Use this repository in Antigravity. Fully restart the app after pulling these changes:

```sh
flutter pub get
flutter run
```

The default `lib/main.dart` is the signed-in cloud app. `lib/main_online.dart` is an alias; `lib/main_fixture.dart` is the separate offline visual fixture (check the file name before using older commands). Firebase configuration is already present. Accounts must verify their email before shared access. No Blaze upgrade, Functions deployment, or store account is needed for the current trial.

Debug `flutter run` enables RevenueCat's simulated Test Store (no real charge). Disable it with `--dart-define=ENABLE_TEST_PURCHASES=false`. Production purchases remain guarded and unconfigured. New onboarding shows a skippable full-page paywall; see [verification](docs/onboarding-plus-and-logo-verification.md).

Tasks, memberships, moods, and calendar plans synchronize through the protected Supabase gateway. Personal Plus is protected server-side and never upgrades other members. Today and Moments retain the approved clay assets and interactions. New shared photos use private Supabase storage and member-checked access. Existing local photos require an explicit Share this photo to space action. Moments refreshes on entry, foreground resume, successful upload, and every 20 seconds while open. Remembered accounts store an email/name only; signing back in still requires secure authentication, with platform autofill where available.

Daily moods expire at midnight in each space's configured time zone through an authenticated server write. Completed-task history uses the authenticated core gateway: Basic covers today and the previous three space-local calendar dates, including daylight-saving boundaries; Plus can page through all retained authorized history. Unfinished tasks remain accessible through Supabase. Public purchases remain disabled. Camera orientation, gallery export, and real two-device behavior still need native-device checks by the owner.

See [cloud setup](docs/live-firebase-setup.md), [implementation record](docs/spark-polish-verification.md), and [backend instructions](backend/firebase/README.md). Earlier verification documents describe historical slices, not the current runtime. Store release still requires the launch gates in the product, subscription, and technical plans.

The Android pilot features for QR invites, calendar reminders, offline edits, and safety controls are staged locally. See [implementation status, backend deployment, and release gates](docs/pilot-completion-verification.md). The current Firestore rules/indexes and scheduled worker were deployed and checked on September 28; the deletion-request page is not public, and `flutter run` does not deploy backend changes.

The private [account-deletion operator runbook](docs/account-deletion-operations.md) and dry-run-first cleanup tool are now in the repository. One disposable live account passed cross-service cleanup on September 28; the external request page, retention-policy review, and wider device testing remain pilot gates.

Location, calendar import, and scheduled reminders are staged in code; real plan-reminder and FCM delivery still need physical-device tests. Firebase Cloud Messaging replaces the earlier OneSignal transport; the in-app activity inbox remains independent of push. Google OAuth is still unconfigured. Follow [the rollout steps and device checks](docs/location-calendar-reminders-setup.md). Do not treat native background location, push, or Google access as verified by a Flutter build alone.

The map and navigation refresh is deployed for the private pilot. [Pilot key setup](docs/map-navigation-rollout.md) explains the free development key; the [completion verification record](docs/map-navigation-completion-verification.md) lists the native-device and multi-account checks still open.

The [September 30 implementation record](docs/public-testing-implementation-status.md) separates this round's local changes and deployed backend code from unfinished dashboard, device, billing, and release checks.

The latest [media, tour and Soft Pop polish record](docs/media-tour-soft-pop-polish-verification.md) covers reliable photo/task retries, camera layout, account-backed tours, sharing controls, and the deployed three-space Basic cap, with remaining device checks listed separately.
