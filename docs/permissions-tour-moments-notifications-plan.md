# Stewardie — permissions, tour, Moments and notification fixes

Implemented on 2026-09-30, including the reviewed Firebase rules and Supabase gateway/worker deployments. See [implementation and verification](permissions-tour-moments-notifications-verification.md) and [generated assets and prompts](permissions-tour-moments-notifications-assets.md). Physical-device notification delivery, GPS behavior and cross-device reaction syncing remain explicit verification gates. This plan supersedes the relevant presentation choices in `media-tour-soft-pop-polish-plan.md`; its completed camera, durable-draft, independent-upload and quota fixes are preserved. Today / Moments / Space, approved clay identity, liked white buttons and free Firebase/Supabase architecture remain intact.

## Observations and confirmed decisions

- Permission cards currently share `_busy`, disabling unrelated cards during any request. Screenshot 2 also shows Android's own permission-dialog dimming: that system dimming is expected and cannot be selectively removed by styling the app. Fix app-level state, preserve the real native prompt.
- Moments repeats `mascot-moments-camera` in its header and empty state. Keep the central camera mascot; use the existing `moments-selfie-group.png` only in the header.
- Inspected `onboarding-butter-task.png`, `onboarding-mint-calendar.png` and `onboarding-rose-camera.png`: the mascots match the identity, but their props resemble flat pasted graphics. Generate coherent sculpted replacements during implementation, rather than overlaying flat icons.
- FCM token registration and server sending already exist. `PushService.onMessage` only refreshes in-app state; it does not currently present foreground device notifications. Global push and photo/reaction/mood preferences currently default off in several paths. These are integration gaps, not proof that live delivery is configured correctly.
- Live sharing records and updates use an active space ID. The map sheet currently renders its active controls from global `isSharing`, so another space can misleadingly look like it is sharing. Verify actual access as well as correcting presentation; do not assume data leakage from the screenshot alone.
- A compact tile Refresh already exists in `StewardieMap`, but the map sheet still has long location-recovery controls. Treat tile reload, GPS refresh and enabling device location as separate actions.
- Reaction controls exist in a legacy Moments route; the main expanded viewer lacks the requested six reactions. Existing reaction rules accept unchecked member writes and require a proper authorization review.

## 1. Permission cards and compact account controls

Files: `features/onboarding/screens/permissions_screen.dart`, `permission_adapter.dart`, `online/account_settings_sheet.dart`, tier chip components in `online_home.dart`.

1. Replace Allow with a light-butter pill, dark text, no border, a shallow lower shadow and a fully rounded shape. Preserve the blue Continue button as the strongest action. Allow/Settings buttons retain at least 48 logical pixels of touch area and spacing from Not now.
2. Track the requesting capability separately from its permission status. Show busy feedback only on the selected card; unrelated cards keep their normal enabled colors. Serialize actual OS prompts: if another card is tapped while a prompt is pending, ignore that tap or queue one request without launching overlapping prompts. Not now on an unrelated card can update only that card. Continue must not navigate away during a native permission request.
3. Recheck actual permission status after each prompt and foreground resume. Granted, denied, permanently denied and location-services-off remain distinct. Settings/Enable location must open the appropriate device page; never manufacture an Allowed state. Android's modal backdrop still dims the entire app while the system dialog is visible.
4. Check the clipped pink mascot above the permissions title in screenshot 1. Use a bounded, correctly fitted image and a scrollable content layout at short heights/large text; do not crop the mascot to preserve a fixed spacer.
5. Make Display name single-line with compact line-height and modest vertical padding. Remove excessive visual height without shrinking the tap target below 48. Permit text scaling and long names; avoid hard-coded height that clips text.
6. Basic uses the neutral gray/chalk tag, dark-gray text and no dot or blue tint in every account-card variant. Plus remains distinct.

## 2. Active space after create/join and isolated sharing

Files: `app.dart`, `core/demo_state.dart`, `online_home.dart`, `qr_join_sheet.dart`, `firebase_session.dart`, `live_location_service.dart`, `live_location_pill.dart`, `space_map_sheet.dart`, trusted location endpoint and rules.

1. Trace selector Create, code Join, QR Join and no-space onboarding through the same active-space selection function. On confirmed creation or membership, select the returned ID and keep the user's current Today/Moments/Space tab. Clear stale person filters for that space. If the membership stream has not arrived, retain a pending selection intent instead of falling back permanently to the old first space.
2. Persist selection per account. Approval-pending invitations must remain pending and must not select a space the user cannot access. Rejects, revoked codes and Basic quota errors retain the previous space and show recovery.
3. Expose an account-scoped active sharing space ID and resolve its current display name. The floating panel and expanded sharing sheet say **Sharing in [space name]**, plus remaining time and End. Never derive this label from the currently viewed space.
4. Space A's map shows its active session. In Space B, show **Your location is shared in [A], not this space**, with View sharing / End; do not show B as active or automatically write a session in B. Starting in B must explicitly confirm ending A and sharing with B's shown recipients; retain one active session unless a later product decision permits multiple.
5. Opening/switching maps never starts sharing. All position writes stay pinned to the captured account, active space and session identity; late callbacks from a previous session must be discarded. Include UID in the presentation session key. Recheck server expiry, recipient snapshots and membership removal with two spaces and a nonmember.

## 3. Map recovery and Android safe areas

Files: `space_map_sheet.dart`, `core/stewardie_map.dart`, photo-location sheets and the fixed toolbar/layout helpers.

- Keep the existing Satellite/Streets stack selector and plain `flutter run` key setup.
- Use one compact borderless clay refresh icon with a 48-pixel target and tooltip **Refresh map** for tile failure. Show a short status, not a long reload instruction. Retry tile requests without moving the camera or restarting sharing.
- GPS refresh gets its own clay recenter/refresh action, with a concise locating/timeout state. If location is disabled or denied, show Enable location / Settings; a refresh icon cannot silently enable OS services.
- Compute sheet height from available safe area. Apply bottom system padding exactly once, keep map attribution and final actions above Android gesture/three-button navigation, and allow the controls/member section to scroll. Do not pad only for the keyboard or the app's floating dock.
- Validate space maps, selected-member details and expanded photo-pin maps separately on Android three-button navigation and gestures, short screens and 2x text. Preserve one drag handle.

## 4. Tour content, continuation and removal of Google import

Files: `tutorial_state.dart`, `tutorial_overlay.dart`, `tutorial_entry_gate.dart`, `tutorial_coordinator.dart`, `mascot_stage.dart`, `online_home.dart`, `calendar_view.dart`, `firebase_session.dart`.

- Keep nine actual feature targets and once-per-account completion/skip state. Match every illustration and explanation to its current stop. Generated props depict real tasks, moods, native Stewardie plans, photos, people/routines, maps and inbox updates. Do not imply Google sync or unsupported functionality.
- Replace the small floating Continue tour button with a centered, rounded cream/butter invitation panel, constrained to a readable width. Use a larger generated navigation-guide mascot, **Ready to look around?**, and two spaced actions: **Continue tour** and **Explore on my own**. Present once when an interrupted/no-space tour can meaningfully resume, without auto-starting the tour or overlaying another sheet.
- Continue resumes its saved stop. Explore records Skipped so the panel does not reappear; keep explicit replay in account settings. For a no-space account, explain that the rest becomes available after joining, and keep Create/Join reachable. Avoid a permanent panel covering the user's main task.
- For a one-stop no-space tour, hide the progress-dot row completely. Multi-stop tours retain accessible progress. Avoid changing the saved stop IDs.
- Remove Google import/connect/disconnect controls and automatic Google restore/refresh from normal runtime for now. Preserve native Stewardie plans/reminders and existing imported records. Do not erase previously shared events or imply that frozen copies are still syncing: label any existing copies **Previously imported · sync paused**. Document the paused integration; prune code/dependencies only after checking there are no other consumers.

## 5. Moments loading, header and expanded photo viewer

Files: `features/moments/moments_screen.dart`, `online_moments.dart` where still used, `photo_viewer.dart`, shared clay/backdrop components.

1. Header uses `moments-selfie-group.png`, approximately 72–96 logical pixels, with responsive title spacing. The central empty-state camera mascot stays. Do not introduce a second duplicate camera mascot in the same viewport.
2. Replace the full-width blue progress bar with a small reserved loader slot: three tiny pastel clay mascots gently rolling/bobbing in sequence, plus **Loading moments** or **Sharing photo** semantics. Use Flutter transforms over transparent assets; no GIF. Do not falsely show a percentage for unknown progress. Polling with already-visible photos should use a quiet corner indicator, not repeatedly block the screen.
3. Honor reduced motion with a still trio and short status. Stop animation when hidden, inactive or idle. Retain upload Pending/Retry and empty/error distinctions; do not treat a failed fetch as an empty album.
4. Expanded photo remains the dominant, original-aspect rounded image with zoom/save. Below: author, caption/task link, reactions, then the saved-location section. Preserve the latest author fix and capture/manual pin labeling; viewing never requests current GPS.
5. Add sparse waves and distinct crawling/hello mascots around the cream page margins and metadata region, at low opacity. Keep them away from the photograph, caption, buttons and map attribution. Use responsive positions and ExcludeSemantics/IgnorePointer for decorative assets. On narrow/large-text layouts, omit excess decoration instead of shrinking functional content.

## 6. Six shared photo reactions

Desired labels: **Like, Cheer, Haha, Sad, Heart, Mad**. Canonical IDs: `like`, `cheer`, `haha`, `sad`, `heart`, `mad`.

- Place labeled clay icon pills below photo metadata and above location. Use Wrap or a horizontal accessible row so six controls never crowd the image. Minimum touch target 48, spacing 8–12; selected state uses a pastel raised/pressed treatment with accessible selected semantics. Show counts and the member's current reaction.
- One reaction per account/photo: tapping another replaces it, tapping the selected one removes it. Show Pending during saving; errors preserve the confirmed state and offer retry. Prevent duplicate taps. Reactions belong to a photo/space, never to the viewer's selected space by accident.
- Reuse the legacy Firestore reaction path only through a trusted mutation that validates the canonical Supabase media ID, ready/published state, current membership, authenticated actor and supported type. Prefer extending the existing media gateway so photo access is checked against its actual media record. Reject direct client writes that bypass validation; do not rely only on a generic `member(space)` rule. Update reader/rules/backend consistently and retain readable legacy heart/cheer entries with an explicit migration mapping.
- Do not manufacture a Firestore photo just to make a legacy reaction widget work. Handle deleted/unpublished media, removed members, user blocks and unauthorized accounts. Shared photo deletion and account/space cleanup must remove or anonymize reaction records according to the existing retention policy; cross-service cleanup must be idempotent and retryable.
- Keep counts refreshed while the viewer is visible through the existing authenticated reaction stream or a bounded refresh. Author reaction notifications aggregate bursts; no self-notifications or notification per tap/toggle.

## 7. Real device notifications through Firebase Cloud Messaging

Files: `push_service.dart`, `notification_settings_sheet.dart`, `permission_adapter.dart`, `scheduled-work/index.ts`, `event_delivery.mjs`, activity-event producers, rules/indexes and native notification configuration.

Defaults mean **in-app preferences on**, not bypassing OS permission. Android 13+/iOS still need the user's system authorization. Foreground notification payloads do not produce visible system notifications automatically; Android needs an appropriate channel/presentation path and iOS foreground presentation configuration. Sources: [FCM receiving](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [FCM setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

1. Audit the entire event chain: protected operation/event → recipients → account inbox → worker eligibility/quiet hours → FCM request → registered device → display → tap/access recheck. Report actual live delivery separately from unit-test results. Inspect server credential/API/channel configuration without printing secrets or activating billing.
2. Set global, per-space and supported category defaults to true for new/unset preferences across onboarding, settings and worker checks. Preserve explicit existing false values, denied OS permissions and user quiet hours. Onboarding notification Allow must persist the account preference and register the authorized device; devices granted before authentication must register after login. On resume, synchronize changed system permission/token state.
3. Show foreground Android notifications through a single local-notification presentation path with a configured channel and stable inbox/event IDs. Use the same IDs to avoid duplicate display. Configure iOS foreground presentation/APNs when available; do not show both native and local foreground notifications for one message. Background/terminated notification payloads use FCM's native presentation path. Notification taps open the authorized inbox/item after authentication; no location/photo/private text on the lock screen.
4. Keep Firebase credentials server-only, revoke/detach tokens on sign-out/account switch, handle rotation/invalid tokens, and preserve in-app inbox when push is denied/off/unavailable. No OneSignal and no dependence on an open phone for the worker.
5. Retain idempotent jobs, task/plan version checks, current membership checks, actor suppression, quiet-hour deferral and device/time-zone behavior. Document the existing five-minute worker latency for ordinary activity; do not promise immediate push for every event.

### Notification coverage to verify and complete

| Operation | Recipient and behavior |
|---|---|
| Join request | Space owner/authorized reviewer; approval or rejection goes to requester without exposing private space details to a nonmember. |
| Member joined/left/removed | Remaining/current eligible members; any notice to the removed person is generic and contains no restricted links. |
| Ownership offered/accepted/cancelled | Nominee or offeror as appropriate; current members receive the final ownership change. |
| Task assigned/declined/cancelled or materially edited | Requested member, creator and affected participants according to the existing action rules; no push for each keystroke. |
| Help requested/offered, coverage/handoff confirmed | Eligible audience for help; direct offer/confirmation recipients; creator and affected participants for coverage. |
| Task completed, task/routine due reminder | Creator/affected participants; assigned/eligible members for due reminders. Routine creation itself is not a repeated alert for every worker retry. |
| Calendar plan added/changed/cancelled, chosen plan reminder | Author/participants/current authorized recipients. Plan reminders remain Off until explicitly selected; push defaults do not create new reminder schedules. |
| Task/plan arrival check-in | Relevant author/participants; member-reported arrival, not verified GPS. |
| Published photo and reactions | Eligible space members for a new photo; author for grouped reaction updates. Exclude uploader/reactor from their own alerts. |
| Mood check-in | Current authorized space members if the supported mood category is enabled; no historical replay on enabling defaults. |
| Location session explicitly started/ended | Only the shown eligible session recipients, with the correct space label. No notification per GPS update and no coordinates on the lock screen. |
| Space deletion/account safety | Only meaningful authorized confirmation/status messages. Private reports go to the operator queue, never broadcast to the reported member. |

If an operation lacks an event or inbox route, add it through the existing protected event/gateway architecture; validate actual transitions, recipient selection and cancellation. Actions such as browsing, filtering, draft editing or panning do not need push alerts. Notification categories need consistent mute behavior.

Acceptance requires two real authorized Android accounts/devices and a nonmember: foreground, background, locked and normal terminated states; permissions denied; app/account switch; quiet hours; expiry/removal; retries and duplicate worker runs. Android force-stop and iOS force-quit have OS restrictions, so do not promise uninterrupted delivery in those states. iOS live push remains gated by Apple/APNs setup.

## 8. Space deletion copy

Files: `space_deletion_sheet.dart`, space selector/deletion status surfaces and cleanup worker.

- While cleanup is pending, use **Packing up this space…** with **It's closed to new activity while we finish cleaning up.** This is playful but truthful.
- Only after confirmed deletion, show **Poof! This space has left the chat.** Hide it from normal active-space choices once closed/deleted, retaining a separate recovery/status entry if cleanup fails and the owner must retry.
- Keep destructive confirmation, role checks, server acknowledgements and recoverable failure messages. Do not display a joke implying deletion succeeded while the server is still pending. Do not auto-delete unrelated shared records to remove the status.

## 9. Asset generation brief

Generate during implementation with the approved original mascot cutouts as image references. Transparent PNG/WebP, matte 3D clay, soft upper-left lighting, sky/rose/mint/light-butter palette, no baked text, rectangular backgrounds or flat pasted props. Inspect alpha and edges; optimize dimensions/file size. Do not replace the owner's other onboarding mascots.

| Asset | Action/appearance | Placement |
|---|---|---|
| `tour-task-helper` | Butter mascot standing/leaning, genuinely gripping a thick cream clipboard with clay checklist marks and pencil; meaningful task action. | Tasks stop and corresponding feature card. |
| `tour-calendar-planner` | Mint mascot turning a dimensional desk-calendar page, a clay date marker and small clock; no tiny unreadable text. | Calendar stop/feature card. |
| `tour-moment-camera` | Rose mascot actively composing a shot through a textured cream camera, strap and raised lens/shutter; kneeling/standing. | Moments stop/feature card. |
| `tour-mood-checkin` | Expressive mascot choosing a matching clay mood token; communicates a check-in. | Mood stop if existing art is unrelated. |
| `tour-navigation-guide` | Front-facing blue guide waving with a softly sculpted route/arrow marker; larger than the existing small navigation icon. | Centered continuation invitation. |
| Other stop-specific variants | Audit Spaces, People, Members/routines, Map and Inbox; reuse significant art or generate a group, curved repeat motif, map explorer or envelope/bell action when missing. | Relevant real-target tour stops only. |
| Six reaction icons | Like: raised thumb; Cheer: raised hands/clap; Haha: laughing face; Sad: tearful face; Heart: dimensional rose heart; Mad: expressive frown. Cohesive lighting and outline-free clay silhouettes. | Labeled reaction pills; icons never replace accessible text. |
| `moments-loader-trio` | Three tiny accessory-free clay figures designed to remain recognizable while rotating/bobbing. | Small Moments loader; motion is Flutter code. |
| `viewer-mascot-crawl`, `viewer-mascot-hello` | Distinct small poses at page margins, soft shadows and consistent character anatomy. | Expanded viewer decoration. |
| Sparse waves/curved paths | Reuse `background-soft-waves.png` first; generate compatible sparse variants only where useful. | Viewer/continuation backgrounds, low opacity. |
| Existing `moments-selfie-group` | Reuse the existing file as requested. | Moments header, replacing the duplicate camera mascot. |

## Build order and focused verification

1. Repair active-space selection, session-space labels/isolation and map safe areas first. Check two spaces, delayed membership streams, approval-pending joins and Basic limits.
2. Correct permission-card state and account controls; pause Google import. Test per-card requests, denied/settings/resume, compact name input and neutral Basic tag.
3. Implement and validate notification defaults, missing event coverage and real FCM presentation before claiming device alerts work. Deploy reviewed rules/indexes/worker changes together only where changed; do not publish or enable paid services.
4. Generate/inspect optimized assets, update tour continuation/artwork and one-stop progress, Moments header/loader, reaction controls and viewer decoration. Preserve existing camera/upload/draft fixes.
5. Run changed-source analysis and focused behavioral tests for selection intent, space isolation, permission serialization, reaction authorization/toggle/counts/cleanup, notification recipients/default migration/deduplication and tour guards. Review screenshots at 360/430 widths, short height, 2x text, keyboard, reduced motion and Android bottom insets.
6. Complete a bounded two-device live test for reaction syncing, notification-center display/taps, session privacy and create/join selection. Record missing credentials/device access as explicit gates rather than claiming completion. Document outcomes in a new verification record, linked from this plan.

No new paid tier, OneSignal, Google OAuth activation or public release was activated. Implementation and focused checks are complete; the device gates in the verification record remain unverified rather than being represented as completed tests.

## 10. Owner follow-up — October 1, implemented

These confirmed requests supersede earlier choices about plain Satellite, label-bearing reactions and waiting for acknowledgment before visible reaction feedback.

- Keep one clay tile-refresh button permanently visible on every shared map component, including healthy/loading/error states. Keep GPS recenter/settings separate.
- Replace plain Satellite with MapTiler **Satellite hybrid**, retaining Streets. Automatically center/zoom to a real personal fix at zoom 16 in the space map and place picker; respect user panning and permission/service failures. Opening a map never starts sharing.
- On selecting a task/place point, debounce reverse geocoding and fill a read-only place name. The member can edit only Location note. Ignore stale lookup/GPS results; use honest coordinates when the provider is unavailable. Preserve saved fixed pins. Provider reference: [MapTiler Geocoding API](https://docs.maptiler.com/cloud/api/geocoding/), [Hybrid styles](https://docs.maptiler.com/sdk-js/examples/built-in-styles/).
- Remove the idle loader slot and reduce the Moments header-to-person-filter gap to 8 pixels. Show the rolling mascot loader at the viewport center without blocking input or moving content.
- Reactions show only clay icons and counts, retaining accessible names. Apply selection/count feedback immediately, serialize/coalesce newer choices, ignore older reads, and visibly roll back/retry failed saves. A small syncing indicator distinguishes pending feedback from confirmation.
- Retain the avatar's profile stream across rebuilds, decode only changed data, and preserve the loaded image with gapless playback. Bound cached images to 100 profiles and clear them when the signed-in account changes. A confirmed removed picture still shows the deterministic placeholder.
- Reuse the location service for camera/composer capture fixes during live sharing. Local device fixes update before cloud throttling/upload, so upload latency cannot make camera GPS unavailable. Preserve the capture-time validity check; never use another person's position or automatically start a new live session.
- Reject repeated-key task names in create/edit paths and enforce repeated ASCII letters/digits in Firestore rules. Keep short legitimate names valid. Preserve drafts and show a useful validation error.
- Use the account-wide live notification badge in the main shell and empty-space shell. Highlight a bell with unread items and display counts capped at **99+**, with enough room for the capsule badge. Keep unread request/history deduplication.
- Bundle three original pastel bell/chime WAV assets: notification, successful task completion and photo capture. Use Android's clay notification channel and APNs sound payload, plus native UI feedback for capture/confirmed completion. Respect silent/disabled channels and OS notification settings; do not play sounds for failed saves. Sound generation is reproducible with `tool/generate_soft_pop_sounds.dart`.
- Check changed surfaces for overflow at narrow/wide widths and 2x text, including reactions, map controls and media preview. Native GPS, perceived latency and sound volume still need device observation.

See the October 1 follow-up section in the [verification record](permissions-tour-moments-notifications-verification.md) for results and remaining gates.
