# Task actions and moment viewer verification

October 1, 2026 — implementation of the [approved plan](task-actions-and-moment-viewer-fix-plan.md).

## Changes

- Removed Synced and its padding from normal task cards; Pending sync, Needs retry and draft controls remain.
- Fixed FirebaseTimelineRepository's assumption that every task acknowledgment contains a task object. It now loads missing task data through authorized `getTask`, including Basic completion-history access. A committed action with a failed refresh reports “Saved. Waiting for the task to refresh; retry to check.” Its acknowledgment is retained in the account-scoped repository so retrying reads rather than repeating the mutation. Uncertain writes retain the original operation ID.
- Added specific task error messages for Firebase permission, connectivity, unavailable-task and conflict failures. No permission rules or Basic/Plus boundaries were widened.
- Replaced the photo viewer's vertically scrollable details/fixed 3:2 split with a bounded, safe-area layout: fitted zoomable image, compact author/caption, clay reactions and saved map near the bottom. Map height adapts to available room. Long captions open a separate sheet; location opens its existing full map. Save feedback uses transient messages instead of adding page height. The app-bar title truncates safely at enlarged text.
- Preserved image aspect, save/retry, reaction mutation behavior, saved-pin identity and existing background art. Opening a photo does not request GPS.

## Fresh local checks

- Task acknowledgment and card-status suite: **7 tests passed**, including accept/complete acknowledgments, read failure followed by retry without a second mutation, rejected writes and all three card sync states.
- Existing media suite plus initial short-page tests: **13 tests passed**, including export failure/retry and Moments filtering/preview at 360/430 widths and 200% text.
- Strengthened the two short-page tests to include cloud reaction controls; **both passed** at 360 × 640, normal/200% text. Captured screenshots in `build/review/moment-page-short-1x.png` and `moment-page-short-2x.png`; inspected the enlarged-text screenshot. No layout exceptions were observed. Widget tests intentionally receive failed tile responses; this is not a map provider outage check.
- Changed-source analysis: **zero errors/warnings**, four existing style information diagnostics. `git diff --check` passed.

## Remaining checks

Run acceptance/completion on two real accounts to verify live Firestore permissions, transaction events and Supabase task hydration. Client regression tests use fake backend responses; no new emulator rule test, live mutation, rule deployment or native build was performed in this repair. Current operation/event/completion rule paths were inspected and left unchanged.

Check actual photo pinch gestures, system navigation insets, very large reaction counts, native saving and revoked membership on a physical device. The local viewer checks cover the specified short-screen layout, not every possible screen height. No paid service or public publication was enabled.
