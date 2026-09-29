# Map and navigation completion verification

Status: code and backend deployed for the private pilot on September 29, 2026. Native map behavior, two-account notification delivery, and end-to-end deleted-space cleanup still require device/live verification. This record distinguishes implemented behavior from observed results.

## Implemented

- One 48-pixel **Layers** button opens Satellite and Streets choices on the Space map and place picker; the expanded pinned-photo map has the same control. The compact photo map stays quiet. Without the ignored local MapTiler key, Satellite is disabled with an explanation and Streets remains available. Map style changes preserve the map controller and do not start sharing or change a fixed pin.
- Added separation to the crowded photo completion actions and the destructive Space action, while retaining the existing 12-pixel Invite members / Routines gap and spaced bottom dock. Removed a duplicate drag handle on the place picker. The capture pin caption includes the recorded local date and time; manually placed gallery pins remain **Place tag**.
- The bell combines live task/ownership requests with unread account activity across current spaces. Activity rows recheck membership and task access before opening the specific item, including Basic Done-history limits. Live request/history deduplication uses task version where available. The Supabase worker delivers immutable space events with deterministic inbox IDs and rechecks current membership; coverage/completion recipient snapshots survive later task changes.
- Deleting a space now writes an owner-confirmed cleanup job and revokes membership access in the same Firestore transaction. The UI shows pending or failed cleanup instead of claiming immediate removal. The scheduled worker retries Firestore subtree, account-reference/activity, and Supabase media cleanup; its job retains a failure state for operator review. The account-deletion operator tool checks for in-progress space cleanup.

## Checks run

- Firestore emulator rules: **15 passed, 0 failed** after the event-version and deletion-rule changes. The tests include event authorization, owner-only deletion requests, revoked access, and account-owned notification preferences.
- Focused Flutter widget/unit tests for Layers at narrow width with enlarged text, notification identity, and member-avatar identity: **6 passed**. Existing camera-readiness and photo behavior were checked in the preceding implementation pass, not repeated here.
- The scheduled worker's recipient-selection tests: **4 passed**. They cover immutable coverage recipients after a task changes, current-membership filtering, direct task targets, and stable inbox IDs. They do not replace a live retry/delivery test.
- Focused Dart analysis reported no errors. It reported existing style/info lints; the Dart CLI then hit a sandbox-denied telemetry-file write, so its process exit code alone is not a clean analysis success signal.
- Firebase rules and indexes compiled and deployed to project `stewardie`; Supabase `scheduled-work` function and its tested recipient helper deployed to project `ulexhxfxatzlobabitpr` after the matching worker changes. The five-minute schedule was already in place. Neither deployment enabled billing or push.

## Still to verify on devices and live accounts

1. On two authorized Android accounts and one nonmember, verify live request badges before worker delivery, worker history after the next run, read state, ownership offers, membership removal, and inaccessible-item navigation. Retry the worker to confirm no duplicate inbox items. The current test environment exposed one Android device, so this comparison was not observed here.
2. On a physical device, use the MapTiler launch configuration to check satellite imagery and attribution, Streets fallback, permission denial, disabled services, timeout, pan/recenter, repeated opening, photo pin stability, and sharing stop/expiry. Opening a photo should never request the viewer's GPS.
3. Create a **disposable** space with members, a task, event, plan, and photo, then request deletion. Confirm immediate access revocation, eventual `spaceDeletionJobs/{id}` status `done`, removal of Firestore descendants and Supabase objects/rows, and safe retry after an injected or temporary failure. Do not use a real shared space for this test.
4. Check small and large screens, enlarged text, and reduced motion for button separation, one handle per sheet, visible map attribution, and usable 48-pixel controls. Repeat native tests on iOS once a suitable device and signing setup exist.

The implementation is suitable for a private pilot, but these open observations remain release gates. If the worker marks a cleanup job `failed`, inspect Supabase function logs and the job before manually intervening; the scheduled worker is designed to retry it.
