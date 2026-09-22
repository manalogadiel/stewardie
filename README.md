# Stewardie

A Flutter shared-life app for families, friends, housemates, dormmates, and crews.

Status: Flutter foundation and first local demo UI slice implemented. No backend, paid service, or payments are connected. See the [demo guide and verification record](docs/demo-foundation.md).

## Start here

1. [Product plan](docs/shared-spaces-product-plan.md) — behavior and scope.
2. [UI and assets](docs/ui-plan.md) — screens, tokens, approved visual direction, and assets needed.
3. [Technical and launch plan](docs/technical-launch-plan.md) — proposed architecture and staged build.
4. [Subscription plan v1](docs/stewardie-subscription-plan.md) — Basic and personal Plus, approved pilot quotas, target pricing, and launch gates.
5. [Character reference](docs/soft-pop-character-reference.png) — visual reference, not production-ready assets.

The project-local [Soft Pop UI skill](.agents/skills/soft-pop-ui/SKILL.md) provides design guidance. Optional upstream skills are not bundled or installed by this setup.

This repository's plans are the working copies going forward. Earlier copies in the Codex output folder are historical snapshots. The technical plan's observations about the old Kalinga repository are historical, not descriptions of this repository.

## Run the demo

Developed with Flutter 3.47.4 / Dart 3.13.3. The app uses Riverpod and go_router, a bundled Nunito Sans font, and in-memory repositories. Android and iOS scaffolds are included; web is a local review target.

```sh
flutter pub get
flutter run -d chrome
# Or connect an Android device and select its ID from flutter devices:
flutter run -d <device-id>
```

Today includes person filters, week navigation, task details, acceptance/decline, completion, help offers, handoff confirmation, and task creation. Check-in supports six moods, an optional note, explicit audience, update, and removal. Moments is an honest preview; Space shows sample members and simulated failure/conflict controls. Jamie is the fixed demo identity. All changes reset on restart.

```sh
flutter analyze
flutter test
# Optional rendered review images in build/review/:
flutter test --dart-define=CAPTURE_DEMO=true
```

**Current machine limitation:** Windows Application Control blocks Flutter's `impellerc.exe`, so normal asset compilation and the full web build did not complete here. Analysis and 20 tests passed using already prepared test assets with `flutter test --no-test-assets --dart-define=CAPTURE_DEMO=true`. This does not verify a clean build. No Android device/emulator was available; iOS requires macOS. See the [verification details](docs/demo-foundation.md#verification) before treating any platform as ready.

Next: resolve local build/device setup, then accounts, spaces, invitations, and online coordination after backend/budget decisions.

Open this same local repository in Codex and Antigravity. Avoid simultaneous agent edits to the same files. Tool-specific automatic skill discovery is not verified for Antigravity; its agent can read the linked skill and plans directly.

Still required before relevant launch stages: backend and operating budget approval, child-account policy, launch countries/platforms, name clearance, final payment/retention decisions, and production artwork.
