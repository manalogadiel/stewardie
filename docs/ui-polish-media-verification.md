# UI polish and local photo slice

Implemented September 23, 2026 after the user's approval of [the plan](ui-polish-camera-moments-plan.md). This extends the [first redesign](ui-redesign-verification.md); it does not enable paid services, publish an app or connect a backend.

## Delivered

- Continuous off-white header backdrop with a centered capsule selector and circular Inbox; person initials stay visible without checkmarks. Mood/calendar cards share a measured height, with stacked cards for enlarged text. Count surfaces have 10px gaps and dock destinations have 8px gaps.
- Six blue clay mood poses in Today and the chooser. Existing mood update, removal and expiry behavior is preserved. [Asset manifest and prompt record](../assets/illustrations/README.md).
- A custom camera screen with a live-preview adapter, shutter, lens switch, gallery shortcut, flash handling, lifecycle disposal/resume, and unavailable/denied states. A shared photo composer previews the image, caption and destination audience before confirmation.
- Task details accept one Basic attachment. Completion without a photo offers Take photo, Choose photo, Mark done without photo, and Cancel. Both Today actions and details use the coordinator. A saved attachment is reused after a failed completion; cancelling cannot silently complete it. Completing with an attached photo publishes that same attachment to local Moments once.
- Standalone Moments, a cream clay TV frame, horizontal paging and Previous/Next buttons, person/space filtering, full-screen zoom, native export/browser download, and uploader-only removal. Removing a photo does not undo task completion. Old linked task details remain subject to Basic history visibility; standalone/photo access is preserved.

## Storage and processing decisions

Task writes and accepted processed photos persist in a Sembast app-private database on native targets and IndexedDB on web. This implementation stores encoded photo bytes with their metadata in the database, rather than separate image files. One attachment record serves both task and Moment; publishing updates it without copying its bytes or charging another upload. Task writes finish before completion becomes visible, and photo writes are serialized. A failed Moment publication leaves a Done task with a retained attachment and a retry action in task details.

Supported imports include JPEG, PNG and WebP. Images are checked before decoding (32 MB input and 40 megapixels), orientation-normalized, resized to a maximum 1600px edge, re-encoded without imported EXIF/GPS, and given a thumbnail. Compression targets approximately 500 KB with a 2 MB hard processed-image cap. Unsupported formats such as HEIC currently show a choose-another-photo error; native format coverage needs device review.

Local Basic limits are one attachment per task/moment, 10 accepted uploads per UTC day and 100 MB of processed photo/thumbnail bytes per uploader across spaces. Removal does not reset the daily counter; publishing an existing task attachment is not a new upload. Database overhead is additional to media-byte accounting. These are local guards, not server-enforced account quotas or multi-browser coordination. Plus purchasing and multi-photo allowances are not enabled.

On Android startup, interrupted picker results are retrieved where the plugin supports recovery. A prepared recovered copy is retained locally and offered for review in Moments; it is never silently assigned to a task or shared into a space. The preview requires an explicit destination confirmation. Recovery is best effort if the platform cannot return a result or decoding/storage fails. Unconfirmed normal previews stay in memory; accepted task photos survive a failed completion and restart. A database-open failure offers Retry without resetting saved data.

Jamie and the spaces/members are still fixtures. Task edits and photos are durable; moods and calendar plans still reset on restart. There is no real authentication, cloud upload, cross-device delivery, billing, media-location capture or online authorization. Clearing browser/app storage removes this local collection.

## Verification

Flutter 3.47.4 / Dart 3.13.3 on Windows:

| Check | Result |
|---|---|
| Dart analysis | No issues |
| Full Flutter suite with rendered captures | 41 tests passed |
| Web release build | Passed; `build/web` |
| Android debug APK build | Passed; `build/app/outputs/flutter-apk/app-debug.apk` |
| Task/photo model tests | Durable record reload, completion failure, idempotent publication, concurrent publication/removal, uploader/member restrictions, attachment/storage limits, UTC counter persistence and reset |
| Image processing tests | Orientation normalization, dimensions, thumbnail size, metadata removal, invalid-image rejection |
| Photo UI tests | Cancel/skip behavior, failure then cancel/retry, standalone posting, TV paging, scope filtering, expansion, mocked export failure/retry, mocked unavailable-camera fallback |
| Layout review | Today at 360/430px, landscape and 200% text; Moments and composer at 360/430px and 200%; simulated keyboard insets; camera fallback at 360px and 200% |

The web build retains the existing Cupertino font-family warning; application controls use Material icons. Test images below are rendered Flutter widgets using a simple synthetic photo fixture, not real captured photos. Insets simulate a keyboard and do not render an operating-system keyboard. Theme contrast and existing labeled-control/target tests pass. Native accessibility services, actual permission dialogs, lens/flash capabilities, capture orientation, background/resume, process-death recovery, gallery format coverage and native export remain hands-on checks. Browser camera permissions/download behavior also require a live-browser pass. Paging respects reduced-motion settings; playback was not separately recorded.

Device discovery found a Samsung SM A326B on Android 13, plus Windows/Chrome/Edge. The Android APK was built successfully; no claim is made here that physical capture, save, installation or runtime tests were performed. iOS compilation and device testing require a Mac/iOS environment.

The final visual pass corrected a selected “Moments” label wrapping at 200% text by allocating destination widths from all three bold labels. The three responsive Moments tests passed again after that adjustment. Camera controls measure 15.15:1 for white text on charcoal and 9.08:1 for the sky-blue retry action; blue on the cream surface measures 5.91:1.

## Reviewed renders

- [Today, small](polish-review/today-small.png) · [large](polish-review/today-large.png) · [200% text](polish-review/today-large-text.png)
- [Moments TV, small](polish-review/moments-small.png) · [large](polish-review/moments-large.png) · [200% text](polish-review/moments-large-text.png)
- [Photo composer with keyboard insets at 200%](polish-review/photo-keyboard.png)
- [Unavailable camera at 200%](polish-review/camera-unavailable.png)

Adapters follow the package documentation for [camera](https://pub.dev/packages/camera), [image_picker](https://pub.dev/packages/image_picker), [camera_web](https://pub.dev/packages/camera_web), [Gal](https://pub.dev/packages/gal), and [Sembast web](https://pub.dev/packages/sembast_web). Web camera access requires HTTPS or localhost. Platform adapters compile; mocked tests do not replace device checks.
