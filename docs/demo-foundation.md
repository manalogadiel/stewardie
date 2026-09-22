# Flutter foundation and demo slice

Implemented September 22, 2026. This is a local, in-memory prototype, not an online service. Existing product, UI, subscription, and technical plans remain authoritative; proposed vendors and launch gates remain unresolved.

## Foundation

- Flutter 3.47.4, Dart 3.13.3; generated Android, iOS, and web targets.
- `flutter_riverpod` 3.4.3 for repository injection and presentation state.
- `go_router` 18.0.1 for Today / Moments / Space and task detail routes.
- Versions resolved in `pubspec.lock`. No Firebase, Mapbox, purchases, analytics, or remote font dependencies.
- `lib/core/theme.dart` contains the UI plan's colors, typography, geometry, and shared component themes. Nunito Sans is bundled for offline use.
- `lib/features/timeline/domain` contains immutable task, space, member, and mood models.
- `lib/features/timeline/data` defines the repository boundary and in-memory implementation. The repository owns task transitions; widgets do not change ownership directly.
- `lib/core/demo_state.dart` tracks selected space/person, pending actions, and failures through Riverpod.
- Feature presentation lives in `timeline/presentation`, `moods`, and `spaces`; `lib/app.dart` owns routing and the shell.

`dev.stewardie.demo.stewardie` is a development identifier, not a production registration. Generated launcher artwork remains Flutter scaffold artwork. No store signing or publishing was configured.

## Try the slice

1. Open Today in Home crew. Select Me: accepted/requested tasks and participating events remain visible; identity does not change.
2. Open Make something good, mark it done, and return to Today. Completion requires no photo. The optional photo action explains that uploads are not connected.
3. Open Water the balcony plants through Inbox. Accept or decline the request. A request alone does not assign responsibility.
4. Open Groceries for the week and offer help. Sam stays responsible. Jamie cannot confirm on Sam's behalf, and no other account is online in the demo.
5. Open Bring in the laundry. Jamie already has a seeded offer from Alex and can confirm the handoff. After confirmation Jamie cannot complete Alex's task.
6. Check in, select a labeled mood, optionally write a note, and review the Home crew audience. Update or remove it. Skip makes no change.
7. Switch to Weekend wandering crew. The person filter clears; its timeline starts empty and its mood is separate. Add a local task to populate it.
8. Space → Try the demo states configures the next task action. Failure leaves the task unchanged and permits retry. For Claim conflict, open the unclaimed recycling task and claim it; another member is shown as owner. All task actions briefly show an explicit pending demo state.

Basic can complete existing shared tasks and access unfinished/overdue work regardless of age. The history predicate covers completion dates today and the prior three days. Plus entitlements, quotas beyond that predicate, and billing are not implemented. The demo has no upgrade prompts.

## Scope and limitations

All people and tasks are fixtures. Data is held only in process memory and resets on restart. The repository's actor checks illustrate UI behavior and are not production authentication or authorization. It has no durable outbox, remote transactions, connectivity detection, real sync, media storage, invitation redemption, notifications, maps, live location, payments, or subscription verification.

The demo uses the device's local calendar day. Mood records expire at midnight and the open UI refreshes once a minute; a read also checks expiry. This is a demo convention, not approval of production retention or space time-zone policy. Online development needs named space time zones and server authority.

Moments and future Space capabilities are labeled previews. Mood faces and member initials are native vector placeholders; no concept-board crops or generated clay art are presented as production assets. See [asset notes](../assets/README.md).

## Verification

Run on this Windows machine:

| Check | Result |
|---|---|
| Flutter dependency resolution | Passed; lockfile saved |
| `flutter analyze` | Passed with no issues |
| `flutter test --no-test-assets --dart-define=CAPTURE_DEMO=true` | 20 tests passed |
| Standard `flutter test` asset compilation | Blocked by Windows Application Control for `impellerc.exe` |
| `flutter build web --no-web-resources-cdn` | Dart compilation completed; final asset build blocked by the same policy; no successful web build claimed |
| Android startup | Not verified; no connected Android device or configured emulator |
| iOS build/device | Not verified on Windows |

The test-assets option reused fonts/manifests prepared before the shader compiler failed. It did not disable or modify Windows security. Clean builds and normal tests must be rerun in a supported environment where the installed Flutter compiler is permitted. Do not treat partial files in `build/web` as a deliverable.

Tests cover acceptance/decline, allowed owner actions, help offers and confirmed handoffs, double-tap rejection, failure/retry, scoped claim conflicts, filters and back navigation, space changes, Basic history boundaries, newly completed overdue work, mood privacy/expiry/update/removal, local task creation, and the navigation destinations.

Rendered widget screenshots were inspected at 360 × 780 and 430 × 932 logical pixels, plus 360 × 800 with 200% text, and landscape at 780 × 360. The suite exercises reduced motion and simulated keyboard/safe-area insets. These are Flutter widget renders, not physical-device screenshots or proof of native keyboard behavior.

Flutter checks for labeled tap targets and 48dp Android targets pass on the initial Today screen. A rendered contrast regression check passes for the mood audience label. The broad screenshot contrast heuristic reported antialias-edge colors for some 14px variable-font text; it is not recorded as a pass. Actual theme foreground/background pairs are tested using relative luminance, with inspected screenshots:

| Pair | Contrast |
|---|---|
| Charcoal / chalk | 13.65:1 |
| Secondary text / chalk | 5.61:1 |
| White / electric blue | 5.96:1 |
| Electric blue / pale blue | 5.11:1 |
| Control border / white | 4.08:1 |

Full TalkBack/VoiceOver, native focus traversal, real permission flows, native animation playback, and Android/iOS release verification remain outstanding. No production readiness is claimed.

## Reviewed screens

- [Today, small phone](demo-review/today-small.png)
- [Today, large phone](demo-review/today-large.png)
- [Person filter](demo-review/today-me.png)
- [Task detail](demo-review/task-detail.png)
- [Mood and audience](demo-review/mood-audience.png)
- [Large text](demo-review/today-large-text.png)
- [Mood with simulated keyboard](demo-review/mood-keyboard.png)
- [Pending action](demo-review/task-pending.png)
- [Failed action](demo-review/task-failure.png)
- [Empty space](demo-review/empty-space.png)

Screens are generated from the current app by `test/demo_ui_test.dart`, with the bundled font loaded. Full fresh captures go to ignored `build/review/`; selected review artifacts live here.

Milestone 0's Android-start gate and milestone 1's user visual review remain open. The next implementation phase is the online core after backend and budget decisions; no paid provisioning is authorized by this foundation.
