# Firebase, RevenueCat, and Space polish implementation plan

Status: implemented for the no-billing Spark trial, September 24, 2026. See [implementation/verification and explicit release gates](spark-polish-verification.md). Original acceptance criteria below remain the production target; native purchases, shared media, and space-time-zone boundaries are not complete.

This follows the [setup review](firebase-revenuecat-setup-review.md), [subscription plan](stewardie-subscription-plan.md), and [UI plan](ui-plan.md). Preserve Flutter, the approved Today/Moments layouts and assets, and Today / Moments / Space navigation. Changes below apply to the normal `flutter run` app.

## 1. Repair data security and choose an explicit backend mode

First close the audited authorization gaps in local code and emulator tests. Every read/write must respect verified identity, active membership, role, and author ownership. Clients cannot change subscription tiers or protected counters. Removed members lose access to space content. Plus never grants membership or owner powers.

Remove the catch-all callable-to-Firestore fallback. Select the backend mode explicitly, keep response schemas identical, and surface actionable failures without repeating uncertain writes. Protect concurrent claims and quota counters with transactions and stable operation IDs.

No paid services are authorized. The recommended architecture retains the existing trusted callable backend for transitions, invitations, counters, and entitlement verification; complete and test it using emulators first. Before live rollout, choose between an approved hosted backend budget and a separately designed Spark-compatible direct-write model. A direct-write model needs its own rule-enforced invariants and threat review; it is not a free substitute obtained by loosening rules. A trusted RevenueCat synchronization component remains necessary for production entitlement enforcement.

Prepare a tested live-rule remediation and migration for existing records. Review missing expiry fields, counters, membership references, and existing entitlements before applying changes. Do not reset data or overwrite founder Plus. Record a deployment/rollback procedure; backing up old rules does not make restoring permissive rules a safe rollback. Live deployment must be explicitly included in implementation authorization; creating this plan does not deploy anything. Existing live exposure remains until corrected rules are deployed, so prioritize this before inviting real users.

Acceptance: outsider, removed-member, unverified-user, forged-tier, forged-role, concurrent-write, and Basic-history tests pass. Core authorized reads/writes still work.

## 2. Restore moods and task requests across people

### Moods

The current direct writer omits `expiresAt`; the repository defaults that field to the current instant. This explains check-ins disappearing immediately and must be covered by a regression test.

- Store a consistent mood/color/note/updatedAt/expiresAt record, using the space's defined daily boundary and time zone.
- Repair legacy missing-expiry records according to their actual timestamps; do not resurrect genuinely old moods as current.
- Everyone and Me show the signed-in person's mood. Another person's tab shows that person's shared mood read-only, with their selected clay pose and color.
- Keep live subscriptions scoped to the current space; distinguish loading, no check-in, expired, and access/network errors.
- Verify sharing, editing, clearing, and expiry between two real test identities on separate sessions.

### Task requests

The fallback currently returns `task` while the repository expects `taskId`. Repair that contract first. Then extend task creation beyond the existing Me/unclaimed boolean to accept an explicit requested member UID.

- When a person filter is selected, preselect that person in the task sheet and show the recipient clearly; allow changing it before saving.
- Everyone defaults to unclaimed; Me defaults to a request for the current account.
- A request stays Pending until the recipient accepts; it does not become Covered automatically.
- Validate active membership and prevent double saves. Keep entered text on failure and explain whether retry is appropriate.
- Verify requests to another member, acceptance/decline, handoffs, completion, removal during a draft, and retry after a lost response.

## 3. Finalize RevenueCat test integration before production billing

- Configure the SDK once at the authenticated-session boundary. Bind Firebase UID through the supported login/logout lifecycle; clear previous-account state and listener subscriptions.
- Use the confirmed `stewardie_plus` entitlement and monthly/annual packages. Retain Test Store for the current trial; no real checkout or store publication.
- Missing offerings, initialization errors, cancellations, and failed purchases must never unlock Plus or display purchase success. Remove the normal-product demo unlock.
- Establish a trusted backend entitlement projection with authenticated events, idempotency, reconciliation, expiry/refund/restore handling, and separation of test versus production status. Verify server-side quotas/history agree with the client.
- Keep the founder grant for the verified `gadielmanalo19@gmail.com` account separate from purchases. Creating/joining a space must not change it or upgrade other people.
- Propose restricting sandbox access to the founder's verified Firebase UID for the current trial; any additional test users are explicitly allowlisted. Do not use an email-only client check as an entitlement grant.
- Align test products to the planned USD 3.99/month and USD 34.99/year; remove the lifetime package from the offered catalog without deleting historical transaction records. Prices remain targets until launch approval.
- Derive price, currency, billing period, equivalent monthly amount, and savings from loaded products. Show the account being upgraded. Decide restore-transfer behavior explicitly to keep Plus personal.

Acceptance: native Test Store purchase, restore, expiry/revocation, app restart, and A → sign out → B tests pass; another account never inherits Plus. Backend verification and live store configuration remain release gates until deployed and tested, even if the local UI works.

## 4. Space selector and Space screen

- Replace the selected-space checkmark with a radio-style circle: empty ring for unselected, filled center for selected. Keep selected semantics, clear text, and large tap targets. Do not change the person-chip initials.
- Fix the cut-off Space header by painting its surface behind the status-bar area while keeping controls inside safe-area insets. Keep transparent floating top controls and avoid duplicate top padding or a rectangular AppBar strip.
- Redesign the account panel with avatar/initials, name, secondary email, and a restrained Basic/Plus badge. Give “View Plus benefits” one clear secondary button placement with room for long names.
- Add owner/member labels and owner-only “Remove from space” actions. Members get “Leave space.” Both use confirmation sheets naming the person and space and explaining loss of access.
- Proposed ownership rule: an owner must transfer ownership to an active consenting member before leaving. Block owner departure without a successor; a sole owner keeps the space until an explicit archive/delete flow is separately agreed. No accidental deletion through Leave.
- Removal/leave is atomic with membership references and counters. Preserve task history; release unfinished assignments to Pending/help-needed with an audit event, clear invalid help offers, and show a former-member label where historical attribution remains. Transfer/release operations require concurrency tests.
- Immediately dismiss inaccessible task/mood/plan views and switch to another authorized space or the create/join screen. Device-local photos retain uploader ownership but must not appear under another account or an unauthorized space. Shared-media retention/deletion policy remains a separate launch decision.

## 5. Moments sheet and camera

### Add moment

Replace the composer page push with a centered modal bottom sheet using the mood sheet's behavior: dimmed backdrop, rounded top corners, drag handle, safe-area and keyboard-aware padding, and a maximum width on larger screens. Keep Moments visible behind it. Camera/gallery, caption, space/audience, preview, and save stay in that flow. Opening the full camera returns the captured photo to the same sheet. Confirm before discarding an unsaved draft; cancellation creates no moment.

### Camera

The current outer preview uses the camera's raw aspect ratio and the controls use a wrapping row. Inspect native sensor/device orientation before selecting the correction; do not assume the camera itself is locked to landscape.

- Use the effective portrait/landscape aspect ratio and an explicitly fitted preview with no stretching. Any intentional crop must match the capture framing shown to the user.
- Center the shutter on the viewport, independently of side-control widths. Keep gallery and flip-camera in balanced side slots; handle absent front/rear cameras without moving the shutter.
- Use soft clay circular controls, pastel fills, subtle shadows, clear icons, disabled/busy states, and accessible contrast/touch targets.
- Verify front/rear orientation, rotation, captured-file orientation, permissions, interrupted lifecycle, and retake on physical Android hardware. iOS requires separate hardware validation; browser screenshots are not camera proof.

## 6. Sign-out, remembered accounts, and clay login artwork

Sign-out opens a clay confirmation sheet with Cancel and Sign out, naming the account. Confirming ends Firebase/RevenueCat sessions, clears account-scoped UI and subscriptions, and preserves local saved content without exposing it to a subsequent account.

Offer “Remember this account on this device” as an explicit choice. Store only the minimal display identity needed for a returning-account card; provide “Use another account” and “Forget account.” Do not store plaintext passwords or secretly retain a signed-out session.

Tapping “Continue as [name]” selects the remembered account and invokes supported platform credential autofill/authentication. A truly passwordless one-tap return after sign-out requires an approved passkey/provider or secure reauthentication flow and platform support; an email card alone cannot provide it. Ordinary session persistence applies when the user has not signed out. Explain any required authentication clearly rather than promise universal one-tap login.

Replace the login heart with a composed scene using the approved Sky/Butter/Rose characters: small 3D clay figures doing everyday activities, supported by restrained flat 2D clay/sticker figures around the background. Keep the form area uncluttered. Place a waving 3D mascot animation at the top center.

Asset deliverables: dedicated consistent poses plus a real short seamless waving GIF (or an equivalent animation format only if agreed), a static reduced-motion/first-frame fallback, asset provenance, and optimized file sizes. Existing assets contain static PNGs, not a waving animation. Generating an image alone does not satisfy the GIF requirement; verify animation production tooling and playback before claiming delivery. Respect reduced-motion settings and stop decorative playback when offscreen.

## Verification and handoff

Capture before/after small-phone and larger-phone images for Space, selector, login, composer, and camera controls. Test long names, keyboard, notches, large text, and reduced motion. Keep existing Today/Moments regression tests and assets intact.

Run Flutter analysis/tests, expanded rule tests, backend contract/integration tests, two-account shared-state tests, removal/leave and entitlement-isolation tests, and physical-device capture tests. Add failure tests for the exact regressions identified above. Clearly distinguish fixture/emulator checks from live cloud, Test Store, and hardware checks.

Update README, backend setup instructions, integration status, and verification records to match the chosen runtime and actual results. Final handoff supplies commands for the same Flutter repository in Antigravity and lists any unmet deployment, account, animation, or hardware gates.

## Decisions before dependent work

1. Live trusted-backend hosting/budget versus a separately scoped Spark direct-write architecture. Default remains no paid-service enablement; emulator implementation can proceed independently.
2. Confirm the proposed owner-transfer/unfinished-task behavior before implementing departure mutations.
3. Choose the supported reauthentication method if true passwordless one-tap return is required. Remembered identity plus credential autofill can proceed without storing passwords.
4. Production payments, cloud media, store publication, and any paid animation tooling remain outside this approval.
