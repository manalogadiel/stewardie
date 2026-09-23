# Stewardie

A Flutter shared-life app for families, friends, housemates, dormmates, and crews.

Status: Flutter foundation and approved Soft Pop UI slices implemented locally. A separate Firebase-emulator entry point now exercises verified accounts, personal Plus, spaces, invitations, shared task actions and tier-scoped Done history. The main visual prototype still uses local fixtures; no live Firebase project, paid service, store account or payments are connected. See the [online-core record](docs/online-core-verification.md), [floating-header and moods record](docs/floating-header-moods-verification.md), [photo slice record](docs/ui-polish-media-verification.md), and [first redesign record](docs/ui-redesign-verification.md).

## Start here

1. [Product plan](docs/shared-spaces-product-plan.md) — behavior and scope.
2. [UI and assets](docs/ui-plan.md) — screens, tokens, approved visual direction, and assets needed.
3. [Technical and launch plan](docs/technical-launch-plan.md) — proposed architecture and staged build.
4. [Subscription plan v1](docs/stewardie-subscription-plan.md) — Basic and personal Plus, approved pilot quotas, target pricing, and launch gates.
5. [Character reference](docs/soft-pop-character-reference.png) — visual reference, not production-ready assets.

The project-local [Soft Pop UI skill](.agents/skills/soft-pop-ui/SKILL.md) provides design guidance. Optional upstream skills are not bundled or installed by this setup.

This repository's plans are the working copies going forward. Earlier copies in the Codex output folder are historical snapshots. The technical plan's observations about the old Kalinga repository are historical, not descriptions of this repository.

## Run locally

Developed with Flutter 3.47.4 / Dart 3.13.3. The app uses Riverpod and go_router, a bundled Nunito Sans font, Sembast local task/media storage, and fixture spaces. Android and iOS scaffolds are included; web is a local review target.

```sh
flutter pub get
flutter run -d chrome
# Or connect an Android device and select its ID from flutter devices:
flutter run -d <device-id>
```

Today includes the clay mascots, floating space selector and Inbox over a light-butter card, people filters, person-aware mood and calendar cards, Pending/Covered tasks, and a direct Done tab. Each of six mood poses has Sky, Butter and Rose clay variants; the author chooses color independently of mood. New tasks require acceptance before becoming Covered. Calendar plans support all-day/timed dates, participants, notes, and author-only editing/removal. The floating glass-clay dock keeps Today / Moments / Space. Moments includes a swipable clay TV, standalone photos, task completion photos, expansion and export. The custom camera and system photo chooser feed a shared preview. Task changes and accepted photos persist locally (app-private database on mobile, IndexedDB on web); moods and calendar plans still reset. Jamie remains the fixed local identity. Other members' moods are seeded local fixtures, not messages from their devices. No photos are sent to other devices. Product screens omit development labels; these limitations remain documented here.

```sh
flutter analyze
flutter test
# Optional rendered review images in build/review/:
flutter test --dart-define=CAPTURE_DEMO=true
```

See [photo verification and platform limitations](docs/ui-polish-media-verification.md) and [floating-header/mood verification](docs/floating-header-moods-verification.md) for checks specific to each slice. Earlier foundation build failures remain recorded historically.

To try the signed-in shared-space flow against local Firebase emulators, follow [the local online setup](backend/firebase/README.md). Its start target is `lib/main_online.dart`; the default `lib/main.dart` remains the visual/photo prototype. The online trial now uses the Soft Pop Today and Moments layouts alongside the existing Space tab. Moods and calendar plans are shared through emulator Firestore with member-scoped reads and server-authorized writes. Moments uses the clay TV, custom camera/gallery composer and photo viewer, but its photos are saved only on this device for the signed-in account and space; they are not uploaded or visible on another member's device. The online task cards and actions work, while the full fixture task-detail/photo-completion flow is not yet connected. Live location and other launch features remain separate work.

Next: verify capture, picker recovery and photo-library export on Android/iOS hardware; connect online media and the full task-detail/photo-completion flow with private Storage rules; finish account controls and remaining launch features; then address the [launch gates](docs/online-core-verification.md#remaining-work-and-launch-gates).

Open this same local repository in Codex and Antigravity. Avoid simultaneous agent edits to the same files. Tool-specific automatic skill discovery is not verified for Antigravity; its agent can read the linked skill and plans directly.

Still required before relevant launch stages: backend and operating budget approval, child-account policy, launch countries/platforms, name clearance, final payment/retention decisions, and final production asset review.
