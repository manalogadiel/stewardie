# Stewardie — media, tour, task reliability and Soft Pop polish

Date: September 30, 2026. **Planning only; this document does not claim these new changes are implemented or tested.**

This is the next implementation plan after [permissions, camera, calendar and tour repairs](permissions-camera-calendar-tour-fix-plan.md). It supersedes that plan where the owner now requests a reserved camera toolbar, no new manual photo pins, nine tour stops, and the updated presentation below. Preserve Flutter, Today / Moments / Space, existing features, approved clay character identity and the owner's preferred plain-white buttons.

## Confirmed decisions

- Keep the application portrait-only. Physical device orientation controls captured photo orientation and camera-control rotation, without moving the controls.
- Remove the blue band from onboarding; paint its pastel background to the screen edges while keeping interactive content clear of system bars and cutouts.
- Offer the tour once per account after initial setup, never on every login or Space visit. Keep explicit replay. Add separate Mood and Calendar stops, making nine stops.
- Remove manual place creation from photo flows. Preserve already-saved pins and task/calendar destination features. Location attachment remains optional and switchable; it never starts live sharing.
- Use light cream camera/viewer surfaces, rounded photo previews, subtle background artwork, and borderless clay controls. Preserve plain-white buttons the owner already likes.
- Basic may belong to **three total spaces, including owned spaces**. At three, disable both Create and Join, with an explanation. Keep Plus limits unchanged. Existing over-limit accounts retain their spaces and unfinished work.
- No paid services, public publication, feature removal beyond the explicitly requested manual photo-place removal, or entitlement changes beyond the Basic membership cap.

## Findings from the current code

| Finding | Evidence | Meaning |
|---|---|---|
| Capture waits for optional GPS before returning the photo | `camera_screen.dart`: `await locationFuture`, with a 12-second timeout | A photograph can appear stuck despite capture having finished. |
| Physical rotation is used for controls but not for the capture lock | Same file: `physicalTurns` drives buttons; `lockCaptureOrientation` uses `controller.value.deviceOrientation` | Likely cause of landscape buttons with portrait output under the portrait activity; confirm on hardware. |
| Camera pixels are decoded on the UI isolate for ratio calculation | Same file: `img.decodeImage` / `bakeOrientation` inside `capture` | High-resolution photos can block rendering; composer already has an isolate processing path to consolidate around. |
| Preview occupies the full Stack behind positioned controls | Same file: `Positioned.fill` plus toolbar overlays | Confirmed mismatch with the newly requested non-overlapping layout. |
| Manual-place and X-remove controls remain | `photo_composer.dart`; completion sheet also has a typed location field | Both entry paths need the same updated photo-location policy. |
| Upload waits can block callers behind the pending queue | `cloud_media_library.dart`: add → share → awaited `retryPending`, sequential pending uploads | Saving a new draft can wait for older uploads. Measure processing, transport and server stages separately. |
| Completion photos use a local-only store before task completion | `task_completion_prompt_sheet.dart` → `OnlineMomentsStore.add` in `online_moments.dart` | These photos are not sent through the shared cloud pipeline and lack `taskId`; retries can save photos again. |
| Completion creates a fresh operation ID on each attempt | `task_completion_prompt_sheet.dart` | Lost acknowledgements need a stable retry identity, not another operation. |
| Task detail closes itself before showing completion UI with its own context | `online_task_detail_sheet.dart::_markDone` | Navigation/lifecycle hazard; move coordination to a stable parent. Actual save/permission failures still require reproduction. |
| Tour guards already exist, but state is local | `tutorial_coordinator.dart`, UID-keyed Sembast `TutorialStore` | Do not rewrite the tour. Same-device guards exist; once-per-account across devices/reinstall needs account-backed state. |
| Starting label contains a replacement character | `space_map_sheet.dart`: `Starting�` | Replace with clean text and a real progress indicator. |
| Basic currently allows 20 memberships | Firestore `maxSpaces`, trusted `join_space.mjs`, subscription plan | Three-space behavior requires rules, server and UI changes together. |

The blue onboarding band, all task-save failures and overall device speed were not reproduced during this planning pass. Treat their reported symptoms as requirements, not proof of an exact cause. No new build, deployment, benchmark or device test was run for this plan.

## 1. Task save/completion correctness first

Files: `online_task_detail_sheet.dart`, `task_completion_prompt_sheet.dart`, `online_home.dart`, `spark_backend.dart`, shared task/outbox services, Firestore rules, activity events and `task-access` gateway.

1. Reproduce create, edit and complete from both Today and task details. Record the operation, role, task state/version, connectivity and returned error code. Distinguish permission denial, conflicts, validation and slow acknowledgement; do not relax rules to hide failures.
2. Compare each atomic write with current rules: task transition, active-task counter, operation receipt, completion proof and activity event. Preserve owner/recipient permissions, Basic history restrictions and access to unfinished tasks. Read completed records through the existing authorized history path.
3. Give each action a stable operation ID, reused until resolved. Disable duplicate taps. Show Saving/Completing promptly, then only show success after server acknowledgement. Preserve drafts and provide a retry when confirmation is uncertain.
4. Have a stable parent close task details and open completion UI; never launch the next sheet from a disposed context. Guard async UI updates after dismissal/account switch.
5. Replace the completion sheet's local-only photo path with the shared media pipeline. Retain local legacy photos; do not auto-publish old private content. Store photo drafts with task ID and stable attachment IDs.
6. Task completion must remain available without a photo and must not wait on optional photo encoding/upload. Commit completion once; enqueue chosen attachments separately. Publish completion photos only after task completion is confirmed, with a task link and appropriate caption. Show `Photo pending`/Retry independently of the completed task.
7. On partial failure, do not duplicate photos, quota charges, task events or inbox items. Enforce the same Basic/Plus attachment limits in this flow as ordinary Moments.

## 2. Correct and faster camera/photo pipeline

Files: `camera_screen.dart`, `device_orientation.dart`, native orientation bridge, `photo_composer.dart`, `media_library.dart`, `cloud_media_library.dart`, private media Edge Function.

- Snapshot physical orientation and selected framing at the shutter. Use that snapshot for the native capture lock; do not use the portrait screen dimensions as capture orientation. Normalize native EXIF orientation once, then crop once. Do not blindly rotate an already-correct image.
- Original follows the captured orientation. Square remains square. Non-square presets follow physical orientation in pairs (3:4 ↔ 4:3 and 9:16 ↔ 16:9); update the visible ratio before capture so the final dimensions are predictable. Gallery imports retain their recorded orientation.
- Consolidate decode, orientation normalization, crop, compression and thumbnail generation into one reusable isolate job. Preserve the chosen output dimensions and EXIF-location stripping through upload and readback. Avoid decoding the full-resolution image twice just to determine its ratio.
- Show a local captured-photo preview promptly. Optional GPS runs independently with a visible locating state; it must not hold the entire transition for the 12-second timeout. Freeze attachment choice on Publish. A late fix must never be silently added to a photo already shared without location.
- Keep capture pins tied to a fresh, accurate fix near shutter time. If unavailable, permit publishing without location. Do not substitute an old live-sharing fix or claim a later position as the capture position.
- Persist each selected photo to the existing account/space-scoped outbox and return a visible Pending state promptly. Let the upload queue continue while the app is active and resume safely later. Do not claim guaranteed background uploads after OS termination.
- Keep upload deduplication and authorization. Reuse processed bytes for retries, invalidate only affected thumbnails/list entries, cancel obsolete work on account changes, and avoid broad refreshes after every phase. Add bounded concurrency only if measurements justify it.
- Measure tap→first feedback, shutter→preview, processing duration, upload bytes/time, and time until the second account sees the photo. Baseline and compare on the same device/network in profile mode. Targets: immediate busy feedback, no UI-thread photo processing, and no mandatory GPS/upload wait before local preview; actual network speed remains measurable rather than promised.

## 3. Camera/composer and expanded-photo redesign

- Reserve layout space for the top controls, rounded preview and bottom toolbar. The preview may use the remaining space but must not sit behind buttons. Keep shutter centered, location on its left, and gallery/flip/flash in fixed accessible slots. Put the single expanding size selector in its own reserved strip. Expanded choices must not cover the shutter.
- Use warm cream (`canvas`/`warm`) rather than pure white or the current dark background. Place faint waves and small clay details around the preview; artwork must not overlay the photograph or reduce control contrast. Rotate icons smoothly while their slots remain fixed.
- Remove `Add a manual place`, map-place picking and free-text location from camera, photo composer and completion-photo paths. This does not remove task/calendar destinations or old saved photo pins.
- Replace the X with a labeled, accessible location toggle. Off excludes the pin; On reuses this photo's eligible recorded capture fix. Keep the original fix privately in the draft so toggling is reversible. When no valid fix exists, explain why it cannot be attached; do not fabricate a pin. Gallery photos cannot receive a new manual pin or the viewer's GPS.
- Give the location control at least 12–16 logical pixels before the optional caption. Apply the same spacing in empty, locating, attached and failure states.
- Rebuild `Your moment` as a light, edge-to-edge viewing page with a large rounded image area and original-aspect zoom/save. Put author/task context below the image, then the saved-location section lower down. Preserve zoom gestures, landscape pixels, save permissions and authorized deletion.
- Existing manual pins remain explicitly `Place tag`; capture pins remain `Taken here`. Opening either never requests current GPS.

## 4. Onboarding and nine-stop tour

- Inspect the actual onboarding route's Scaffold, system overlay style, SafeArea and native launch/window background. Paint the same pastel background under the status area; keep controls safe from camera cutouts. Remove the blue band without simply deleting safety insets. Apply the route's system-bar treatment consistently and restore the next route's treatment on exit.
- Preserve the current eight onboarding steps and optional profile screen. Correct stale comments that still describe the earlier seven-screen flow.
- Keep existing tour coordination, completion/skip semantics, account-switch cancellation and no-space continuation. Add account-backed completion/skip state, with local caching and owner-only access. Never use local-store absence alone to decide that an existing account is new. If authoritative status is unavailable, avoid an automatic repeat and keep manual replay available.
- Migrate existing local completion/skip records without reopening the tour. Adding two stops must not reset existing users. Use stable stop IDs so an in-progress seven-stop tour resumes sensibly after migration.
- Nine stops: Spaces → People filter → **Mood** → **Calendar** → Tasks → Moments → Members/routines → Map/sharing → Notifications. Mood explains personal check-in versus another member's read-only mood; Calendar explains person filtering, month/year selection and plans.
- Register dedicated keys on the actual mood/calendar cards, scroll to them and wait for layout before measuring. Keep safe highlights, reduced motion, Retry/Skip for genuine loading failures, and explicit continuation after joining a first space. Teaching does not submit content, enable sharing or mark notifications read.
- Replace compass/explore artwork at the tour invitation, continuation and replay entry points with one newly generated clay navigation asset; preserve readable labels and semantics.

## 5. Location panel and map presentation

- Add a minimize/expand action to the active-sharing panel. Expanded shows status, remaining time and End; minimized retains a clear active-sharing indicator, remaining time and an immediately accessible End action. Minimizing must not stop/restart GPS or change recipients/expiry.
- Animate size/position/opacity with an interruptible 200–300 ms transition; reduced motion uses a brief fade. Keep both states clear of the navigation dock, keyboard and content. Reset to expanded for a newly started session; keep minimized state only for that session.
- Give the map sheet a cream background, a small location-themed mascot and borderless clay controls. Keep most space for the map and readable member details; do not put decoration over map labels or attribution.
- Replace `Starting�` with `Starting…` and a proper small spinner aligned with its label. Prevent duplicate starts and preserve meaningful failure/retry states and the End panel.
- Replace the long tile-error overlay with a compact clay Refresh control and a short accessible status such as `Map unavailable`. Keep a Streets fallback in the existing layer selector. Retry tiles only; do not restart live sharing or reset user panning. Avoid covering the selected-person marker.
- Preserve server-controlled expiry, membership/recipient restrictions, recorded accuracy/age, private no-space maps, and the new account-scoped Stop retries.

## 6. Moments and shared control polish

- Restyle Taken here, View task and Remove photo as consistently shaped clay icon actions with labels. Use cream/sky/light butter for ordinary actions, a restrained rose destructive treatment for Remove, and retain confirmation and author permissions.
- Use a newly generated camera-themed mascot in the Moments header. Keep TV framing, person filters and upload/error states functional. Reuse it sparingly in the viewer; do not crowd the photograph.
- Remove the blue person-selection outline and avatar-selection ring in the affected selector. Show selection with a soft tinted surface/shadow and accessibility state. Avatar identity/color must remain consistent and no checkmark may replace its initials.
- Replace the history selector's gray outline with the preferred light raised surface. Preserve selected/history semantics and Basic/Plus history access.
- Lighten Invite members and Routines tiles, especially the yellow. Use the same clay lighting/shadow language as the camera, and maintain their 12-pixel gap and enlarged-text stacking.
- Replace targeted blue clickable-text emphasis with a light-butter action surface or highlight and dark readable text. Pale yellow text directly on cream is too faint; do not make that a global text-color replacement. Keep focus indication, disabled states and destructive distinctions.
- Rebuild the member three-dot menu with a rounded cream surface, generous padding and one matching icon family for its three existing actions. Preserve which options each role can see and existing confirmations; do not expose unauthorized actions merely to fill three rows.
- Apply 8–12 pixels between neighboring controls and 16 between groups throughout affected routes. Use shared spacing/component tokens, not scattered one-off padding. Preserve at least 48-pixel targets and the owner's preferred plain-white buttons. Audit visible routes/secondary sheets rather than blindly replacing every Flutter button type.

## 7. Three-space Basic cap

- Update [subscription plan v1](stewardie-subscription-plan.md) and every runtime boundary consistently: account quota helpers, Create/Join in both shell variants, code/QR redemption, ownership transfer, Firestore rules, trusted `space-actions` join and any supported callable path.
- At three total memberships, disable Create and Join with readable `3 of 3 spaces` guidance; leave switching, leaving, deleting, task coordination and stop-sharing available. Count owned spaces within the total; do not confuse this with the separate 20-members-per-space limit.
- Trusted checks must reject bypasses and concurrent additions, including an approved invite redeemed after another device fills the last slot. Handle stale counts by refreshing the account after a server rejection.
- Existing accounts above three keep access. Block additions until below three or legitimately Plus. Existing Plus ownership/membership limits stay 20/50 and do not upgrade other accounts.
- Test Basic at 2, 3 and already above 3; Plus; two concurrent joins/create attempts; downgrade; deleted-space cleanup; and QR entry bypass. Deploy reviewed cap rules and server checks together after tests, then ship the matching client. Do not treat a disabled button as quota enforcement.

## 8. Asset brief and implementation order

Generate during implementation using the approved cutout mascots as references. All new images: transparent background, matte clay, soft upper-left lighting, approved sky/pink/light-butter palette, no text/GIF/rectangular backdrop. Inspect transparency and edges before bundling; optimize size and decode dimensions.

| Planned asset | Content and usage |
|---|---|
| `clay-navigation.png` | Small sky-blue wayfinding arrow/route marker on a light-butter clay form; readable at icon size; replace tour compass artwork consistently. |
| `mascot-moments-camera.png` | Expressive approved mascot actively photographing, with a cream camera and small matching accessory; standing/kneeling action rather than another generic seated pose. Moments header/viewer. |
| `mascot-map-explorer.png` | Approved mascot studying a folded map with a small clay location pin; supporting map-sheet header artwork. |
| Existing `background-soft-waves.png` and approved ambient assets | Reuse at low opacity around content. No sparkles, busy backgrounds or artwork over photographs. Generate a matching sparse wave/route variant only if these cannot fit the new surfaces. |

Order:
1. Reproduce and repair task completion/save, capture orientation and the shared-media pipeline; retain any failing cases as focused regressions.
2. Implement the Basic cap and account-backed tour state/migration, then the two real tour targets.
3. Generate/inspect assets and update the affected light camera/viewer/map surfaces and shared controls.
4. Add the minimizable sharing panel; audit spacing, selection, loading, failure and role-specific menu states.
5. Run changed-source analysis and focused tests, review rendered layouts, then perform the bounded device/account checks below. Update the implementation record with actual results.

## Verification and acceptance

- Local checks: task state transitions/receipts/event authorization; completion with zero/failed/retried photos; stable upload IDs; rotation/crop/thumbnail dimensions; nine tour stops and migration; cap concurrency; minimized sharing state; no duplicate sheet handles; no new manual photo pins.
- Layout: 360 and 430 logical widths, short screens, 2x text, keyboard, system insets and reduced motion. Confirm rounded previews do not clip controls; no blue onboarding band; no person/history outlines; readable butter actions; existing plain-white buttons preserved.
- Two verified accounts plus an unauthorized account: create/save/accept/complete/retry tasks; saved photos/pins/task links on the second device; cloud authorization; joining/caps; location start/minimize/expand/end and expiry. Test account switching during pending work.
- Device: portrait and both physical landscape captures with known content, native pixel orientation/EXIF, lenses, pause/resume, denied permission and unavailable GPS. Verify location attachment does not delay preview or silently change after publishing.
- Performance: compare the measured capture/encode/upload/refresh stages before and after on the same device/network. Inspect jank and memory with large images and growing Moments lists. Preserve all unrelated app features; do not claim a universal speedup from a debug build.
- Broad regression smoke list, not endless full-suite reruns: authentication/onboarding/profile, selectors, task states, moods, calendar, Moments, map/sharing, inbox, invites/roles, routines, account settings, history/tier visibility, sign-out and deletion entry points. Investigate and fix observed failures; report unsupported integrations separately.

Completion means the listed behavior is implemented and these checks have recorded outcomes. Never claim “no issues anywhere” solely from analysis or widget tests. Public release, Google OAuth, payments and iOS setup retain their separate gates.

## Additional findings for the owner

Implementation and deployment outcomes are recorded in [the September 30 verification record](media-tour-soft-pop-polish-verification.md). Physical-device and two-account acceptance checks remain explicit gates.

1. **Completion photos can remain local-only and unlinked.** Included in this plan because it directly affects the reported task/photo reliability; it needs more than styling.
2. **Tour completion currently lives on the device.** Account-backed state is recommended here to make “once per account” survive reinstall or another phone; preserve local completed/skipped users during migration.
3. **Several task errors expose raw exception strings.** Include concise recovery messages for the repaired task paths; an app-wide error-copy cleanup can be a separate follow-up if desired.
4. **Over-limit Basic accounts need preservation, not eviction.** This plan keeps their access and blocks only additions. No data deletion or automatic member removal is proposed.
5. **Legacy/fixture and live paths coexist.** Audit which routes the signed-in app actually uses before editing. Removing unused duplicate screens is optional cleanup; do not remove them as a shortcut for performance.
