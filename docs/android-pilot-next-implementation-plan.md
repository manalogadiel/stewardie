# Stewardie Android pilot: next implementation plan

Status: Phase 1 completed September 28, 2026. Phase 2 has a private cleanup tool, operator procedure, and tighter safety rules; the disposable live-account test, external page, and public retention policy remain open. Real account/device behavior is still to verify. This plan does not authorize a paid service or public release. Use [pilot completion status](pilot-completion-verification.md) for the exact implementation and checks; older planning documents describe earlier states of the app.

## Goal and boundaries

Reach a dependable invitation-only Android pilot using the existing Today / Moments / Space Flutter app, Firebase Spark, and the existing Supabase project. Basic members retain unfinished tasks and shared completion; the founder's Plus grant remains personal. OneSignal, Google Calendar OAuth, public paid Plus, iOS, and Play production are outside this pilot.

The locally staged QR invitations, calendar reminders, offline outbox, reporting, blocking, and deletion-request intake are starting points, not tasks to rebuild. The current checkout has uncommitted work. Preserve and review it before changing or deploying anything.

## Phase 1 — Stabilize and deploy the pilot backend

1. Review the current diff against `docs/pilot-completion-verification.md`, including Firestore rules, the `scheduled-work` function, and the Flutter callers. Fix only issues found in that review and record the resulting revision. Keep secrets out of Git and Flutter.
2. Run focused static checks on changed Dart, Firestore rules, and worker code. Keep the existing emulator rules suite as the authorization check; add a targeted case only when a rule changes or a defect exposes a missing case.
3. Deploy the reviewed Firestore rules to `stewardie` and the reviewed `scheduled-work` function to Supabase project `ulexhxfxatzlobabitpr`. Confirm that the existing five-minute Cron job still targets this function and that the worker secret is present in Edge Function secrets and Vault. Do not create a second schedule.
4. Verify one unauthorized worker request is rejected, one authorized run returns success with zero errors, and Cron history plus function logs show a successful scheduled invocation. Record deployment revision and time in the verification document. Investigate errors before proceeding; do not infer deployment success from the Flutter app compiling.

**Gate:** deployed rules and worker match the reviewed checkout, scheduled runs succeed, and no secret appears in client code or source control.

## Phase 2 — Close deletion and moderation operations

1. Define the account-deletion procedure before automating it: identify Firebase Auth identity, account and space references, private data, authored shared records, Supabase `media_items`, private Storage objects, and any retained audit records. Shared tasks must remain understandable to other members after an author leaves; personal data and media removal must follow a documented ownership and retention rule. Decide those rules explicitly rather than deleting a whole space by accident.
2. Implement an operator-only processor or documented manual runbook that takes a tracked deletion request through **received → processing → verified complete / needs attention**. Make each cleanup step idempotent so a retry can resume safely. Record completion evidence without storing unnecessary personal content. The current operator queue is intake only and must not label a request complete before both Firebase and Supabase cleanup are checked.
3. Test with a disposable account that belongs to two spaces and has tasks, calendar plans, moments, and photos. Verify the account can no longer authenticate, private data and Storage objects are gone, other members retain permitted shared history, and repeated processing does not corrupt records. Test a partial failure and retry.
4. Define a named report reviewer, response target, and evidence-retention approach. Exercise report submission, reporter-only hiding, blocked direct requests, and owner/operator access using authorized and unauthorized accounts.
5. Only after the deletion path works, review and publish `hosting/deletion-request.html`; verify it from another device and ensure its request reaches the same operator queue. Keep the in-app request path available. Google Play requires both an in-app deletion path and an external web resource for apps with account creation: [account-deletion policy](https://support.google.com/googleplay/android-developer/answer/13327111).

**Gate:** a real deletion request can be completed and verified across Firebase and Supabase; reports have an assigned review process; the external request path works without requiring the app.

## Phase 3 — Real-device pilot matrix

Use two authorized Android accounts/devices and one account outside the space. Keep the first pilot invitation-only. Record device model, Android version, app revision, account role, observed result, and any defect. Test the existing Today / Moments / Space presentation as a regression, not as a redesign.

| Area | Pass conditions |
| --- | --- |
| Invitations | Stewardie QR scan and manual code entry reach the same preview; expired/revoked codes fail; approval and duplicate scans do not grant extra access; denied camera permission leaves code entry usable. |
| Calendar/reminders | Author and current participants receive one in-app reminder at the chosen local time; Off and imported Google plans do not alert; edit, delete, membership removal, quiet hours, worker retry, and a daylight-saving boundary do not leave stale or duplicate alerts. |
| Offline edits | Task creation and own plan edits show Pending, then Synced after reconnection; conflicts show Needs retry without overwriting newer server work; sign-out/account switch and removed membership do not expose or replay another account's drafts. |
| Media and location | Shared Moments and photo pins appear on the second device; camera orientation and gallery labels are correct; unauthorized media access fails; live location stops on Stop/expiry and behaves honestly under lock, backgrounding, permission change, and network loss. |
| Core coordination | Two-account task assignment, completion, routines, moods, inbox, and Basic access to unfinished tasks work with the deployed backend. |
| Safety | A nonmember cannot read space records; reports and deletion requests are private; blocking prevents new direct requests without hiding coordination history. |

Fix reproducible defects, then rerun only the affected cases and a short core regression. Do not claim background location reliability from an emulator or one foreground run.

**Gate:** no unresolved access-control or data-loss defect; pilot-critical flows pass on physical devices; known OS limitations and nonblocking issues are recorded.

## Phase 4 — Android release preparation, after the pilot

1. Decide the final Android application ID and publisher identity before creating store records or signing artifacts. Keep the private upload keystore out of Git; verify the release Gradle configuration and build a signed AAB using the [Flutter Android release guide](https://docs.flutter.dev/deployment/android).
2. Create the Play developer account when ready, set an operating budget and monitoring thresholds, and prepare English listing, support contact, privacy/terms, data-retention and deletion wording, Data safety answers, and content rating. Review the adult-only positioning and legacy dependent-profile data before a public audience.
3. Distribute internally, then complete the required closed test for the account type before applying for production access. As of this plan, Google's rule for new **personal** developer accounts is at least 12 continuously opted-in testers for 14 days; verify it again at release time: [Play testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465).
4. Treat worldwide Play availability as a later distribution choice. Confirm support coverage, privacy wording, costs, and store policy for selected countries before enabling it. Public release requires a separate decision; passing the private pilot does not publish the app.

**Gate:** signed release build, store and policy materials, tested deletion/moderation operations, required Play testing, and an explicit publication decision. No paid tier or OneSignal Growth is activated by this plan.

## Ownership and next action

Codex can review and fix the code, prepare the backend deployment, implement the deletion processor/runbook, and document focused verification. The owner must provide physical-device results, choose the final publisher identity/application ID, create a Play account if pursuing distribution, and approve any paid-service or public-release decision. The immediate implementation slice is **Phase 1**, followed by deletion operations in **Phase 2**; the device pilot can run as soon as the deployed backend is verified.
