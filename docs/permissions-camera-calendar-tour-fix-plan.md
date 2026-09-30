# Stewardie permissions, camera, calendar, and tour repairs

Status: implementation plan, September 30, 2026. Prepared from the reported defects and focused source inspection; no app implementation or native-device verification is performed by this document.

Keep Flutter, Today / Moments / Space, the existing Soft Pop palette, approved clay characters, Firebase verification links, and current tier boundaries. Preserve completed repairs in `empty-space-and-tour-visual-plan.md`.

## Confirmed causes and investigation targets

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
