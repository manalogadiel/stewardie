# Shared Moments, login mascot and Space header — September 24, 2026

## Delivered

- Compact Add Moment sheet sizes to content; camera/gallery actions are centered. Selected-photo preview/caption can scroll above the keyboard.
- Space hero title/art are fixed together on the yellow surface; account and other cards scroll in front with an initial overlap.
- Login uses one original procedural 3D blue bean model rather than a collage or separate head/belly. Five rendered actions (wave, look, bounce, peek, sleepy stretch) share the same neutral endpoints. Flutter adds a short blend, idle pauses, reduced-motion still, and pauses while the keyboard is open or app is backgrounded. The user's September 24 references guide the silhouette and features; these are new renders, not edits/crops of the references.
- New signed-in photos use CloudMediaLibrary and the live private Supabase gateway. Firebase accounts, tiers, spaces, tasks, Today, and TV Moments remain intact. No second login.
- Durable account-scoped upload queue, stable IDs and retry; thumbnails in the feed, protected full-photo viewing/export, uploader deletion. Existing device-only photos are not uploaded automatically: choose “Share this photo to space.”
- Task completion remains possible without photos. A protected completion proof lets the gateway publish already uploaded attachments later, including after Basic history expires.

## Live deployment

Supabase project `stewardie` / `ulexhxfxatzlobabitpr` under `manalogadiel`, Seoul region. Private `moments` bucket; `media_items` and `media_daily` with RLS and no anon/authenticated table access. Only the gateway's existing server-side service role can access them. Transactional reservation/finalization functions enforce per-uploader quotas and cross-uploader attachment caps. Pending reservations consume capacity until retried or removed; failed transfers remain tracked, not unaccounted objects.

Gateway: `https://ulexhxfxatzlobabitpr.supabase.co/functions/v1/media`. The Supabase legacy-secret JWT check is replaced by mandatory Firebase RS256 verification in the function (issuer, project audience, expiration, verified email and UID), then fresh Firestore membership checks under the caller's token. No service key, user token or database password is stored in Flutter/Git. Downloads are streamed through the gateway, not public or persistent signed URLs. Already saved/exported copies cannot be recalled after removal.

Migration source: `supabase/migrations/202609240001_private_moments.sql`. Function: `supabase/functions/media/index.ts`. Existing Firebase project received the tested `taskCompletions` rule addition; clients cannot fabricate, edit or list completion proofs. No paid service, Blaze upgrade, Firebase Function, purchase or store publication was enabled.

Media metadata lives in Supabase with its counters to avoid a cross-provider partial publication. Visible feeds refresh every 20 seconds, on entry or via Refresh moments (not instant Firestore realtime). A 900 MB aggregate safety cap leaves headroom within the current free storage allowance; it is not a change to the planned personal Basic/Plus tiers. Egress and function allowances still apply; this is a small pilot, not unlimited hosting. Daily limits count finalized uploads; retrying a stable ID does not increment them again. Removing a finalized photo does not refund its daily count.

## Verification and limits

- Eight Spark security emulator checks passed, including completion-proof forgery, mutation, outsider access and list denial. Rules deployed successfully.
- Initial focused Flutter run: nine UI tests passed; one export test needed a ProviderScope after PhotoViewer gained the shared-photo dependency. That fixture is corrected. Composer position, cancellation, keyboard/large-text layouts and reduced-motion login passed in that run.
- Final Flutter rerun and direct Dart analysis were blocked by Windows Application Control preventing `dartaotruntime.exe` from starting. Formatting succeeded. No security policy was weakened to bypass this block. The earlier analysis errors (missing theme import) were corrected. Do not describe the final revision as fully test-passing.
- Five GIFs generated from the same 3D model; browser visual review and asset frame checks are local verification only, not native animation performance testing.
- Live gateway anonymous/invalid-token smoke checks and transaction checks are recorded in the completion notes below. Real two-device authenticated upload/download, native camera/export and account switching still need owner-device verification. No real user photos were used for agent checks.

## Run and check on your devices

### Completion checks

- Deployed gateway returned HTTP 401 for a malformed bearer token.
- Live SQL assertion reserved and finalized a synthetic upload twice and confirmed the daily count stayed at one. The entire fixture transaction was rolled back; no test media or quota records were retained.
- Live database returned `false` for bucket public access, anonymous reservation permission, and authenticated-client reservation permission.
- Each mascot GIF contains 48 frames over 3,360 ms, with 47 distinct frames and identical first/last frames. Browser appearance was inspected; native playback/performance remains a device check.
- Formatting and `git diff --check` completed. The final Flutter test/analyzer attempts remain blocked as described above.

Fully stop and restart both Flutter runs after updating this same repository; `flutter pub get` registers the existing HTTP package. Run `flutter run` normally. Join the same space with verified accounts. Add a new Moment on device A; on B open Moments and tap Refresh moments (or wait up to 20 seconds). Try a task photo and mark its task done. Older local photos need the explicit Share this photo to space action. If disconnected, the draft is retained; use Retry sharing. No Vercel deployment is required.

Do not put a Supabase service key in dart-defines. The optional `MEDIA_GATEWAY_URL` is a public endpoint override only. Public purchases remain disabled and founder Plus remains personal. Broader launch gates in the product/subscription plans remain separate.
