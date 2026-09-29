# Map and navigation completion plan

Status: implemented and deployed for the private pilot on September 29, 2026; physical-device and multi-account verification is still open. See [the verification record](map-navigation-completion-verification.md). Keep Today / Moments / Space, the existing Soft Pop palette, and the free private-pilot architecture. Do not activate billing or publish the app as part of this work.

## Current baseline

The Flutter app has a shared map component, Satellite/Streets tile sources, a larger Space map, fixed photo pins, a centered space selector, a notification bell, Space action tiles, and UID-based member avatars. Firestore event rules and the Supabase activity worker have been deployed. The MapTiler pilot key is in the Git-ignored `.local/maptiler.json`; the Antigravity/VS Code launch configuration loads it. Physical-device map behavior and two-account notification delivery have not been verified.

## 1. Replace the map-style selector

- Remove the wide Satellite / Streets segmented control from the Space map and place picker. Put one 48-pixel-minimum soft raised **Layers** button over each interactive map, clear of Recenter, Close, pins, and attribution.
- Tapping Layers opens a small anchored panel with separate **Satellite** and **Streets** actions, each with an icon, readable label, and selected state. Selecting a style changes tiles in place and closes the panel; tapping outside or pressing Back dismisses it without changing style. Keep the button accessible by label and keyboard/screen-reader action.
- Satellite remains the default when a MapTiler key is loaded. Without a key, show Streets and explain in the panel why Satellite is unavailable. A tile failure keeps the existing retry control and offers Streets. Keep the compact photo map visually quiet; put Layers on the expanded photo map if style switching is useful there.
- Share this control across map surfaces rather than reimplementing the popup. Preserve map center and zoom when switching styles. A style change must not start live location sharing or change a fixed pin.

## 2. Give crowded controls breathing room

- Review Today task and calendar forms, Moments add/photo actions, Space management, the top controls, bottom navigation, and all map controls at narrow and normal phone widths. Change only pairs or groups that visibly touch or have unclear hit areas; keep the already-spaced Invite members / Routines tiles unless a device review reveals a problem.
- Use the UI plan's 4/8/12/16-pixel spacing scale: at least 8 pixels between adjacent compact buttons and generally 12–16 between larger action surfaces. Preserve 48-pixel touch targets and enough separation for destructive actions. Wrap or stack controls when enlarged text would squeeze them.
- Maintain one drag handle per sheet, safe-area clearance, and the existing Soft Pop hierarchy. Check pressed, disabled, loading, and error states so the extra spacing does not create awkward empty gaps.

## 3. Complete account-wide notifications

- Route each activity row to its specific task or ownership action after checking current space membership, task visibility, and Basic Done-history limits. If access has gone away, show a brief unavailable state and mark the item read without exposing old content.
- Include live actionable task and ownership requests in the bell count before the five-minute worker delivers history. Deduplicate live cards and worker items by space, entity, action, and task version. Keep unresolved requests actionable after being read; clear their action state once resolved.
- Query unread activity independently of the limited recent-history page, with the required Firestore index. Show `9+` when appropriate without loading unbounded history. Keep read-state writes account-owned and validate all navigation against current Firestore state.
- Ensure event delivery uses the immutable event recipient snapshot, then removes anyone who is no longer a member. Do not drop a historical coverage/completion event merely because the task changed again before the worker ran. Keep deterministic inbox IDs and retry-safe delivery. Add focused tests for repeated worker runs, assignment changes, removed members, and request/history deduplication.

## 4. Finish deleted-space cleanup

- Replace the current client-side root-document delete with a confirmed deletion request and a trusted, retryable cleanup path. First revoke membership access, then remove space subcollections including immutable events, account references/activity, and linked Supabase media; remove the root document only after cleanup succeeds.
- Show **Deletion pending** until the worker confirms completion. Preserve an operator-visible failure record for partial cleanup, and prevent a retry from deleting another space or duplicate data. Test a space with members, tasks, events, plans, and photos, including a worker retry.

## 5. Finish photo-location copy and key behavior

- For capture pins, show **Taken here** with the recorded local date **and time**, and accuracy when available. For manually placed gallery pins, keep **Place tag** and never describe its timestamp as capture time. Opening a photo must not request the viewer's GPS. Keep original-aspect zoom and saving.
- Keep the pilot key outside Git for now. Antigravity Run/Debug loads it automatically; a terminal still needs `flutter run --dart-define-from-file=.local/maptiler.json`. A literal plain terminal `flutter run` cannot read that ignored file by default. If zero-argument terminal runs become a requirement, decide explicitly whether to include a restricted public MapTiler key as a compile-time default; document the quota/exposure tradeoff before changing source.

## Verification and finish criteria

- Run focused Flutter analysis and tests for map-style state, avatar identity, camera readiness, and notification navigation/deduplication; run the Firestore rules test for event authorization and deletion access. Deploy reviewed rules/indexes and worker changes together only after local checks pass.
- On physical Android devices with two authorized accounts and one unauthorized account, test satellite loading, Streets fallback, denied GPS, disabled location services, timeout, panning, Recenter, repeated map opening, fixed photo pins, sharing stop/expiry, notification delivery/read state, and space deletion. Test iOS when a suitable device and signing setup are available.
- Review changed controls on small and large phones with enlarged text and reduced motion. Confirm no buttons touch, selected map style is apparent, map attribution remains visible, and sheets show one handle.
- Record the observed results in the rollout verification document. Code inspection, emulator tests, and a successful build do not count as native GPS, tile, gesture, or two-account verification.
