# Stewardie

A Flutter shared-life app for families, friends, housemates, dormmates, and crews.

Status: The normal Flutter app connects to the live `stewardie` Firebase project using verified email/password accounts and rule-enforced Firestore transactions on Spark. The approved Today / Moments / Space layouts remain in place. Paid purchases and cloud photo uploads are not enabled. See [current implementation and verification](docs/spark-polish-verification.md).

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

Tasks, memberships, moods, and calendar plans synchronize through Firestore. Personal Plus is protected server-side and reserved for the verified founder account; it never upgrades other members. Today and Moments retain the approved clay assets and interactions. Photos remain private to this device/account and are not synchronized to other members. Remembered accounts store an email/name only; signing back in still requires secure authentication, with platform autofill where available.

The Spark trial uses UTC boundaries for mood expiry and Basic Done-history access. Space-time-zone boundaries and trusted purchase synchronization require a later backend decision. Public purchases remain disabled. Camera orientation, gallery export, and real two-device behavior still need native-device checks by the owner.

See [cloud setup](docs/live-firebase-setup.md), [implementation record](docs/spark-polish-verification.md), and [backend instructions](backend/firebase/README.md). Earlier verification documents describe historical slices, not the current runtime. Store release still requires the launch gates in the product, subscription, and technical plans.
