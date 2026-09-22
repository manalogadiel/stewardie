# UI polish, clay moods, camera and Moments — approved plan

Status: approved by the user and implemented locally, September 23, 2026. See [implementation and verification](ui-polish-media-verification.md) for delivered behavior, adapter choices and outstanding native device checks. The original proposed defaults below record the approved direction; no paid services or publication were enabled.

Follow-up correction: the user clarified that the entire header must overlay page content, with only the selector capsule and Inbox circle visible. The current reserved AppBar area does not satisfy that behavior. See the [next header/person/mood plan](top-navigation-person-mood-plan.md), which also records person-aware calendar/mood cards, compact names, a distinct Today color and a mood color selector. That follow-up is planned, not yet implemented, and supersedes conflicting earlier wording here.

This follows the implemented [first redesign](ui-redesign-verification.md) and the user's five screenshots. The requests below are confirmed direction; dimensions, interaction details and implementation choices are proposed defaults. Preserve Flutter, Riverpod, go_router, Today / Moments / Space, the approved character family and subscription v1. No paid services.

## 1. Fix the existing layout first

| Area | Observed cause / change | Proposed result |
|---|---|---|
| Top navigation | The theme is already transparent, but a conventional AppBar still reserves a separate rectangular region. Review the shell/body painting together. | A continuous page backdrop behind floating controls: centered rounded space-selector capsule and a separate circular Inbox button. No full-width bar fill, divider, elevation or scroll tint. |
| Person chips | `PeopleFilter` explicitly sets `showCheckmark: true`. | Disable checkmarks for the entire row, including Everyone. Keep initials/photos unchanged. Selected chips retain a blue outline, soft fill, stronger label and selected semantics. |
| Mood/calendar row | The row is top-aligned and both cards size independently. | Equal outer heights, with mood stretching to the calendar/content height; retain the 12px column gap. Place the mascot in the middle and the action near the bottom. |
| Help / Covered / Done | Each number surface can expand across its column, with no gap between columns. | Keep three equal columns with explicit 10px gaps (8px on narrow widths), number above label and independent rounded surfaces. |
| Bottom dock | Expanded destination containers have no intervening gap. | Add approximately 8px between destination pills, matching the dock's inner top/bottom breathing room. Preserve readable labels, a 48px minimum target and bottom safe area. |

Top controls: approximately 48px Inbox circle, 48px minimum selector height, subtle cream/milky fills and restrained clay shadows. Reserve balanced left/right space so the selector stays centered. Long names wrap or truncate within the control, with the full name available in the selector sheet. Keep content out of the notch and tappable controls; a transparent background must not create text overlap while scrolling. Verify whether the blue status strip in the screenshot comes from the app, system chrome or the preview frame before changing it.

Equal-height implementation: use a shared responsive row layout that measures both children and stretches to the larger natural height. Refactor the calendar's nested `LayoutBuilder` if needed; simply wrapping the current row in `IntrinsicHeight` is not safe for that layout. Do not hardcode a height that clips six-row months, longer person names or scaled text. At large text sizes stack the cards and let each grow naturally.

Dock spacing must be checked again at 200% text; adding gaps must not bring back the earlier split “Moments” label. Use responsive outer gutters and destination sizing before reducing any text. Retain glass/opaque accessibility variants.

## 2. Six clay mood illustrations

Create a cohesive set after approval, using the same sky-blue companion for all moods so emotion is conveyed by pose and expression rather than a color ranking. Keep the yellow/pink companions elsewhere in the app.

| Mood | Proposed expression and pose |
|---|---|
| Happy | Gentle open smile, relaxed raised hands |
| Calm | Soft closed eyes, restful seated pose |
| Tired | Sleepy eyelids, small yawn, relaxed shoulders |
| Overwhelmed | Slightly worried expression, hands near cheeks, no alarming effects |
| Sad | Quiet downturned expression, gently tucked posture |
| Excited | Bright eyes, raised arms, one restrained blue sparkle |

Export separate transparent PNGs with consistent proportions, lighting, framing and visual size. Reuse the calm companion for the initial invitation if suitable. Replace the selected mood's `MoodFace` in Today with its clay asset; use the same family in the mood chooser with visible text labels. Keep small member indicators lightweight and labeled rather than forcing large artwork into avatar chips. Check-in skip, update, removal, audience and expiry remain unchanged. No emotion scores, rankings or compulsory cheerful poses.

## 3. One camera and photo flow, used in three places

Entry points: task details → Add photo; completion photo prompt → Camera / Choose photo; Moments → Add moment.

Build a real full-screen live camera preview with Stewardie's own overlay: rounded close button, small space/task context capsule, large raised clay shutter, camera-flip button, gallery shortcut and flash only where supported. Keep decoration outside the live image and use high-contrast controls over variable lighting. Hide the bottom dock during capture and preview.

Flow: source choice → camera or system photo picker → preview → confirm. Camera preview offers Retake; chosen photos offer Choose another. Both offer Cancel and an optional caption. Show the destination space and task association before saving/sharing. System permission prompts and the operating system's photo chooser retain their native UI; the capture, review and posting screens are custom Soft Pop UI.

Proposed Flutter integrations: the Flutter-published [`camera`](https://pub.dev/packages/camera) package provides the live preview/capture layer; [`image_picker`](https://pub.dev/packages/image_picker) handles library selection. Check compatible versions against the project's installed SDK during implementation. Do not use the picker's external-camera path as a substitute for the requested built-in camera screen.

Handle denied/restricted permissions, no camera, initialization failure, background/resume, camera disposal, unsupported flash, retake and cancellation. Still images only; disable audio/video capture. Gallery and photo-free completion remain available. Recover interrupted picker results where supported and copy accepted media out of temporary storage. The camera package requires explicit lifecycle handling; picker recovery and temporary-file handling are described in their official documentation.

Android/iOS are the target native camera experiences. Web review uses browser camera access and a file chooser; camera access needs HTTPS or localhost and browser capabilities vary. Unsupported controls should be omitted with a usable fallback. See [`camera_web`](https://pub.dev/packages/camera_web) and [`image_picker_for_web`](https://pub.dev/packages/image_picker_for_web). Do not infer native camera readiness from a desktop widget screenshot.

## 4. Task attachment and completion behavior

Add a Photos section inside task details, near the description and before completion actions. It contains an attachment preview and Camera / Choose photo actions when allowed. Proposed permissions: the task creator or current responsible person can add, subject to the attachment cap; the uploader can remove their own image. Other authorized space members can view. An offer to help does not itself grant ownership or editing access.

Explain beside an attached photo that it belongs to the current space and will appear in Moments when the task is completed. Capturing/selecting alone never publishes a photo; the preview's confirmation is required.

| On Mark done | Behavior |
|---|---|
| Task already has an attached photo | Complete the task and automatically create/update its completion Moment; no second photo prompt. |
| Task has no photo | Open a small clay sheet: “A photo for this little win?” with Take photo, Choose photo, Mark done without photo, and Cancel. The skip action is immediately visible. |
| User picks a photo | Preview → “Finish & share photo”; then complete and create the linked Moment. |
| User skips | Complete normally. Do not create an empty image post. |
| User cancels/back-dismisses the prompt | Leave the task unfinished. Cancelling capture returns to the prompt so skipping remains easy. |
| Completion fails | Keep the task unfinished and preserve the photo draft for retry; no success Moment. |
| Photo processing/publication fails after completion succeeds | Keep the task Done. Show the retained photo draft with Retry / Remove, without reporting a successful photo post. |

Apply the same completion coordinator to Today card actions and task details, so neither bypasses the prompt. Permission denial or quota exhaustion must never prevent Mark done without photo.

If a photo is added to an already completed task later, confirmed attachment creates/updates that task's completion Moment. Use a deterministic completion/attachment identity so repeated taps, retry, restart or editing a caption do not create duplicates. Keep uploader, completer and task creator as separate identities.

Proposed caption: **“{Task name} — done!”** as a predictable default, plus an optional personal caption. Preserve the title snapshot for the completion post. Standalone moments never receive a fabricated completion label.

## 5. Moments as a clay TV viewer

Replace the empty presentation with one prominent retro TV-style frame: warm cream rounded cabinet, soft clay depth, subtle rim, small decorative speaker detail and a generously sized photo opening. Build the frame as reusable Flutter drawing/widgets so it scales cleanly; keep image, labels and controls separate. No scanlines, distortion or effects that obscure the actual photo.

Show one Moment at a time, newest first in the active space. Swipe horizontally to move between Moments; provide Previous / Next buttons and “2 of 8” as an accessible alternative. No automatic slideshow. If a post has multiple permitted attachments, use explicit photo thumbnails/count inside that post rather than nesting two competing horizontal swipe gestures.

Below the TV: task completion heading or standalone caption, author, date and a separate View task action for linked posts. Tap the photo to open a full-screen viewer with pinch zoom, Close and Save photo. Keep the source aspect ratio using neutral letterboxing where needed. Saving exports the processed photo without the decorative TV frame; native photo-library saving and browser download need platform-specific adapters and genuine success/failure handling.

Add moment opens the same camera/library and preview flow, with an optional caption and explicit space audience. Work in progress, outings and everyday photos are first-class standalone posts and do not create tasks. Only the uploader may remove a photo; remove its references from both Moments and task views without undoing completion. Retain space/member filtering and a friendly empty state.

## 6. Local media foundation and existing limits

Implement real capture/import and a local Moments collection first. “Automatically published” in this phase means added to the active space's local Moments collection; cross-device delivery needs the separately approved backend. Keep this distinction in project documentation and do not show invented synchronization receipts. No cloud storage, billing or paid API setup.

Introduce separate `MediaAttachment`, `Moment` and `PhotoDraft` models plus capture, picker, processing, export and repository interfaces. Reuse one attachment between task and Moment rather than copying its bytes. Track IDs, space, uploader, optional task/completion link, caption, capture/import source, timestamps, dimensions and preparation/publication state. Source metadata is descriptive, not proof of authenticity.

Proposed durable local storage: app-private files plus local metadata on mobile; browser storage for web review, with browser quota/error handling. Persist linked task/completion metadata consistently with its attachments, so a restart cannot produce a finished-photo post alongside a reset unfinished task. Choose a compatible local storage adapter during implementation; this is an addition to the current in-memory foundation. Unrelated calendar/mood persistence is outside this photo slice unless required by the shared store.

Validate image bytes and dimensions, normalize orientation, generate a thumbnail, and strip embedded GPS from shared copies. Follow subscription v1's processed-image target near 500 KB and 2 MB maximum. Clean up abandoned drafts and unused files. No video, map integration or automatic location collection in this slice.

The [subscription plan v1](stewardie-subscription-plan.md) remains authoritative: Basic permits one photo per shared task/moment; Plus permits up to five subject to edit rights and account quotas. A linked task image and its Moments presentation are the same attachment, not two uploads or two storage charges. Existing photos remain viewable; a limit never blocks task completion. For this local build, exercise the Basic allowance and inject limits for tests; do not claim server-enforced quotas or introduce purchase controls. Older technical-plan wording that proposed one photo universally does not supersede v1.

Avoid using task completion-history visibility to accidentally delete or hide standalone Moments. For a task-linked Moment whose task detail falls outside Basic history, preserve authorized photo access and disable/restrict the task-history destination without exposing its full record. This retains v1's existing photo access and task-history boundaries.

## 7. Implementation order and checks

1. Fix the transparent shell, selector/Inbox shapes, chip checkmarks, equal-height row and count/dock gaps; review screenshots at 360/430px, landscape and 200% text.
2. Generate/review six mood assets and connect chooser, current mood, update/remove/expiry paths.
3. Add media models, local storage/processing adapters and shared photo preview. Validate cancellation, restart recovery, limits, orientation and failure cleanup.
4. Build native camera/gallery integration and export. Verify permission denial, lifecycle, physical-device capture, unavailable-camera fallback and save failures.
5. Connect task attachments and the optional completion-photo sheet to every Mark done entry point. Verify success, skip, cancel, duplicate taps, completion failure and photo retry independently.
6. Build the TV Moments viewer, standalone posting, filtering, expansion/save and author removal. Verify no cross-space leakage, no duplicate media and correct attribution.
7. Run analysis, relevant regression tests, builds, visual/accessibility review and actual camera checks on available platforms. Update governing UI/product docs only after approval, recording native checks that remain unavailable.

Likely code areas: `lib/app.dart`, `lib/core/people_filter.dart`, Today/calendar layout, mood presentation/assets, task detail/actions and repository interfaces, a new `lib/features/media/`, and a dedicated `lib/features/moments/`. Preserve existing user work and staged changes.

## Approved defaults

Proceed with a single blue companion in six moods; 10px count gaps and 8px dock gaps; one Basic attachment; optional photo prompt before final completion; automatic Moments entry only after confirmed task completion; one TV-style Moment per swipe; raw processed-photo export without the frame; and real local camera/media behavior without paid cloud services. The user approved implementation of these defaults.
