# Main Flutter app + Firebase integration plan

Status: **proposed, not implemented**. Updated September 23, 2026.

## Decision to preserve

The default `flutter run` path (`lib/main.dart` → `lib/app.dart`) is the approved Soft Pop app. Keep its Today, Moments, Space, task detail, camera, clay TV, mascot assets, mood/calendar cards, floating controls, navigation, and responsive styling. The separate `lib/main_online.dart` is an emulator experiment and must not replace those screens. Reuse its auth, Firestore, Functions, rules, and domain logic as infrastructure. Do not make the online preview the product entry point.

## Why Firebase Console is empty

The current online code connects to local Firebase Auth, Firestore, and Functions **emulators** under the `demo-stewardie` project ID. That ID is not a cloud project. This was intentional for the user's local-only trial and the instruction not to enable paid services. No Firebase Console project, app registration, production config, billing, deployment, Cloud Storage bucket, or real email delivery has been set up. The local founder Plus grant is tied only to a simulated verified emulator account; it is not a production entitlement.

## Implementation sequence

1. **Freeze the approved UI.** Capture baseline phone/large-text screenshots and widget tests for the default app. Keep `TodayScreen`, `MomentsScreen`, `TaskDetail`, `SpaceScreen`, shared clay components, and asset paths as the rendering layer. Remove no feature because the online backend lacks it.
2. **Add sign-in to the default entry point.** Initialize emulator-only Firebase in `main.dart` during local development, route signed-out users to the existing online sign-in/verification/recovery flow, and route signed-in users into the existing `StewardieApp` shell. Replace the fixed `me` identity with the authenticated UID in state and permissions. Preserve a clearly separated fixture mode for UI review and tests.
3. **Adapt data under the current screens.** Evolve `TimelineRepository` and Riverpod providers from synchronous fixture getters to account/space-scoped streams and async commands. Map Firestore members/tasks/check-ins/plans into the existing domain models; preserve server-authorized task transitions and Basic/Plus history boundaries. Wire the existing Space selector and member filter to live membership. Ensure switching account or space invalidates old scoped state.
4. **Restore every existing interaction against online data.** Keep the approved task card/detail/add/completion UI, mood color and clay pose chooser, per-person calendar and plan editor, pending/done tabs, and Moments TV/composer/viewer. Connect each behavior to the appropriate backend service. Where online support is absent, implement the backend and rules first; do not replace a designed screen with a placeholder. Photo upload/sharing and completion-photo publication require private Cloud Storage design and budget approval before live enablement. Until then, keep photos explicitly device-local in the local trial.
5. **Verify the default run path.** Run `flutter run` without `-t` in Antigravity, plus `flutter analyze`, widget/domain tests, emulator integration/rules tests, and a phone-sized visual comparison with the baseline. Verify two accounts in one space see the same task/mood/calendar state, personal Plus remains personal, and unauthorized writes fail. Test camera/export on Android hardware separately.
6. **Complete the remaining approved roadmap in stages.** After the main screens use signed-in data, add private shared media and completion photos; full member/invitation controls and account deletion; offline reconciliation; routines and reminders; notifications; and opt-in location sessions. Track child-account policy, privacy/legal work, real email delivery, store billing, and release preparation as launch decisions or gates, not as hidden UI placeholders. Use the existing product, UI, subscription, and technical plans as the source for each stage.

## Firebase setup gate

The local emulator integration can be implemented without a Firebase Console project or paid services. Creating a real project is a separate step once the user is ready: choose project/region and account ownership, register Android/iOS/web apps, generate environment-specific config, set Auth email delivery and domains, deploy tested rules/Functions, and define billing/budget controls before enabling Storage or other paid components. Real Gmail verification and production Plus grant belong after that gate. Store publishing is later still.

## Acceptance criteria

- `flutter run` opens the approved Today/Moments/Space shell after sign-in; the old UI and assets remain intact.
- The space/member filters, tasks, moods, and plans are scoped to the authenticated user and chosen space; no fixture identity or data leaks into signed-in mode.
- Basic users retain unfinished tasks and shared completion; the founder Plus grant upgrades only that account.
- Every online limitation, especially device-only photos before private Storage, is stated accurately in documentation and never silently presented as shared.
- No paid Firebase service, live deployment, store account, or publication is enabled as part of the local integration.
