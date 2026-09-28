# Stewardie

A Flutter shared-life app for families, friends, housemates, dormmates, and crews.

Status: The normal Flutter app connects to the live `stewardie` Firebase project using verified email/password accounts and rule-enforced Firestore transactions on Spark. The approved Today / Moments / Space layouts remain in place. Private cloud photo sharing is connected through Supabase; paid purchases remain disabled. See [shared Moments deployment and verification](docs/shared-moments-verification.md). See [earlier Spark implementation](docs/spark-polish-verification.md).

## Start here

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

Tasks, memberships, moods, and calendar plans synchronize through Firestore. Personal Plus is protected server-side and reserved for the verified founder account; it never upgrades other members. Today and Moments retain the approved clay assets and interactions. New shared photos use private Supabase storage and member-checked access. Existing local photos require an explicit Share this photo to space action. Moments refreshes on entry, foreground resume, successful upload, and every 20 seconds while open. Remembered accounts store an email/name only; signing back in still requires secure authentication, with platform autofill where available.

The Spark trial uses UTC boundaries for mood expiry and Basic Done-history access. Space-time-zone boundaries and trusted purchase synchronization require a later backend decision. Public purchases remain disabled. Camera orientation, gallery export, and real two-device behavior still need native-device checks by the owner.

See [cloud setup](docs/live-firebase-setup.md), [implementation record](docs/spark-polish-verification.md), and [backend instructions](backend/firebase/README.md). Earlier verification documents describe historical slices, not the current runtime. Store release still requires the launch gates in the product, subscription, and technical plans.

The Android pilot features for QR invites, calendar reminders, offline edits, and safety controls are staged locally. See [implementation status, backend deployment, and release gates](docs/pilot-completion-verification.md). The current Firestore rules/indexes and scheduled worker were deployed and checked on September 28; the deletion-request page is not public, and `flutter run` does not deploy backend changes.

The private [account-deletion operator runbook](docs/account-deletion-operations.md) and dry-run-first cleanup tool are now in the repository. One disposable live account passed cross-service cleanup on September 28; the external request page, retention-policy review, and wider device testing remain pilot gates.

Location, calendar import, and scheduled reminders are staged in code; the current reminder worker is deployed, but real plan-reminder delivery has not been device-tested. OneSignal and Google OAuth remain optional and unconfigured. Follow [the rollout steps and device checks](docs/location-calendar-reminders-setup.md). Do not treat native background location, push, or Google access as verified by a Flutter build alone.

The map and navigation refresh is staged locally; [pilot key setup and remaining map checks](docs/map-navigation-rollout.md) explains the free development key.
