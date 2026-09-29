# Stewardie: reliability, visual finish, and public testing

Status: implementation plan, September 30, 2026. Based on the current local Flutter code and the owner's latest requests. This document records planned work, not completed features or live dashboard verification. Existing uncommitted Today, Moments, map, and mood-asset changes must be preserved and reviewed before implementation.

## Confirmed decisions

- Keep Flutter, Today / Moments / Space, the existing Soft Pop palette, and approved clay character identity.
- Replace OneSignal with Firebase Cloud Messaging (FCM), retaining the existing account inbox, notification preferences, quiet hours, and Supabase scheduler.
- Personal Plus target: **US$4.99 monthly / US$39.99 annually**. Plus history has no age cutoff for retained records the viewer may access. Basic retains today plus the previous three calendar days. Deleted content and removed-space access are not restored by Plus. The [subscription plan](stewardie-subscription-plan.md) has been updated accordingly.
- New artwork will be generated in the implementation phase using existing illustrations as references. This planning task does not generate or replace production assets.
- Android is the first testing target. Preparing a testing build does not activate paid services, charge users, or publish publicly.

## What inspection established

| Area | Current evidence | Consequence |
|---|---|---|
| Space deletion | `SparkBackend.deleteSpace` removes membership refs and creates `spaceDeletionJobs`; `scheduled-work` leases/retries cleanup jobs. The selector explicitly lists every job whose status is not `done`. | A deleted space can still appear as a pending job. Check real job/worker failure before treating this as only a visual bug. |
| Invitations | `createInvite` writes an invite, then catches errors when updating `activeInviteToken`. Rules permit owners to create invites and require exact space metadata and bounded expiry. | Verify role, deployed rules, metadata, clock/expiry, and the precise denied operation. Do not weaken access rules to silence an error. |
| Map configuration | `stewardie_map.dart` reads `MAPTILER_KEY` without a default; the VS Code launch file supplies a local define file. | Plain terminal `flutter run` does not inherit that editor setting. |
| Tours | `TutorialExampleCard` still builds separate miniature controls. | Sharing colors alone does not make previews match real UI. |
| Identity | The onboarding name step has no photo input; account settings has no complete avatar upload flow; the Space card still includes an `Account settings` text action. | Implement photos end to end and use one settings entry. |
| Moods | `setCheckIn` calculates next UTC midnight. The local JPG placeholder was replaced by `mood-gray-question.png`. | Implement the intended local midnight and update asset references. |
| Notifications | Account activity, task events, reminders, preferences, and the worker exist; push transport currently calls OneSignal. | Extend the existing system and replace its transport. |
| RevenueCat | Public Test Store keys exist in code, purchases require an explicit test flag/environment, release builds disable test keys, and reconciliation checks tester eligibility. | This is not evidence that all users can purchase or that current dashboard offerings are correct. |

## Phase 1 — Deletion and invitation reliability

### Automatic space cleanup

Keep the confirmed delete transaction: revoke access, remove space references, stop sessions, and queue cleanup. Immediately remove the space from active selectors on every device after server confirmation. The selected tab must fall back to another authorized space or the real no-space screen.

Add an authenticated, owner-requested Edge invocation to start/drain the existing cleanup job promptly, with Cron as the durable fallback. Reuse one idempotent cleanup implementation. Do not make cleanup depend on the deleting phone remaining open. Paginate and checkpoint large jobs, retain leases and bounded retries, and avoid a full scan of every account on each ordinary worker run where targeted indexes/recipient records can be used.

Inspect pending/failed jobs, worker response bodies, credentials, Cron execution, storage errors, and lease expiry. An HTTP request queued successfully is not proof that cleanup succeeded. Finish only after space documents/subcollections, invites, media objects/metadata, notifications, routine/reminder work, and location sessions are cleaned according to retention policy. Never set `done` merely to hide a failure.

Remove deletion jobs from **My spaces**. If cleanup is still running, give the requester a discreet account-level status outside the active-space list; completion clears it automatically. Persistent failure has a retry/support path and operator visibility. Test interrupted cleanup and repeat deletion without deleting another space's data.

### Invitations without unexplained permission denial

Reproduce code generation/reuse, QR generation, revocation, code preview, redemption, and approval with an owner, member, and nonmember. Log the failing operation/error code for diagnostics without printing invite tokens or credentials. Check local versus deployed rules and indexes before editing permissions.

Retain owner-only invite management unless the product role policy is explicitly expanded. Show a useful explanation to members who cannot invite. Validate token format, verified identity, canonical space name/kind, approval policy, and expiry. Use trusted time or a safe server-validated expiry calculation rather than relying on an exact seven-day boundary from a potentially skewed device clock. Make replacement/revocation/cache updates consistent; do not swallow partial write failures and report an unusable invitation as successful. Test legacy valid codes, expired/revoked codes, approval mode, duplicate scans, and concurrent redemption.

## Phase 2 — Accurate tours and new artwork

### Tour previews use actual components

Capture the running no-space and member versions of Today, selector, mood/calendar, task controls, Moments TV, Space actions, map, and inbox. Create a visual reference matrix for each stop. Extract presentation-only variants of real components for tutorial samples, using local read-only data and actual labels, typography, spacing, and icons. Avoid miniature hand-drawn replicas that drift from the app.

For no-space accounts, teach the real selector and Create/Join actions; do not show a fabricated selected space. For members, spotlight rendered targets and wait for layout after tab changes. No task, photo, location, or membership mutation runs from a preview. Preserve UID-scoped first-use completion, manual replay, reduced motion, and the existing tour/Create-or-Join sequencing. Never trigger a tour simply by opening Space.

### Asset generation brief

Use the existing reference family and the supplied onboarding mascots: rounded 3D clay, soft grain, blue/butter/pink/mint palette, dark simple faces, consistent lighting, friendly proportions. Deliver true transparent PNGs, inspect edges over cream and pastel surfaces, then create optimized runtime derivatives. No baked text, rectangular image backgrounds, generic human substitutes, GIFs, or sparkling background decorations. Preserve approved source files and record provenance/mapping.

| Proposed asset | Composition and meaning |
|---|---|
| `onboarding-share-everyday.png` | Standing butter mascot stepping forward with a small clay task board; blue helper receives one task tile. Show cooperation with simple unchecked/checked shapes. |
| `onboarding-keep-moments.png` | Pink mascot standing with a camera at eye level; a friend leans into the frame. One small clay photo print supports the photo-sharing message. |
| `onboarding-stay-in-loop.png` | Mint mascot reaching toward a simple calendar board while a blue mascot holds a mood-face token. Clear plans-plus-mood meaning without a cluttered pile of props. |
| `mascot-couple.png` | Exactly two blue and pink mascots leaning together around one soft clay heart, balanced for a wide header. |
| `mascot-other.png` | A welcoming mixed group assembling rounded clay pieces together; flexible community identity without family/office-specific clothing. Use `mascot-all-groups.jpg` only as a style reference. |
| `empty-breathing-room.png` | A mascot reclining or stretching comfortably with relaxed expression and a small cushion/plant; visually expresses a break after tasks are clear. |
| `moments-selfie-group.png` | Three or four mascots leaning together for a selfie, one holding the camera/phone, with distinct restrained accessories such as cap, scarf, and glasses. |
| `background-clay-motifs.png` | Transparent, sparse clay loops, rounded pebbles, and soft leaf/cloud forms with ample empty space. |
| `background-soft-waves.png` | Transparent flowing rounded ribbons/wavy lines, using the same palette and quiet contrast. |

The three onboarding illustrations must have different silhouettes/actions and match the current card copy: **Share the everyday**, **Keep the little moments**, **Stay in the loop**. Generate and inspect each separately before integrating it; keep each composition readable at its actual phone size.

Reuse `mascot-family.jpg`, `mascot-friends.jpg`, and `mascot-organization.jpg` for their corresponding types. They are JPEGs: inspect whether their backgrounds need faithful transparent derivatives rather than assuming alpha exists. Add Couple and Other to the actual type selection, canonical model, persistence, validation, and reference mapping. Preserve legacy housemate/dorm/crew types with a deterministic fallback to Other.

Map the selected space type to the Today and Space header art through one shared resolver. Keep Moments' dedicated selfie art. Enlarge the Space hero illustration approximately 20–25% initially, within responsive bounds; inspect long space names, narrow phones, and enlarged text before settling dimensions.

### Shared backgrounds

Create one lightweight backdrop widget used by onboarding and all three tabs, including no-space states. Use the generated motifs at roughly 3–6% opacity in page margins and quiet open areas. Put waves behind content, never over labels, photos, maps, input fields, or hit targets. Preserve opaque reading surfaces and existing full-width yellow headers. Avoid multiple stacked opacity layers, background sparkles, and continuous animation; decorative layers ignore gestures and screen-reader semantics.

## Phase 3 — Profile, Space controls, and sheets

Add optional **Add photo** to the onboarding name step with camera, gallery, review/crop, and Skip. Keep the six-step progress model and verification-link authentication. Before verification, retain an account-flow-scoped local draft safely across restart; upload only after verified authentication. Cancel, denial, or upload failure never blocks signup.

Implement a private account avatar upload/read/delete path in Supabase, owner-only writes, and member-authorized reads. The existing media path is space-scoped and is not automatically suitable. Resize, remove EXIF, version/cache the avatar, and handle replacement, removal, account switching, and deletion cleanup. Use the same avatar component and centered initials everywhere, including notifications/map pins. Confirm cross-device visibility and unrelated-account denial.

In the Space identity card, replace the `Account settings` string with a rounded gear in a soft raised surface at the upper right, with a 48-pixel target and accessible label. Open profile management from that gear and optionally the avatar. Keep name/email readable and a simple Basic/Plus badge without a leading dot. Keep the display-name input compact but accessible.

Add an owner-only **Edit space name** action near the space title or its management menu. Update the canonical space record and denormalized member references/invite previews consistently so every device sees the new name. Validate trimmed length, preserve Unicode, show pending/error state, and handle concurrent rename or deletion.

Replace Invite members' generic human glyph with a code/vector Stewardie-shaped silhouette plus a clear plus sign. Use two curved arrows for Routines. Keep equal-width pastel action tiles, a 12-pixel gap, and enlarged-text stacking. Use vector/code artwork for these functional icons rather than image-generation output.

Audit every bottom sheet. The theme currently enables a drag handle, so remove extra manually painted black bars or disable the theme handle for a custom shared handle. Each sheet gets exactly one subtle handle. Root sheets cover the dock; scroll content clears system insets/keyboard; nested sheets do not leave two handles appearing as one modal.

## Phase 4 — Maps and daily moods

Give `MAPTILER_KEY` an approved public pilot-key fallback for debug `flutter run`, while keeping an explicit define override. Reuse the existing local key source during implementation and avoid duplicating it in documents. It is a public client key, not a server secret. Confirm plain terminal `flutter run` works independently of VS Code settings. Keep attribution, tile failures, Streets fallback, and private no-space mode. Before external release, verify provider usage terms, quotas, supported key restrictions, and release-key configuration; do not enable billing automatically.

Define daily mood expiry as the next **midnight in the space's configured IANA time zone**, not UTC midnight or 24 hours after check-in. Every viewer in that space sees the same boundary. Compute expiry in a trusted authenticated backend path, store timestamps, and keep backend access/validation consistent with the rule. Avoid a client-controlled expiry that can be extended arbitrarily.

At midnight, stop displaying the mood immediately using expiry-aware rendering; refresh on resume and account/space changes. The worker can delete expired records later, independently of display expiry. Handle offline stale data, DST, and time-zone changes; do not resurrect an expired check-in. Show `mood-gray-question.png` whenever no active mood exists and update all JPG/old-placeholder references. Other people's missing mood remains view-only.

## Phase 5 — Notifications with Firebase Cloud Messaging

FCM is listed as no-cost by Firebase. Send through the existing Supabase trusted server using FCM HTTP v1 and short-lived Google access tokens; no Firebase Functions/Blaze migration is required for this architecture. Hosting/database quotas still apply. Follow [Firebase pricing](https://firebase.google.com/pricing), [Flutter FCM setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), and [server sending](https://firebase.google.com/docs/cloud-messaging/send/v1-api).

Replace OneSignal SDK/init/login and worker delivery code with `firebase_messaging`, account-bound per-installation tokens, rotation, logout cleanup, denied-permission handling, foreground presentation, and deep links. Keep credentials server-side and prevent users from reading other devices' tokens or sending arbitrary notifications. iOS delivery needs the later APNs setup. Register permission only from an understandable reminder/notification action.

Keep the in-app inbox authoritative. Generate validated durable events atomically with the actual operation, or through its trusted server transaction. Reuse deterministic inbox IDs, task/plan revisions, memberships, actor suppression, read state, quiet hours, and per-space/category settings. Push failure must not undo a task or remove inbox activity. A best-effort authenticated dispatch call may send promptly after commit; the existing worker catches missed calls. With Cron fallback, acknowledge up to roughly five minutes of delay rather than promising instant delivery.

| Feature/event | Audience and treatment |
|---|---|
| Task assignment, help request, help offer, handoff, acceptance/decline | Direct recipient plus affected creator/participants as applicable; actionable inbox and push if enabled. |
| Task coverage/completion, material edit/cancellation | Affected participants/creator, suppress actor; cancel stale reminders and update actions. |
| Due tasks and plan reminders | Current authorized recipients at the configured time, quiet-hours deferral, current revision checks. |
| Plan invitation/addition, major time/place change, cancellation | Affected participants; avoid notifying everyone for a private/local preview or imported event not explicitly shared. |
| Task/plan arrival check-in | Relevant participants, clearly member-reported arrival. |
| Join request, approval/decline, joins/leaves/removals | Owner receives requests; requester receives decision; current members get appropriate membership activity. Removed users receive only a minimal access-ended account notice, not restricted space details. |
| Ownership offer/acceptance, space rename/deletion | Nominee/action participants or affected members. Deletion notification survives only as a minimal account notice without links to deleted content. |
| Routine generated task, paused/failed/cap-blocked routine | Use task assignment when applicable, avoiding a duplicate alert; notify routine manager of failures. |
| New Moments, reactions | Optional social category; authors receive grouped reactions, members can opt into new photos. No notification before upload/share succeeds. |
| Mood updates | Optional in-app activity only by default; no unsolicited push containing mood/note or alerts for failing to check in. |
| Live location start/stop/expiry | Sender gets the persistent active-session state; optional recipient activity uses only the consent snapshot. Never push coordinates or every GPS update. |
| Upload/outbox failures, cleanup failure, subscription change | Private account status when action is needed; no space-wide broadcast. Payment status derives from verified server events. |
| Reports/security/account deletion | Private acknowledgements/operator queue; never disclose a reporter to the reported member. |

Inventory all mutation entry points in both Flutter implementations, Spark backend, media Edge routes, and worker. For each, record whether an event already exists, is missing, or deliberately produces no notification. Camera previews, scrolling, profile-photo browsing, and routine GPS samples do not need social alerts.

Retry with backoff, prune invalid tokens, use generic lock-screen text, coalesce bursts, and revalidate membership before dispatch and on deep-link opening. FCM delivery is not exactly-once: use stable event IDs/collapse behavior to reduce duplicate display and idempotent inbox writes. A stale notification never grants access to old Basic history or a departed space.

## Phase 6 — RevenueCat and history

Verify the signed-in RevenueCat dashboard against the SDK: correct app, current offering, monthly/annual products, Plus entitlement, customer UID mapping, active webhook, and deployed reconciliation secrets. Perform one approved nonfounder tester purchase, restore, expiry, and account-switch test; founder status alone masks entitlement failures. Current code/config inspection is not proof that the live offering works.

Allow explicitly enrolled pilot testers to test via a protected tester eligibility record. Do not let a public client self-grant tester status or honor arbitrary sandbox purchases in production. Keep the founder grant independent. RevenueCat Test Store is a development tool; current documentation states its test key must not initialize in release builds, including Play testing tracks. Public release/testing builds therefore use Basic with checkout disabled until native store sandbox products and keys are ready. See [RevenueCat Test Store](https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store).

Update test products and all price/benefit copy to the approved US targets, but use store-provided localized prices in an enabled purchase UI. RevenueCat/dashboard product changes are separate from documentation/code edits. Label simulated purchases clearly. Verify no charge can occur in a development test flow.

Replace the benefit label with **Unlimited task history** with a concise retained/authorized-record qualification in details. Audit Flutter lists, backend queries/rules, paginated history, inbox links, exports/search if present, downgrade, and space time-zone boundaries. Plus should paginate all retained authorized history without eagerly downloading an unlimited list; Basic remains four days. Unfinished tasks stay accessible to everyone regardless of age.

## Phase 7 — Public-testing readiness

Build in this order: deletion/invites → shared identity/settings/sheets → art/tour/backgrounds → map defaults/mood expiry → FCM/event coverage → billing/history verification → release candidate. Each phase records completed code, deployed backend revisions, tests run, and open limits. Do not repeat already passing checks unless the change affects them.

Run focused checks for authorization and each changed UI, followed by a bounded Android test matrix using two members and one nonmember: create/join/rename/delete; photos/avatars; task/routine/calendar/inbox flows; midnight mood expiry; tab/tour first-use behavior; notification permission denied, foreground/background, sign-out/token reuse, quiet hours; GPS background/stop/expiry; offline replay. Review small/large phones and enlarged text. Record unsupported or untested cases honestly.

Before calling the build ready for external testers: settle package ID/signing, remove release debug/test-store affordances, verify deployed rules/indexes/Edge functions/Cron, protect abuse-prone endpoints and quotas, verify reporting/blocking and private operator access, recheck account deletion including avatars/tokens, provide working privacy/terms/deletion/support resources, and define tester distribution and incident support. Existing Android policy/release documents remain gates; verify current store requirements when choosing a track.

Start with an invited Android pilot and a signed release build with billing disabled. Play testing/public listing and iOS remain dependent on developer accounts and platform setup. Map/provider terms and quota/operating limits need review before opening enrollment widely. No public publication or billing activation follows automatically from this plan.

## Setup needed during implementation

- Existing Firebase access to enable/verify FCM HTTP v1 and server identity permissions; store private credentials only in backend secrets.
- RevenueCat dashboard access to verify offerings and test products, plus a nonfounder pilot tester account.
- Existing MapTiler dashboard access for usage/restriction review; the pilot key is already supplied.
- Later: final Android package/signing and distribution choice, Play account for Play tracks, publisher/support details, hosted policy pages; APNs/Apple developer access for iOS push.

Ask for missing access only when its step is blocked. Do not request secrets pasted into chat. No OneSignal account is needed.
