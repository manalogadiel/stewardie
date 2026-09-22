# Stewardie

A Flutter shared-life app for families, friends, housemates, dormmates, and crews.

Status: Flutter foundation and approved Soft Pop UI redesign implemented locally. No backend, paid service, or payments are connected. See the [redesign and verification record](docs/ui-redesign-verification.md).

## Start here

1. [Product plan](docs/shared-spaces-product-plan.md) — behavior and scope.
2. [UI and assets](docs/ui-plan.md) — screens, tokens, approved visual direction, and assets needed.
3. [Technical and launch plan](docs/technical-launch-plan.md) — proposed architecture and staged build.
4. [Subscription plan v1](docs/stewardie-subscription-plan.md) — Basic and personal Plus, approved pilot quotas, target pricing, and launch gates.
5. [Character reference](docs/soft-pop-character-reference.png) — visual reference, not production-ready assets.

The project-local [Soft Pop UI skill](.agents/skills/soft-pop-ui/SKILL.md) provides design guidance. Optional upstream skills are not bundled or installed by this setup.

This repository's plans are the working copies going forward. Earlier copies in the Codex output folder are historical snapshots. The technical plan's observations about the old Kalinga repository are historical, not descriptions of this repository.

## Run locally

Developed with Flutter 3.47.4 / Dart 3.13.3. The app uses Riverpod and go_router, a bundled Nunito Sans font, and in-memory repositories. Android and iOS scaffolds are included; web is a local review target.

```sh
flutter pub get
flutter run -d chrome
# Or connect an Android device and select its ID from flutter devices:
flutter run -d <device-id>
```

Today includes the clay mascots, people filters, personal mood, shared month calendar, Pending/Covered tasks, and a direct Done tab. New tasks require acceptance before becoming Covered. Calendar plans support all-day/timed dates, participants, notes, and author-only editing/removal. The floating glass-clay dock keeps Today / Moments / Space. Moments is an empty presentation; uploads are not connected. Jamie is the fixed local identity; all data resets on restart. Product screens omit development labels; these limitations remain documented here.

```sh
flutter analyze
flutter test
# Optional rendered review images in build/review/:
flutter test --dart-define=CAPTURE_DEMO=true
```

See [current verification and platform limitations](docs/ui-redesign-verification.md) for test, build, and device results. Earlier foundation build failures remain recorded historically.

Next: resolve local build/device setup, then accounts, spaces, invitations, and online coordination after backend/budget decisions.

Open this same local repository in Codex and Antigravity. Avoid simultaneous agent edits to the same files. Tool-specific automatic skill discovery is not verified for Antigravity; its agent can read the linked skill and plans directly.

Still required before relevant launch stages: backend and operating budget approval, child-account policy, launch countries/platforms, name clearance, final payment/retention decisions, and final production asset review.
