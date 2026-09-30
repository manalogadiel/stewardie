# Stewardie permissions, camera, calendar, and tour repairs

Next owner-requested phase: [media, tour, task reliability and Soft Pop polish](media-tour-soft-pop-polish-plan.md). That planning document supersedes this record where explicitly stated; its new requirements are not claimed complete here.

Status: **implementation finalized for local handoff; physical-device acceptance remains open**. Updated September 30, 2026. Use the summary below for current status. Original findings and chronological records are retained as history, not instructions to redo completed work.

Keep Flutter, Today / Moments / Space, the existing Soft Pop palette, approved clay characters, Firebase verification links, and current tier boundaries. Preserve completed repairs in `empty-space-and-tour-visual-plan.md`.

## Final implementation checklist

| Requirement | Current implementation | Evidence / remaining limit |
|---|---|---|
| Permissions and recovery | Native OS checks/requests; entry/resume refresh; borderless permission cards; camera/location Settings recovery | Focused permission/revisit/recovery checks passed. Clean-install OS prompts and real Settings return need devices. |
| Optional profile step | After Permissions; skip/change/remove; transparent open-eyed mascot; full-image confirmation and explicit square crop; draft migration | Profile/foundation checks recorded below. Real camera/gallery and deferred-upload retry need device acceptance. |
| Plus and rename | Draggable benefits-first list; state-owned rename controller; cancellation does not save | Focused sheet and dialog checks passed. Purchases retain their existing configuration gates. |
| Calendar | Shared month/year selector, documented browsing range, day clamping and retained selection | Focused picker/foundation checks passed; native visual acceptance remains open. |
| Maps | Large scrollable sheet; private cached fix with age/accuracy; selected details and Directions fit enlarged text; duration checkmarks removed; default satellite key | Actual-sheet regression and analysis passed. Owner confirmed plain-run satellite tiles. Live gestures/GPS and two accounts still need acceptance. |
| Camera / Moments | Portrait shell; independent native icon rotation; anchored clay toolbar; centered expanding size selector; location left of shutter; one saved crop; contained TV framing and saved-pin actions | Camera/media/framing checks and Android Kotlin compilation passed. Hardware output, lens/resume and second-device photos/pins remain unverified. |
| Verification / tour | Gmail inbox action; real route targets, readiness/reveal handling, seven-stop tour and per-account persistence | Focused tour/foundation checks passed. Gmail opening and production owner/member walkthroughs need device results. |
| Join / sharing follow-up | Restored Create/Join; trusted join with approval/quotas; trusted server-clock sharing expiry; retained GPS cache; Stop panel; cancelled starts and account-scoped retries | Six server-policy checks passed; reviewed existing `space-actions` function deployed. Three focused location lifecycle checks passed. Live joining and sharing still need device results. |

### Final handoff

1. Stop the previous run, then run `flutter run` from this repository. No MapTiler flag is required. Native rotation changes require a full restart.
2. Check requestable permissions and Settings return; optional profile skip/photo/crop; benefits dragging; rename cancellation; month/year selection.
3. Capture in both physical landscape directions: button positions stay fixed, icons rotate, preview remains visible, and saved dimensions match the selected ratio. Reopen the saved Moment and its location.
4. On two verified accounts, check a valid invitation (including approval when enabled), shared framing/pins, Start/End sharing, map reopening, expiry and removed-member access. Opening a map must never start sharing.
5. Walk all seven tour stops with an owner and ordinary member; reopen Space to confirm it does not automatically restart. Review enlarged text and short-screen layouts.

Send any failing step, displayed error and screenshot in the existing chat. These are acceptance checks, not further implementation instructions. Until their results are available, do not claim the whole plan or public-release readiness is verified. iOS native build/acceptance requires a Mac and device. No paid service or public publication was enabled.

### Final account-scope repair

Pending Stop retries are now keyed by both UID and space. They never run under another signed-in account, and that account does not see the prior account's pending-stop indicator. Retries resume only under the originating UID; server expiry still limits inaccessible sessions. The three focused location tests passed for account-switch retry isolation, late-acknowledgement cancellation, and GPS reuse/denied permission. This is mock/platform evidence rather than live-device confirmation.

## Original findings and investigation targets

These findings describe the defects that motivated the plan. Consult the implementation record and the continuation checklist below before editing: some causes have already been repaired.

- `permission_adapter.dart` marks camera access granted from `availableCameras()` and always checks camera/notification status as not determined. Camera enumeration is not proof of permission. Re-entering Permissions therefore loses the accurate granted presentation.
- Location already calls `Geolocator.requestPermission()`. Its missing device prompt must be investigated through actual permission/service state, native declarations, and the active build; do not assume its button is a no-op.
- Verification uses `mailto:`, explaining why the email button opens compose.
- Rename disposes its text controller immediately after the dialog returns. Cancellation already avoids the backend call; investigate dismissal-animation/controller lifetime and capture the actual exception before changing unrelated backend code.
- Plus already uses a bottom sheet, but not the requested draggable benefits-first presentation.
- Camera has a location switch with the unwanted subtitle. The photo viewer already contains saved-pin support; trace the live Moments route, authorization, and serialization before adding another viewer.
- Map member overflow, landscape behavior, and tour target visibility need reproduction in the actual screens. Passing earlier harness tests does not verify these native/layout paths.

## 1. Permission and location foundation

Repair `PermissionAdapter`, `PermissionsScreen`, Android permission declarations, and iOS usage descriptions together.

- Use a genuine native camera permission check/request. Reuse an existing suitable dependency; add a focused permission package only if needed. Do not initialize an unnecessary camera preview or request microphone access for still photos.
- Each Allow button requests its own capability. Show the real OS prompt when permission is requestable; already granted or permanently denied states cannot be forced to display another prompt. Keep Not now and Continue available. Follow [Android runtime permission behavior](https://developer.android.com/training/permissions/requesting).
- Recheck real camera, foreground location, and configured notification authorization on entry, back navigation, and resume. Persist skipped preferences separately; cached UI state never overrides the OS. Ignore stale checks that finish after a newer request.
- Remove the blue permission-card outlines. Use cream/pastel surfaces, shallow shadows, clear granted/error labels, and at least 48-pixel actions.
- Distinguish location permission denied, permanently denied, services disabled, timeout, and approximate/unavailable fixes. Provide Allow location, Open app settings, Open location settings where supported, and Retry as appropriate. Settings buttons open device controls; the app does not silently enable GPS. Recheck on return. See [Geolocator settings and permission APIs](https://pub.dev/packages/geolocator).
- Opening maps and granting permission never starts sharing. Explicit sharing still checks membership, service state, recipients, and expiry; private no-space maps retain the Join a space explanation.

## 2. Dedicated optional profile onboarding screen

Insert **Let's add your profile, {name}** immediately after **Make it yours** and before the three feature cards. Move the photo picker out of the earlier name screen, preserving any existing draft image.

- Offer Take photo, Choose from photos, Skip for now, Change, and Remove. Denied camera access leaves gallery and skipping usable.
- Preserve the current deferred, verified-account upload and pending retry behavior. Optional upload failures never block entry or lose the draft.
- Confirmation displays the full selected image using contain fitting, without forced zoom. If the final avatar needs a square crop, show an explicit crop stage and preview that exact crop. Never silently show a different framing after saving.
- Add a stable `profile` step ID and bump the draft schema. Migrate older numeric steps explicitly so returning drafts resume on the correct screen; completed accounts are not onboarded again. Recalculate progress for seven preparation screens and the eighth All set payoff. Maintain back navigation, reduced motion, keyboard safety, and long-name wrapping.
- Generate `assets/illustrations/onboarding-profile.png` during implementation: one front-facing sky-blue clay mascot matching the approved proportions/material, eyes open, holding a small cream portrait frame with a person-shaped clay silhouette and a small camera beside it. Transparent background, no lettering, no rectangular backdrop, no GIF. Use approved existing mascots as image references. Keep ambient artwork subtle and preserve the no-sparkle background decision.

## 3. Benefits sheet and rename cancellation

- Make View Plus benefits open a root-level draggable, scrollable benefits-list sheet, with one handle and compact/expanded heights. Tie the sheet controller to its content so pulling and scrolling work together. Keep Basic/Plus comparison and subscription details accessible; any purchase entry follows the existing purchase configuration gates. Use the approved US$4.99/month and US$39.99/year targets only as appropriate; store-provided prices govern an enabled checkout.
- Give the rename dialog its own state-owned controller, disposed with the dialog widget, instead of disposing it while the exit transition can still build. Cancel, barrier dismissal, and system Back return null, perform no write, and display no error. Save validates the name, checks mounted state, and reports only genuine save failures. Preserve owner authorization.

## 4. Month/year selection

In the live calendar in `online_today_extras.dart`, make the month/year title a borderless Soft Pop pill with a calendar icon and chevron. Keep previous/next arrows and Today.

- Open a compact sheet with a 12-month grid, a scrollable year selector, selected states, Cancel, and Show month. Use an explicit documented browsing range, initially current year minus 100 through current year plus 20, with navigation clamped consistently.
- Apply month/year together without creating/editing plans. Clamp the selected day to the destination month's last day, preserve the chosen person and space, and preserve all-day/time-zone behavior.
- Use one handle, generous spacing, accessible labels, enlarged-text wrapping, and scrollable content. Mirror shared selector behavior in the fixture calendar where applicable without treating fixture events as synchronized data.

## 5. Map member details without overflow

Refactor `SpaceMapSheet` so the map, selected-member details, sharing controls, and system insets fit the available sheet height. Avoid combining a fixed half-screen map with an unbounded detail section.

- Keep the map prominent; put expandable member information in a constrained scrollable section and allow the sheet to expand. Long names, accuracy, update age, stale status, and directions must remain readable.
- Deselecting/reselecting people must not duplicate detail panels or change sharing. Test short screens, landscape, and enlarged text, including location errors and sharing confirmations.

## 6. Camera, chosen framing, and Moments locations

Treat capture framing and display framing as one pipeline across `camera_screen.dart`, `photo_composer.dart`, media storage/metadata, the live Moments TV, and expanded photo viewing.

- Maximize the usable camera preview, extending behind compact floating controls where safe. Keep capture centered and controls anchored to stable positions. Rotate icons/labels smoothly with device orientation without rearranging the toolbar; respect reduced motion.
- Correct preview transforms using the camera sensor/device orientation and controller readiness, not merely the viewport ratio. Landscape must retain a visible, undistorted preview and produce correctly oriented output. Release temporary orientation constraints when leaving. Handle pause/resume and lens changes. Consult the [camera plugin's native lifecycle and permission guidance](https://pub.dev/packages/camera).
- Apply the chosen aspect ratio to the saved pixels exactly once after orientation normalization. Preserve resulting dimensions through compression, upload, thumbnails, and second-device reads. Existing photos keep their original dimensions.
- Inside the fixed clay TV screen, show the complete chosen framing with contain fitting and restrained letterboxing where needed; do not crop portrait/square images to a landscape fill. Expanded viewing remains original-aspect zoom and saving.
- Replace the location switch and its subtitle with a soft icon button: location icon when enabled, slashed location icon when disabled, plus accessible on/off tooltip and selected treatment. **Capture-location preference defaults on**, superseding the earlier off-by-default plan for this camera feature. This does not enable live sharing or background tracking.
- Obtain a fresh location only for an enabled capture around shutter time, subject to permission. If disabled/unavailable, capture still succeeds and the preview clearly offers Retry location, Settings, or Continue without location. Never attach stale coordinates as a current capture fix. Keep time/accuracy and Remove location in preview; strip embedded EXIF location from the file.
- For each Moment with a valid saved pin, add a visible location action on its TV/viewer presentation. It opens that photo's fixed map with thumbnail and Taken here or Place tag labeling. Keep any existing compact map. Never substitute the viewer's GPS. Photos without pins show no misleading active location action; optional manual tags remain explicitly manual.

## 7. Restore complete, truthful tour highlights

Keep the short no-space Create/Join path and explicit one-time continuation. After membership, cover all three tabs and the seven established feature stops, including manual replay.

- Register targets on real controls: selector, person/mood/calendar region, task actions, TV/Add moment, member/Invite/Routines region, map action, and notification bell. Each tab change must finish before measuring.
- Prepare the target's scroll position, await actual layout/data readiness with bounded cancellation, and remeasure during scrolling, size changes, and keyboard changes. Keep the highlighted control visible outside the explanation card and fixed navigation.
- Remove the blanket “This control is not available in this view yet” message. While loading, show a brief truthful loading state; on failure offer Retry/Skip. Choose a meaningful role-appropriate target for members without owner controls. Skip only features genuinely unavailable to that account, never simply because the widget has not mounted yet.
- Teaching remains visual and read-only: do not submit tasks/photos, change moods, start sharing, or mark notifications read. If a real sheet is needed, coordinate one visible surface rather than stacking a tour modal over it.
- Persist completion/skip by UID, retain explicit continuation after joining, and never restart automatically when Space is revisited.

## Build order and focused acceptance

1. Fix permission truth and settings recovery first; verify on clean native installs and after denial/Settings return.
2. Add/migrate the profile step and its mascot; verify back/resume, skip, crop preview, and failed-upload retry.
3. Repair rename lifecycle, benefits sheet, and month/year navigation.
4. Repair map details and the camera-to-TV/pin pipeline.
5. Finalize tour target preparation against the repaired real screens.

Run focused analysis and behavioral tests for permission state, step migration, rename cancel/no write, month/year boundaries, photo framing/pin preservation, and one-time tour coverage. Review layouts at 360 and 430 logical pixels, short screens, enlarged text, and reduced motion. Native-device checks must cover actual OS prompts, settings recovery, both landscape directions, lens switching, app resume, and selected-member overflow. Use two authorized accounts/devices to confirm photo framing and fixed pins survive sharing.

Record results and remaining device checks in this document. Do not claim native verification from widget tests. This plan does not enable paid services, change memberships/Plus rights, deploy automatically, or publish the app.


## Implementation progress

September 30: repaired real native permission checks/requests with permission_handler, removed blue permission-card outlines, added location-settings recovery, inserted the optional profile step with stable-ID draft migration and a generated transparent mascot, and added an explicit full-image crop confirmation. Plus benefits now use a draggable sheet; rename owns its controller through route disposal; verification opens the Gmail inbox; the live and fixture calendars share a month/year selector. Map pin boxes accommodate selection growth. The real member app shell now receives the tutorial database and real screen targets; the previous no-space-home-only wiring was insufficient.

Still in progress: camera orientation/preview/framing and capture-location button/default, fixed-map location actions, target readiness/retry/remeasure, focused regression/render verification, and native camera/location/two-device checks. Do not mark the overall plan complete from this progress record.

Foundation verification: 18 onboarding/repair tests passed (permission mapping, legacy step migration, month/day boundaries, onboarding screens and mascot paths); focused analysis found no errors or warnings. Generated profile artwork is copied into the project. Capture location now defaults on with an icon toggle; failed-location recovery and the rest of the camera pipeline are still in progress.

## Continuation checklist

The following is the handoff for the next implementation pass. “Present” means code exists, not that a physical-device acceptance check has passed. The test results above are the earlier implementation record; no tests were rerun for this planning update.

| Requested repair | Current state | Acceptance before closing |
|---|---|---|
| Pullable Plus benefits list | Draggable sheet present | Open from the account card; drag up/down and scroll the list without competing scroll controllers or duplicate handles. |
| Rename cancellation | Dialog-owned controller present | Cancel, tap outside, and use system Back during dismissal; no exception, backend write, or error message. Save still works. |
| Native camera/location prompts | Native adapter and status rechecks present | On a clean Android/iOS install, each Allow action shows the appropriate OS prompt; return from Settings and revisit Permissions without losing the real grant. |
| Location-disabled recovery | Settings actions present in permissions/map code | Services off, denied, and permanently denied produce different explanations and working recovery buttons. Resume rechecks status; sharing remains an explicit action. |
| Month/year navigation | Shared selector present | Jump to a distant month/year, preserve member/space selection, and clamp dates such as February 29 correctly. |
| Map person overflow | Shared scaled marker bounds and selected-location resolver present; details layout needs device acceptance | Selected details fit short screens and enlarged text; scroll content without covering controls, map attribution, or system insets. |
| Camera ratio, landscape, larger preview | Full-preview overlay, rotating controls, and one-time baked crop present; native behavior unverified | Both landscape directions retain a visible, undistorted preview; controls stay anchored and rotate their contents. Saved pixels, TV display, expanded image, and second-device copy all preserve the selected ratio. |
| Moments location action | Internal saved-photo map helper and viewer action present; confirm the live TV entry point | A visible location button opens the saved photo map internally with thumbnail and capture/manual labeling. Opening it never requests or substitutes current GPS. |
| Capture-location icon/default | On-by-default icon toggle present | No unwanted subtitle; on/off states are accessible. Failed fixes offer recovery or continuing without a pin, never a stale capture coordinate. |
| Dedicated profile onboarding | Profile step, migration, and artwork present | Appears after permissions, before feature cards; Take/Choose/Skip/Change/Remove work. Existing completed accounts remain completed. |
| Permission card borders | Blue outlines removed in code | Check the rendered cards, focus states, long copy, and denied/permanent-denied actions. |
| Unzoomed profile confirmation | Full-image confirmation and explicit crop present | Portrait/landscape images remain fully visible before confirmation; crop preview matches the saved avatar. |
| Verification inbox | Gmail inbox URL present | Opens inbox rather than compose, preserves the verification screen, and offers a clear fallback when Gmail cannot open. It must not claim that a link has been verified merely because the inbox opened. |
| Tour coverage and highlights | Real-route targets, bounded readiness, Retry/Skip, remeasurement, and account cancellation present | All seven stops reach actual controls across Today/Moments/Space. Remove the unavailable-view fallback and implement loading, bounded retry, scrolling, and remeasurement. Completion does not repeat on tab visits. |

### Permission state rules

Persist onboarding choices separately from operating-system authorization. A saved “Allow” tap is not proof of access. On entry/resume/back navigation, read the OS state and location-service state; a late status response must not overwrite a newer request result. Request only foreground location here. Notification permission must reflect the configured native transport and OS version rather than displaying a fabricated grant.

An OS prompt cannot be forced when permission is already granted or permanently denied. In those cases show the real state and, where needed, Open app settings. Location services being off requires Open location settings where supported; on platforms without a direct switch, explain the manual Settings path. Returning from settings must retry the private fix without starting live sharing.

### Camera and location data contract

Normalize orientation before computing the crop. Apply the selected ratio once, then generate the upload and thumbnail from those same cropped pixels. Record their true width/height, and clear or version any old framing metadata so another device cannot crop the image a second time. Preserve compatibility with existing uncropped photos and their framing metadata.

Keep capture time separate from upload time. An enabled capture location is valid only when obtained near shutter time and within the documented freshness limit; retain its recorded accuracy/time. A later Retry must not silently relabel the user's later position as where the earlier photo was taken: if it cannot recover a valid near-shutter fix, offer an explicitly manual place tag or continue without location. Gallery images receive manual tags only. Strip embedded EXIF location in the final shared file.

### Tour readiness and presentation contract

Follow the signed-in production routing, not only the fixture or no-space home. Wait for tab navigation, necessary data, and target layout; bring targets into view before measuring. Recalculate the highlight after scroll, resize, keyboard changes, or a target's size change. Dispose listeners and cancel pending work on Skip, route exit, or account change.

The explanation card must not cover the highlighted control. Use the actual control as the visual example, with role-appropriate targeting. Keep the tour read-only; navigating to a tab or scrolling is allowed, but creating content, changing preferences, sharing GPS, or marking inbox items read is not. When a target truly fails to load, keep Retry and Skip usable rather than advancing into a misleading empty highlight.

## Completion record to fill during implementation

For each checklist row record: files changed, focused check performed, result, and any outstanding native check. Reuse the existing tests where they cover the behavior; add tests for meaningful state transitions and media metadata rather than decorative layout details.

Code completion and device acceptance are separate. Before calling the full repair complete, check real permission prompts/Settings return, camera landscape/lens/resume, map selection overflow, Gmail inbox opening, and two-device photo ratio/location persistence. Until then label these items awaiting device verification. No cloud deployment, billing activation, or public release is authorized by this repair plan.


### Camera, saved locations, and tour continuation

September 30 continuation: camera controls now float over the full available preview instead of consuming its height in a Column. The camera plugin owns preview orientation; crop dimensions are computed after EXIF orientation normalization. Sensor-aware control contents animate without rearranging the toolbar and respect reduced motion. Location permission requests finish before the shutter operation, avoiding a permission-dialog/camera lifecycle race. Unavailable capture locations carry a visible recovery message into preview, with Retry, Settings, and Continue without location. Later fixes outside the near-shutter freshness window are not labeled capture locations; manual place tags remain available.

New photo attachments bake the selected framing into saved pixels once, regenerate the thumbnail, and reset framing metadata to full. Cloud uploads and local fallback storage retain these cropped dimensions and fixed pins; old framing metadata remains readable. Moments and expanded photos now expose an internal saved-location map action with thumbnail, capture/manual labeling, time, and accuracy, without requesting current GPS.

The tour waits for real target layout, reveals offscreen targets, gives loading then Retry/Skip on timeout, and remeasures as targets move. Its explanation is constrained to the available space above/below the highlight. The real Today task header now has its missing target key and a scroll preparer for lazy slivers. The map retries the private fix on foreground resume after Settings.

Verification this continuation: 31 targeted media/library/framing/foundation/tour tests passed; the existing enlarged-text unavailable-camera widget test passed separately. Its screenshot was regenerated with CAPTURE_DEMO enabled and visually inspected at 360 logical pixels with 2x text. Focused analysis reported no errors or warnings; informational brace-style lints remain. Tests use mock uploads and UI targets, so they do not prove live two-device uploads or full production-route tour coverage.

Remaining acceptance: native camera preview/output in both landscape directions, lens changes and pause/resume; real OS prompts and Settings return; two-account framing/pins; actual production-route seven-stop tour and selected-member maps at enlarged text; rendered review of other repaired screens. The full repair remains open pending those checks and any defects they reveal. No cloud deployment, billing, or public publication occurred.


## Updated execution handoff

This section supersedes earlier statements that camera framing and tour readiness have no implementation. The original findings above are historical causes, not a request to restore or duplicate old code. This review changes documentation only.

### Pass 1 — permissions and profile entry

Inspect `lib/features/onboarding/permission_adapter.dart`, `screens/permissions_screen.dart`, `onboarding_flow.dart`, `onboarding_store.dart`, `screens/profile_screen.dart`, and `lib/core/profile_photo.dart`.

1. Keep the real native permission adapter and entry/resume checks. Reproduce the user's missing prompt with actual OS state recorded: requestable, granted, denied, permanently denied, or location services off. Already-granted access should display Allowed without requesting another prompt. Returning to this step must re-read OS state rather than resetting the cards.
2. Audit Android declarations and iOS usage descriptions/configuration against the installed permission plugin. Provide recovery actions that actually open supported settings; if a direct location-service switch is unavailable, show the platform's manual Settings path. Never claim the app can turn GPS on itself.
3. Keep borderless permission cards and the dedicated optional profile step immediately afterwards. The requested transparent, open-eyed profile mascot already exists at `assets/illustrations/onboarding-profile.png`; inspect and reuse it before generating replacement art.
4. Fix the observed lifecycle hazard in `ProfilePhoto.choose`: it checks `context.mounted` before awaiting `picked.readAsBytes()`, then uses the context afterwards. Read bytes first and check mounted again before opening confirmation. Preserve full-image contain fitting and the explicit final crop preview.
5. Confirm skip, back, resume, migration of old drafts, and failed deferred upload do not block entry or erase the selected photo.

### Pass 2 — account, calendar, and maps

Preserve the draggable benefits-first sheet and `lib/online/rename_space_dialog.dart`. Verify cancel, outside tap, and Back through the entire dismissal animation; writes occur only after validated Save. Inspect the current save caller before changing backend authorization.

Keep `lib/core/month_year_picker.dart` shared between actual and fixture calendars. Verify the month/year pill, year range, February/day clamping, selected member, and selected space together.

In `lib/online/space_map_sheet.dart`, verify the selected-member details as well as `member_location_pin.dart`: fixing marker bounds alone does not prove the bottom panel fits. Constrain/scroll detail content at short heights and enlarged text, retain reachable Close/Recenter/sharing controls, and clear a selected member's expired or inaccessible session. Never replace another member's missing coordinates with the viewer's private fix.

### Pass 3 — camera through shared Moments

Trace the actual path through `lib/features/media/camera_screen.dart`, `photo_composer.dart`, `media_library.dart`, cloud upload/readback, the Moments TV, and `photo_viewer.dart`.

- Reuse the current maximized preview and anchored controls. Check both landscape directions, both lenses, permission prompts, background/resume, and shutter output on hardware. Change transforms only when an observed distortion explains the change.
- Keep orientation normalization followed by exactly one crop. Check saved and uploaded width/height and full framing metadata, including the thumbnail. The fixed TV should contain the selected crop with letterboxing as needed; it cannot display every chosen aspect ratio edge-to-edge without cropping.
- Keep the default-on location icon and accessible on/off states; remove the old subtitle wherever a legacy route still exposes it. The preference applies to capture pins only. It never starts live sharing.
- Preserve a near-shutter fix, recorded timestamp, accuracy, and EXIF stripping. Retry after that window must offer an explicitly manual tag rather than claiming a later position was the capture location.
- Confirm a visible location action in the **actual live TV** and expanded viewer. It must open the saved pin internally, with thumbnail and Taken here/Place tag labeling. No-pin photos should not show an active location action. Opening a pin must not request GPS.

### Pass 4 — verification and tour

Keep the Gmail inbox URL in `screens/verify_email_screen.dart`; test opening inbox on a device and failure recovery. An opened inbox is not proof of email verification: only refreshed Firebase verification status advances the flow.

Use the current target registry, overlay, entry gate, and coordinator instead of writing another example tour. Walk all seven stops through the production Today/Moments/Space routes with an owner and an ordinary member. Wait for target readiness and scroll it into view; Retry/Skip is a failure state, not the normal replacement for a highlight. Check manual replay, first-membership continuation, account switching, and no automatic restart on Space visits. Teaching must not submit content, start GPS sharing, or mark inbox items read.

### Focused verification and completion

Reuse `test/repair_controls_test.dart`, `test/repair_foundation_test.dart`, `test/tutorial_test.dart`, `test/tutorial_routes_test.dart`, and the existing media/framing tests. Run only checks affected by actual edits; do not repeat broad builds to establish native permission or camera behavior. Fixture and mock-upload tests are useful regressions, not live synchronization evidence.

Record each outcome under four separate labels: **source present**, **local check passed**, **device check passed**, and **still open**. This review established source presence only; earlier test records remain historical evidence with their stated limitations.

Close the plan only after: clean-install native requests; granted/denied/Settings-return states; portrait and both landscape camera outputs; selected-person map layout; Gmail inbox opening; two-account photo ratio and pin persistence; and all seven production tour highlights. Review 360/430 logical widths, enlarged text, keyboard/safe areas, and reduced motion. Do not enable billing, change tier rights, publish, or redeploy unrelated backend services as part of these repairs.


### Latest lifecycle and location-recovery pass

Implemented after the planning review:

- `ProfilePhoto.choose` now rechecks the screen lifecycle after reading selected bytes, preventing a confirmation dialog from using a departed screen.
- Permissions recheck OS grants and location-service state after each Allow action as well as entry/resume. The focused revisit test also verifies that returning with enabled services removes the disabled-services message.
- A shared location-settings helper handles unavailable native shortcuts and provides a manual device Settings path. iOS guidance follows [Apple's Location Services instructions](https://support.apple.com/en-us/102515). Onboarding, maps, and photo recovery retain usable explanations when settings cannot open.
- Private map fix requests ignore stale results, distinguish requestable denial from blocked access, and handle service/API failures. Recenter uses the same recovery path. The externally owned map controller is disposed when its sheet closes; opening/closing maps does not leak that controller or stop an independent sharing session.

Verification performed in this pass: focused analysis of the edited Dart sources and test found no errors or warnings (seven informational brace-style lints); the permission revisit/settings-return regression passed. No full build, live write, native camera capture, deployment, or billing action was performed. These checks do not close the physical-device and two-account acceptance gates listed above.


### Camera permission recovery and control rotation

The native camera's access-error screen previously instructed the member to use Settings but lacked a Settings action. `camera_screen.dart` now exposes Open camera settings specifically for access failures, opens the native app settings, and retains gallery selection and a manual explanation if the shortcut fails. Flash and lens-switch icons now use the same orientation-aware rotation wrapper as the gallery/location controls; their toolbar positions remain unchanged.

Verification: two focused camera recovery widget tests passed, including a mocked CameraAccessDenied error, actual platform-channel dispatch to openAppSettings, reachable recovery at 640 × 360 with 2x text, and retained gallery access. This proves UI/channel behavior in the harness, not physical lens orientation or OS permission settings. Camera preview/output, clean-install prompts, real Settings return, live tour roles, and two-device photo persistence remain required device checks.


### Device report follow-up: portrait app, space entry, maps, sharing

The owner's latest report supersedes the earlier assumption that the whole app should rotate: lock the app shell to portrait while camera capture and icon rotation continue following physical device orientation. Flutter startup and native Android/iOS orientation declarations now agree; camera code does not unlock the shell. Recheck both physical landscape directions for a stable toolbar, rotated controls, and correctly oriented photo pixels.

Restored Create a space and Join with a code at the bottom of the actual signed-in shell selector. They reuse the existing create dialog/backend operation and QR/code join sheet; the no-space entry points remain present. No additional intermediate screen or duplicate Space-tab actions are introduced.

Plain `flutter run` now supplies the user's public pilot tile key, with build-time override retained. See the updated map rollout instructions.

Location start previously attempted to read its own missing or expired session before deleting it. Recipient read rules intentionally reject those documents, so that read could prevent the first share from starting. The client now deletes its own session directly (permitted by the owner delete rule) before creating a new rule-validated session; recipient and expiry restrictions remain unchanged. A native update-stream initialization failure after a successful server acknowledgement now preserves the visible active session and End action, with updates marked unavailable. Successful Start closes the map sheet to expose the persistent soft cream/sky/rose sharing panel above the dock. End stops local collection immediately and retains truthful pending-server status.

No Firestore rule relaxation or cloud deployment is required for this client repair. Hardware orientation/GPS and two-account sharing still require owner confirmation on the rebuilt app.


Focused follow-up verification: five tests passed for signed-in-shell Create/Join entry points (dialog cancellation and code sheet), the enlarged-text sharing panel and End action, and map-layer selection/layout. Analysis found no errors or warnings, with existing style-only informational lints. Android XML and iOS plist parsed successfully with portrait-only declarations; iPad requires full screen for this policy. Widget-test tile requests receive the test harness's synthetic HTTP 400 responses, so these tests do not validate the MapTiler account/key or live tiles. Sharing names are bounded to the rules' 60-character limit and unusably imprecise fixes give an explicit message instead of an opaque rules failure. Rebuild with plain flutter run; no extra map flag or backend deployment is needed for these changes. Native camera rotation and live GPS/session visibility remain device acceptance checks.


### Provider and location authorization verification

September 30: a single live HEAD request to the configured MapTiler satellite tile endpoint returned HTTP 200 with image/jpeg. No image was downloaded and no billing or dashboard configuration was changed. This verifies that the configured key and sampled satellite endpoint were accepted at check time; it does not prove every device's connectivity or gesture behavior.

Two location-only tests passed against the local Firestore emulator using the repository's current rules. The new regression reproduces the denied read of an absent session, proves owner deletion followed by creation succeeds without that read, seeds an expired session locally, verifies both owner/recipient reads are denied, and proves the same delete/create sequence restores authorized recipient access while outsiders remain denied. The existing test also rejects invalid coordinates, collection listing, and recipient deletion. The emulator stopped successfully after the checks; no live location/session record or cloud rules were written.

These results confirm the location-start authorization repair locally. Physical GPS fixes, device orientation with the portrait shell, two-account live updates, and remaining original native acceptance checks still require rebuilt-device results.

### September 30 device-report follow-up

Owner confirmed plain `flutter run` loads satellite tiles and the persistent sharing End panel works. Remaining reports were stationary camera icons under physical rotation, inaccessible joining, slow/repeated map location lookup, and duration checkmarks.

- Keep the portrait app/activity configuration. A native orientation channel now drives camera-control rotation independently of the locked layout, with boundary hysteresis on Android and UIDevice orientation notifications on iOS. The shutter and other toolbar slots remain fixed; capture orientation remains handled by the camera plugin. Close, gallery, location, shutter, flip, flash and ratio-option contents rotate. The centered size-selector label stays readable in the portrait shell, while its icon rotates.
- Replace the strip with one centered Photo size pill and expanding ratio options. Camera controls use raised cream/pastel surfaces and shallow shadows. Location is immediately left of the shutter. Reduced motion switches options without a size animation; a focused test caught and removed a zero-duration AnimatedSize layout assertion.
- Route live invite redemption through the existing trusted `space-actions` function. The previous client transaction attempted to read the private space before joining, which the membership rule correctly rejects. The server verifies the Firebase identity and email, invitation expiry/revocation/redemption, approval, 20-member space limit and Basic/Plus account quotas. Atomic compare-and-set writes preserve membership, account references and activity recipients; conflicts retry without promoting roles or changing entitlements. Grouped invite codes accept hyphens. Duplicate scans are guarded and the join sheet closes before the parent callback. Rules have not been relaxed. The older client-only emulator redemption branch remains unchanged; these join checks exercise the new trusted policy, not that branch.
- Deduplicate overlapping location requests and reuse a permission-checked fix up to 30 seconds old. Retain the recent coordinate when reopening the map; device last-known fixes up to ten minutes old are labeled as cached while refreshing. Timeouts retain that recorded coordinate with a retry message. Starting sharing still needs a valid fix and server acknowledgement. No lookup promises instant GPS or starts sharing automatically. Duration chips no longer show checkmarks.

Verification: four Node join-policy checks passed, three focused camera widget checks passed, and one location-platform test passed for concurrent lookup, cached reopening and denied permission. Focused Dart analysis found no errors or warnings (style-only informational lints). The camera-control and enlarged-text recovery screenshots were rendered; the camera-control screenshot was inspected, with mocked unavailable camera hardware. Android `:app:compileDebugKotlin --offline` succeeded. The reviewed `space-actions` function was deployed to the existing project `ulexhxfxatzlobabitpr`; no billing or publication was enabled and no real member was added during tests.

Acceptance still requires a full `flutter run` restart, physical rotation/capture, cold GPS and reopen checks, and joining from a second verified account (including owner approval when enabled). iOS native compilation is unavailable on this Windows host. Existing original plan device/release gates remain open.

### Final map detail review

The actual selected-person panel still described a cached private fix as current and omitted its timestamp/accuracy. Private-pin data now carries the recorded fix metadata and labels it Private / not shared with update age, accuracy, and a stale marker where appropriate. The map title can wrap beside Close. A focused test of the actual `SpaceMapSheet` at 360 × 640 with 2x text reproduced a horizontal overflow in the selected-name/Directions row; Directions now sits beneath the readable name and status in the sheet's existing scrollable content.

The selected-panel regression passed after the repair, including a long account name, a three-minute-old private fix, scroll access to Directions and Close, and teardown. It selects through the real pin callback because synthetic HTTP 400 responses in widget tests display the map's tile-error card over the center marker. This verifies panel state/layout, not native marker gestures or live tiles. Focused analysis of the changed map and test found no issues.

Implementation work is present for the latest plan; completion remains unproven at its required hardware/live-account scope. Remaining acceptance requires owner/device results for clean-install permission prompts and Settings return, landscape capture/rotation and lens/resume, real selected-member map gestures, Gmail inbox opening, two-account shared framing/pins and joining, and the seven production tour stops. No account was reset and no real photos, memberships or sessions were created to simulate these checks.

### Connected-device location-start diagnosis

Read-only ADB inspection found the connected Samsung A32 running an APK installed September 30 at 15:30:23. Its process logs include denied location-session writes during attempted sharing. That build includes the native camera rotation bridge but predates the later map detail repair. Logs alone do not establish camera-orientation, capture or tour acceptance.

A read-only Firebase Rules API check confirmed that deployed location rules match the local authorization boundary, including owner deletion and a strict server-time upper bound on expiry. The client still calculated expiry from the device clock; the sampled phone time was slightly ahead of the workstation. This exposes a clock-skew rejection risk even with valid permissions and membership. The denied production writes are observed; their exact individual rule predicate cannot be inferred from the generic log message.

Live `startLocationSession` now calls the existing trusted `space-actions` function. The server verifies the Firebase identity, current membership, deletion state, allowed duration, coordinates and accuracy; derives the recipient snapshot from the space; sets server-controlled start/update/expiry times; and commits atomically with a space-version precondition. Caller-supplied timestamps, UID and recipients do not control the session. Coordinates are serialized as Firestore doubles where needed. The existing expiry/recipient read rules, client coordinate updates and owner Stop permission remain unchanged. The legacy emulator-only client path remains unchanged.

Six join/location policy checks passed, including server-time expiry independent of caller timestamps and refusal of nonmembers/deleted spaces/invalid fixes. Focused analysis of the two changed Dart sources found no errors or warnings. The reviewed existing function was deployed; no location session, membership, permission or account was changed by these checks. The client must restart with the new source to use this action. Native start, updates, stop and expiry still need a rebuilt-device/two-account check before declaring the plan complete.

### Pending sharing lifecycle

Source review found that Stop/sign-out during a pending GPS or server request could be followed by a late acknowledgement that reactivated collection. Sharing now uses a cancellation revision, captures its backend/account identity, rejects overlapping Start requests, and ignores cancelled restore/update initialization. Stop clears local active state before awaiting native stream cancellation. A cancelled server acknowledgement never enables the session locally; cleanup is attempted only under the original account rather than deleting a different account's session. Server expiry remains the access boundary when cleanup cannot be acknowledged after sign-out.

The focused location suite passed both the late-acknowledgement cancellation regression and concurrent/cache/denied-permission behavior. The cancellation test confirms local sharing remains off, no active space is installed, and the acknowledged session receives a cleanup attempt. This is mocked-backend evidence, not a live sign-out or remote deletion acceptance result.
