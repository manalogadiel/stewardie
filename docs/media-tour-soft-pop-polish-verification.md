# Media, tour and Soft Pop polish — implementation record

Updated September 30, 2026. Companion to [the implementation plan](media-tour-soft-pop-polish-plan.md). This records implementation and focused verification, not public-release approval.

## Implemented

- Task detail saves are serialized, expose retry errors, and use task revisions to reject stale edits. Editing an accepted task no longer accidentally requests reassignment. Completion opens from a stable navigation context and confirms the task before processing optional evidence photos.
- Completion photos use the shared media pipeline. Stable draft/attachment IDs prevent retries from consuming quota twice. Uploads enter an account-scoped durable outbox and return Pending before network transfer finishes; failures retain the photo and offer retry.
- Camera controls occupy their own fixed area below the rounded preview. The centered ratio control expands into scrollable options; capture location sits left of the shutter. Physical orientation and ratio are frozen at shutter time. EXIF normalization and cropping run together in the processing isolate. Optional GPS acquisition no longer blocks capture preview.
- New manual photo-place entry is removed. A capture pin can be switched off and back on before publication; late fixes cannot alter an already published draft. Existing saved manual pins and task/calendar destinations remain supported.
- Camera, composer and expanded photo viewing use cream/light surfaces, rounded imagery, faint existing background artwork and readable clay actions. The populated Moments header includes the new camera mascot. Existing original-aspect zoom and saving remain available.
- Onboarding paints through the status-bar area while keeping controls safe. Tour status is account-backed with local terminal-state migration and resumable stop identities. Nine actual targets include mood and calendar. New navigation artwork replaces the tour compass treatment.
- Sharing status can minimize/expand with reduced-motion handling while retaining remaining time and End. The normal shell keeps End accessible when the keyboard hides its dock. Map sharing uses the new explorer mascot, a proper Starting spinner and a compact tile-refresh button.
- People/history selections have no colored selection outlines. Avatar initials stay centered at enlarged text settings, without enlarging decorative initials beyond their fixed circle. The space-selector label remains one line. Management tiles, member menus and affected media actions use lighter pastel surfaces and spacing; plain-white controls are preserved.
- Basic permits three total space memberships, including owned spaces. Client affordances and trusted backend/rules enforce the cap; legitimate Plus limits remain 20 owned/50 total. Existing over-limit accounts retain access and can leave/delete, but cannot add memberships.
- Generated transparent assets are bundled and optimized: `clay-navigation.png`, `mascot-map-explorer.png`, and `mascot-moments-camera.png`.

## Verification performed

- Final `dart analyze lib`: no errors or warnings; 34 informational style lints remain.
- Final media framing/outbox and polish pipeline tests: 9 passed, including durable Pending before network completion, stable attachment retries, landscape crop dimensions, tour migration and sharing minimization.
- Moments layouts: 3 passed at 360/430 logical pixels and enlarged text. Other focused checks passed for failed completion recovery, photo-save retry, all nine routed tour targets, and camera controls/recovery layouts.
- Domain and trusted join tests: 11 passed. Focused Firestore emulator tests: 3 passed, including concurrent additions competing for the final Basic slot, protected task edits and owner-only tutorial state. Expected permission-denied assertions are part of these tests.
- Generated artwork and camera/Moments layout captures were visually reviewed. The camera recovery tests use a mocked/unavailable camera; they do not prove native capture behavior.

## Deployed

- Supabase `space-actions` deployed to `ulexhxfxatzlobabitpr` via the existing authenticated CLI session.
- Firestore rules compiled and deployed to Firebase project `stewardie`.
- No paid service, public publication or purchase activation was performed. Callable Firebase Functions source was updated for consistency; it was not deployed on Spark.

## Still needs owner verification

### Follow-up review repairs

The follow-up code review identified remaining gaps, now repaired locally:

- Task takeover updates the sheet's saved-assignee and owner state, so later content/checklist saves do not request a prohibited reassignment. Subtask changes now share serialized revision-checked saving, retain failed drafts and expose Retry. Saving is visible. Regression tests also exposed and fixed a disposal-time `setState` from the final autosave.
- Restored photo queues retry on initialization and foreground resume, with a 30-second retry interval while the signed-in library is active. Attempts remain serialized and use the same attachment ID; disposal cancels the interval. This is foreground/session recovery, not guaranteed OS background upload.
- Completion photos expose individual reversible capture-location switches with locating/unavailable states. Gallery photos receive no new pin. Completion freezes selected pins; async callbacks and upload preparation check the originating account, and dismissed sheets do not invoke their parent completion callback.
- The initial tour invitation now uses the same clay-navigation asset as continuation/replay. Expanded photos show the resolved author below the image.

Changed-file analysis passed with no issues. Two new task regression tests passed. Five cloud framing/outbox tests passed, including automatic retry of a restored pending attachment. Seven media UI tests passed across the initial run and the corrected camera recovery rerun; the old camera test expected IconButtons and a hidden flash control, and now checks the current clay controls and disabled fixed flash slot. No backend-rule changes or additional deployment were needed for these repairs. Real capture-location switching and account departure during a live network request still require device acceptance.

### Final reliability review repairs

- Upload failures are handled per attachment. A rejected photo stays Pending with its error while later eligible photos continue uploading in the same pass. Stable IDs and successful-item acknowledgement are preserved.
- Task detail drafts are persisted locally under account/space/task keys before saving and on dismissal. Closing while an earlier save is pending retains newer title, note, destination, assignee and checklist changes. Reopening restores the draft with an explicit Review/Retry message and uses the newly opened task revision for conflict checking. Draft writes are serialized; acknowledgements clear only their matching session/revision, so an older acknowledgement cannot erase a newer or reopened draft. Dismissal still supports the existing route controls and does not mutate disposed UI.
- Final focused run: **9 tests passed** (6 cloud/media pipeline tests and 3 task-detail regression tests). The two new cases explicitly cover a rejected photo followed by a successful photo and closing/reopening during an unfinished save. Changed source and tests analyzed with **no issues found**; whitespace checks passed. Widget tests disable only Sembast's cooperative timing pauses to avoid real-time timers inside Flutter's fake clock, while retaining the real in-memory database.
- These repairs are client/local-storage changes; no additional cloud deployment is required. Native-device, multi-account and performance acceptance gates below remain unchanged.

Run a fresh `flutter run` on the intended devices. Test portrait and both landscape captures with recognizable content, resulting pixel orientation, preview-to-shutter speed, upload completion/retry, and second-account photo/task visibility. Test permission denial, disabled GPS, map close/reopen, sharing under lock/background/network loss, minimize/expand/End and expiry. Check once-per-account tour behavior across sign-out, reinstall and a second device.

Use two authorized accounts and a nonmember for invitations, task save/completion, stale edit conflicts, membership caps and privacy. Widget/emulator checks do not establish real device latency or guarantee uninterrupted OS background execution. No measured performance comparison or broad physical-device acceptance run was performed in this round. Google OAuth, public purchases and store-release setup retain their separate gates.
