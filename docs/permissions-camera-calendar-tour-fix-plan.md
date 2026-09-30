# Stewardie permissions, camera, calendar, and tour repairs

Status: repair plan with partial implementation, September 30, 2026. Updated against the current working tree. Source inspection confirms several repairs are already present; this document does not certify native-device behavior. Finish the remaining work without replacing completed repairs.

Keep Flutter, Today / Moments / Space, the existing Soft Pop palette, approved clay characters, Firebase verification links, and current tier boundaries. Preserve completed repairs in `empty-space-and-tour-visual-plan.md`.

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
| Map person overflow | Marker sizing/recovery partially repaired | Selected details fit short screens and enlarged text; scroll content without covering controls, map attribution, or system insets. |
| Camera ratio, landscape, larger preview | Remaining pipeline work | Both landscape directions retain a visible, undistorted preview; controls stay anchored and rotate their contents. Saved pixels, TV display, expanded image, and second-device copy all preserve the selected ratio. |
| Moments location action | Saved-pin viewer exists; live TV action needs review | A visible location button opens the saved photo map internally with thumbnail and capture/manual labeling. Opening it never requests or substitutes current GPS. |
| Capture-location icon/default | On-by-default icon toggle present | No unwanted subtitle; on/off states are accessible. Failed fixes offer recovery or continuing without a pin, never a stale capture coordinate. |
| Dedicated profile onboarding | Profile step, migration, and artwork present | Appears after permissions, before feature cards; Take/Choose/Skip/Change/Remove work. Existing completed accounts remain completed. |
| Permission card borders | Blue outlines removed in code | Check the rendered cards, focus states, long copy, and denied/permanent-denied actions. |
| Unzoomed profile confirmation | Full-image confirmation and explicit crop present | Portrait/landscape images remain fully visible before confirmation; crop preview matches the saved avatar. |
| Verification inbox | Gmail inbox URL present | Opens inbox rather than compose, preserves the verification screen, and offers a clear fallback when Gmail cannot open. It must not claim that a link has been verified merely because the inbox opened. |
| Tour coverage and highlights | Real-route keys/entry gate present; readiness unfinished | All seven stops reach actual controls across Today/Moments/Space. Remove the unavailable-view fallback and implement loading, bounded retry, scrolling, and remeasurement. Completion does not repeat on tab visits. |

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
