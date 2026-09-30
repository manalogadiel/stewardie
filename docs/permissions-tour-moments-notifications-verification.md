# Permissions, tour, Moments and notifications — verification

Implemented 2026-09-30 against [the approved plan](permissions-tour-moments-notifications-plan.md). This record describes code and observed checks, not public-release readiness.

## Implemented

- Permission Allow pills are yellow, borderless, rounded and softly raised. Only the requesting card becomes busy; native requests serialize, unrelated cards retain their colors, and Continue cannot leave during a prompt. Real permission status is rechecked on resume. Android's native dialog still dims the whole app as expected. The compact mascot fits without cropping.
- Create/join/switch selects the returned space, preserves the current tab, retains selection through delayed membership delivery, and stores selection per account. Approval-pending joins do not become memberships prematurely.
- Location controls identify the actual sharing space. Switching spaces does not share with the new space. Starting there requires recipient confirmation and stopping the previous session. A trusted, client-write-protected account anchor serializes concurrent starts across devices. Collection stops locally while server confirmation retries. Cached position survives sheet dismissal.
- Tile reload and GPS refresh use compact clay icon buttons; device-location settings remain a separate action. The large map sheet opens above nested navigation and protects Android's bottom safe area. Stop is a borderless rose pill.
- Tour continuation is a centered, scrollable invitation with navigation art and Continue tour/Explore on my own. Completed/skipped tours do not replay; meaningful interrupted tours can resume. A single-stop tour omits dots. Existing real-feature highlight navigation is preserved.
- Google Calendar import entry and startup refresh are paused. Existing imported plans remain visible, read-only and labeled sync paused; native calendar/reminders remain available.
- Moments uses the existing selfie-group header and preserves the central empty-state mascot. The full-width loader is replaced by a compact rolling trio, static with reduced motion and paused outside the foreground. The expanded photo keeps original-aspect zoom/save, author/caption/task details, lower location map, six reactions and faint margin artwork.
- Like/Cheer/Haha/Sad/Heart/Mad use new clay icons and accessible labels. One reaction per account/photo can be toggled or replaced. Counts update after server acknowledgment; double taps are suppressed. The trusted media gateway validates the canonical Supabase photo, membership and account blocks; direct client writes to Firestore reactions are denied. Photo/account/space deletion cleans reaction records, including orphan parent documents. The worker prunes departed/blocked reactions.
- Account controls use a compact display-name field and neutral gray Basic tag. Deletion uses “Packing up this space…” during actual cleanup and “Poof! This space has left the chat.” only on completion; hidden-space and cleanup-retry behavior is retained.

## Notification coverage and boundaries

Firebase Cloud Messaging replaces no existing scheduler: Supabase Cron/worker remains responsible for durable routines, inbox delivery and optional push. OneSignal is unused. Missing push/photo/reaction/mood settings default on; explicit opt-outs, denied OS permission and quiet hours remain respected.

| Activity | Delivery |
|---|---|
| Task assignment, acceptance/decline, help/coverage, edit/cancellation, completion and arrival | Existing validated activity events and reminders; affected recipients |
| Calendar creation/change/cancellation, arrival and due reminders | Existing plan/event worker; authorized participants |
| Join approval/decline, member joins/departures/removals | Member activity or private account notice |
| Ownership offer/acceptance/cancellation | Validated transition; offer/cancellation targets nominee |
| New photos, grouped photo reactions, daily mood check-in | New worker paths with category preferences and current membership |
| Location start/end/expiry | Atomic trusted events; snapshot/current-membership checks; no coordinates in notifications |
| Space cleanup/failures, routine failures | Account/manager notices |
| Safety reports and account-deletion requests | Private operator review notices only |

Android foreground messages use a native notification channel/icon and stable tags; background FCM uses the same tag to avoid duplicate cards. iOS foreground presentation is configured. Lock-screen text is generic. Opening an alert goes through the authorized inbox. Account departure unregisters/invalidate tokens and clears only Stewardie update notifications. Deterministic inbox IDs, stale-action checks and an exact rollout boundary (`2026-09-30T14:40:38Z`) prevent duplicate/history-backlog alerts. The in-app inbox remains independent of push availability.

## Checks actually run

- Four focused Flutter regressions passed: short-screen tour dialog at 2x text, delayed space selection/removal, serialized permission requests, and reaction acknowledgment/double-tap suppression.
- Existing seven media UI checks and the real-target tutorial routing check passed during this implementation.
- Onboarding screenshot capture passed with real NunitoSans/Fredoka/icon fonts and real shadows. Rendered permission cards were visually inspected; review images are in `build/review/onboarding/`. All 14 generated assets were inspected; see [asset record](permissions-tour-moments-notifications-assets.md).
- Five isolated Firestore emulator tests passed, covering task confirmation, reaction-write denial, private/server-owned location state, genuine ownership cancellation, Basic quotas and account-owned tour state.
- Backend reaction/notification/event/account-deletion tests passed (17 in the initial focused run); final policy/location checks passed (13). Rollout-boundary assertions were added and passed after the deployment timestamp was fixed.
- Deno type checking passed for `media`, `space-actions` and `scheduled-work`. It identified and prompted repairs to nullable-space checks and incomplete join-plan typing.
- Focused Dart analysis reported no errors or warnings; 32 style-info diagnostics remain in the inspected source scope.
- Final Android `:app:compileDebugKotlin` passed. No release build/signing or store publication was performed.

## Deployed

Firebase project `stewardie`: `backend/firebase/firestore.rules` compiled and released. Supabase project `ulexhxfxatzlobabitpr`: `media`, `space-actions`, and `scheduled-work` deployed successfully. No new indexes were required. Post-deployment unauthenticated POST requests to all three private gateways returned 401. Required server-secret names are present; no secret values were printed or placed in source.

## Device verification still required

No Android device was connected to ADB. Actual FCM send permission/token delivery, notification-center presentation/taps, locked-screen GPS, native permission/settings behavior, two-device reaction syncing and cross-device location-start races have not been observed. iOS APNs configuration and device delivery are also unverified. These are testing/setup gates, not claimed successful integration tests.

Fully stop and rerun `flutter run` because native Android notification code changed. With two authorized accounts, check a new task/photo/reaction, foreground/background alerts and taps, sharing in space A while viewing B, Stop/expiry, and create/join selection. Also verify denied notification permission and explicit opt-outs. A failed push must not prevent the inbox/task/photo from syncing. No billing, OneSignal or public release was enabled.
