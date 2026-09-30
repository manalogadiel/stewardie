# Task actions and single-page moment viewer

Status: implemented locally — October 1, 2026. See the [verification record](task-actions-and-moment-viewer-verification.md); live two-account authorization and native gesture checks remain open.

## Confirmed requests

- Remove the normal **Synced** label from task cards.
- Fit the expanded **Your moment** image, reactions and saved-location map on one page without vertical page scrolling. Preserve Soft Pop clay styling.
- Fix acceptance and completion errors without weakening permissions or calling an unconfirmed operation successful.

## Findings from the current code

1. `TaskCard` always renders a synchronization label, including Synced. Its containing padding also occupies space on normal cards.
2. `PhotoViewer` divides the screen into a 3:2 image/details split. The details use `SingleChildScrollView`, while the location preview has a fixed 150-pixel height. Reactions, metadata and map compete for that lower region.
3. There is a concrete response-contract mismatch: Spark `actOnTask` returns `{taskId, ok: true}` after its transaction, while `FirebaseTimelineRepository.act` expects `result['task']`. When absent, it refreshes history and throws an error. This can report failure after a successful acceptance/completion. It does not prove every reported error has this cause; transaction authorization and cloud hydration still need focused verification.
4. The controller replaces most exceptions with “Could not save. Try again.” This obscures the difference between rejected writes and failure to refresh an already committed task.

## 1. Repair task actions first

- Align the backend and repository contract for accept, decline, help, handoff and completion. Treat the acknowledged operation as committed when the transaction returns success; do not require an undocumented response field.
- Hydrate the resulting task through the existing authorized task-access path, including Basic completed-history access. Do not add unrestricted direct reads of completed tasks or widen Basic history.
- If hydration fails after commitment, keep a truthful “Saved; refreshing” state and retry the read. Do not label the committed write failed or invite another mutation. Reconcile against subsequent authorized snapshots and current membership.
- Retain stable operation IDs for uncertain network responses and retries. A retry of the same completed operation must not duplicate completion records, activity events, counts or success sounds. A new legitimate transition receives a new operation identity.
- Surface safe, useful error categories: connection unavailable, task changed/unavailable, membership removed and permission denied. Preserve pending guards and server confirmation for acceptance/completion; these actions are not offline outbox writes.
- Check the transaction's operation receipt, task transition, completion record, active-task count and activity event against current Firestore rules. Fix any evidenced mismatch in client payloads/rules while preserving owner/recipient/role restrictions.
- Exercise the optional callable route as well as the default Spark route so both follow the same acknowledged-action contract.

## 2. Remove Synced from normal task cards

- Render synchronization status and its spacing only for Pending sync or Needs retry.
- Preserve retry/discard draft controls and action restrictions for unsynchronized drafts.
- Keep actual responsibility states such as Requested, Accepted and Completed. This change removes decorative sync feedback only; it does not hide errors or alter synchronization.

## 3. Redesign Your moment as one fitted page

- Use `SafeArea` and `LayoutBuilder` to budget the actual height below the app bar, including device navigation insets. Replace the details scroller and fixed flex split with one bounded layout.
- Make the image the largest flexible region, with rounded corners and `BoxFit.contain`. Preserve its original portrait/landscape aspect ratio. Pinch zoom and pan remain inside the image viewport; the page itself does not scroll.
- Use a compact author/caption row below the image. Truncate long captions in this page and let the member open their complete text in a separate detail sheet. Do not squeeze unlimited metadata into the viewport.
- Place the six clay reaction icons and counts beneath the metadata. Preserve optimistic registration, pending/error feedback, rollback and accessible reaction names. Adapt to two rows when enlarged text/counts cannot fit six across.
- Anchor a compact saved-location card at the bottom when a valid pin exists. Include Taken here / Place tag and a map preview with rounded corners. Tapping opens the existing full map and accuracy/time details. Never request the viewer's GPS or substitute their location.
- Allocate the map height from available room (initial normal-size target 100–140 pixels), rather than always 150 pixels. On short screens or enlarged text, reduce decoration and caption lines first; keep a smaller real map preview, reachable reactions and usable image viewport. Define a compact map card fallback for extreme height constraints; full details stay one tap away.
- Use cream/chalk surfaces, subtle shadows, charcoal text and the existing approved clay icons/background assets. Keep low-opacity decoration outside text/control areas. Avoid added blue borders and preserve the liked plain white controls.
- Keep Save photo and location access in the app bar. Move long save/error messages into an accessible transient message or dedicated sheet so they cannot overflow the fixed layout. Show meaningful progress without shifting the reaction/map sections.
- Photos without pins devote the freed map space to the image. Missing image, revoked space access and reaction failure remain explicit states.

## Verification and completion criteria

1. Regression tests: Spark acknowledgment without a task payload; accepted/completed task hydration; committed write followed by read failure; retry with the same operation ID; duplicate-tap guards; denied/nonmember actions. Confirm a failed write never shows success.
2. Focused rules/emulator checks: recipient accepts, owner completes, unauthorized member cannot do either; completion/event/count writes remain atomic and retries remain idempotent. Deploy changed rules only if a rule change is necessary and validated.
3. Task card checks: Synced absent with no empty status gap; pending/retry states and responsibility labels retained.
4. Viewer layouts: portrait and landscape photos, pin/no pin, long name/caption, large counts, load/save errors at 360/430 widths, short height and 200% text. No page scroller, overlap or overflow; image, reaction controls and saved map remain reachable above OS navigation. Check screen-reader names and zoom behavior separately.
5. Run changed-source analysis and targeted tests only. Record real-device/two-account limitations honestly; local fakes do not verify cloud permissions or native gestures.

Implementation order: task response contract and errors → normal-card label removal → viewer layout/style → focused verification. Preserve Today / Moments / Space, tier boundaries and existing camera/upload functionality. No paid service or public publication is involved.
