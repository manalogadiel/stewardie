# Login, shared Moments, and pinned Space header

Status: implementation completed for the free cloud pilot, September 24, 2026; see [deployment and verification](shared-moments-verification.md) for verification limits. Supersedes the prior login collage and fixed-height composer proposals. Preserve approved Today, TV Moments presentation, mascots elsewhere, and Today / Moments / Space navigation.

## Confirmed causes

- LoginScene currently mixes multiple raster figures, flat figures, and a GIF made from a shaded 2D Flutter painter. It is not an actual 3D character animation.
- MediaLibrary writes image bytes and metadata to the device/account's Sembast database. It has no shared storage transport. Firestore task synchronization working on two devices does not imply photo synchronization. This is missing implementation, not a need to publish the Flutter client.
- PhotoComposer reserves 86% of screen height even before a photo is selected. The camera/gallery Wrap defaults to start alignment.
- OnlineHome Space paints a fixed yellow background but puts its hero inside the scrolling page. The title/art can scroll away from their background.

## 1. One real 3D login mascot, five actions

Use one sky-blue clay companion, centered above the form, with rounded volume, soft material, consistent studio lighting, contact shadow and cream backdrop. Remove the side characters and flat companions on login only. Keep form controls stable and unobstructed.

Create or obtain one reusable rigged 3D source model, then render five short coherent animations: welcome wave; look around/blink; small happy bounce; peek/lean curiously; sleepy stretch/yawn. One character appears at a time. Play welcome on entry, then spaced varied idle actions without immediate repetition; tapping can trigger the next action. Pause offscreen/backgrounded, use a still for reduced motion, and avoid continuously distracting movement while typing.

Approve a model/style still before rendering all five clips. Bundle optimized rendered animations for Flutter rather than requiring a live 3D engine on the login screen. Select final animation encoding after checking transparency, decoder memory and native playback. This provides real 3D-rendered movement without claiming that a painted 2D GIF is a 3D model. If a usable rig/model or rendering tool is unavailable, report that asset-production dependency rather than silently substitute another flat drawing. No asset generation in this planning pass.

## 2. Shared Moments: recommended no-billing pilot route

Keep Firebase Auth and Firestore for the existing accounts, tasks and spaces. Investigate and implement private Supabase Storage plus an Edge Function media gateway on the free plan, subject to a small authorization/limits validation first. No migration of working tasks, no second user login, no Vercel deployment required. Supabase supports Firebase third-party authentication, but that alone does not enforce Firestore space membership.

Firebase Cloud Storage currently requires Blaze. The all-Firebase route is simpler operationally, but conflicts with the present no-billing constraint. Do not enable it. Supabase's current Free allowance is 1 GB storage with bounded egress; this is a small pilot capacity, not sufficient to promise every Plus account 5 GB. Existing tier boundaries remain the product target; introduce a clearly documented temporary pilot capacity gate rather than silently redefining Plus. No paid upgrade or new account terms accepted automatically.

Security architecture:

- A private bucket; no public object URLs or broad authenticated-user access.
- Gateway verifies Firebase ID-token signature, issuer, audience, expiry, email verification and UID. It checks current space membership against authoritative Firestore on each upload/read/delete authorization. Do not trust client-supplied uploader, role, tier or a stale client membership mirror.
- Prefer Firestore reads under the caller's Firebase token so existing rules also enforce access. Validate this deployment path first; keep Supabase service credentials only in gateway secrets, never Flutter or Git. Native third-party JWT handling must be explicitly configured; no assumption that default Edge Function auth accepts Firebase tokens.
- Gateway issues tightly scoped short-lived upload/download permissions, or streams private downloads if immediate revocation is required. Document the short signed-URL revocation window and clear unauthorized local views. Already downloaded photos cannot be remotely recalled.
- Reserve daily/storage quota atomically per UID in trusted server-controlled storage; enforce actual file bytes, image type and dimensions, finalized size, ownership, and space/task validity. Compress originals and thumbnails before upload, strip location EXIF by default, and validate uploaded objects before publication. Release failed reservations and clean orphan uploads.
- Use stable moment/upload IDs for idempotent retry. Track local draft, uploading, failed, and published separately; publish shared metadata only after upload verification. Maintain a durable retry queue and explicit failure/retry UI.
- Implementation decision: keep media metadata and quota reservations together in private Supabase tables so publication and quota accounting are atomic. Firebase remains authoritative for accounts, spaces and tasks. The gateway checks current Firebase membership before serving metadata or bytes; Flutter refreshes visible Moments/task photos every 20 seconds and on entry/manual refresh. Minimal member-only Firestore task-completion proofs support delayed photo publication. No photos or base64 blobs are stored in Firestore.
- Task completion remains allowed without a photo. Attached task photos become Moments once the task is confirmed complete; retries cannot duplicate publication. Standalone Moments use the same pipeline. Preserve uploader-only deletion and member-only viewing.
- Existing device-only photos stay intact. Offer an explicit Share to space action for selected existing photos; do not bulk-upload private local history automatically.

Two-device acceptance: verified members in the same space see a newly published standalone photo and task-completion photo; thumbnails/fullscreen/export work; retries do not duplicate; offline draft survives restart; outsiders cannot fetch guessed keys; removed members lose fresh access; account switching does not leak cached photos. These checks require backend deployment, but no public app deployment or store release. A Supabase project/access will be needed at the cloud setup stage.

## 3. Compact centered Add Moment sheet

Replace fixed 86%-height sizing with content-driven layout and a maximum height based on available screen/keyboard space. Initial state shows title, compact art, centered Take photo / Choose photo controls and Cancel, without a large blank area. Use centered Wrap alignment and equal button sizing where space permits; stack centered buttons for large text/narrow widths. After choosing a photo, grow only enough for a bounded preview, caption and publish action; scroll when required. Preserve camera return, draft-discard confirmation, safe areas and keyboard visibility. Do not use a full-screen Scaffold that forces an otherwise short sheet to expand.

## 4. Pinned yellow Space hero with foreground cards

Place yellow surface, title, space name and artwork in a single fixed header layer extending behind the status bar. Put account/member/Plus cards in a separate foreground scroll layer, beginning with a small intentional overlap at the bottom of the yellow hero. As cards scroll up they cover the hero; its title/art remain anchored. Keep the floating selector/inbox above both layers and account for their safe-area clearance. Ensure covered hero elements cannot intercept touches or produce duplicate semantics. Responsive header sizing must accommodate long names and large text without clipping.

## Order and verification

1. Compact composer and pinned Space hero (small reversible UI edits).
2. Approve single-mascot 3D style/source and produce five animations.
3. Validate free private-media gateway authorization and quotas, then implement storage, metadata and retry flow.
4. Focused layout checks and a two-device sharing/access test. No repeated full builds; user runs native validation.

No billing changes, store publication, purchase activation or redesign of Today/TV Moments is included.

## Official references checked

- Firebase Storage billing requirement: https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024
- Supabase Firebase-compatible third-party auth: https://supabase.com/docs/guides/auth/third-party/overview
- Supabase Free storage allowance: https://supabase.com/docs/guides/platform/billing-on-supabase
- Egress limits: https://supabase.com/docs/guides/platform/manage-your-usage/egress
