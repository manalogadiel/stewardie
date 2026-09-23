# Spark cloud and UI completion record — September 24, 2026

## Implemented

- Normal Flutter entry point uses live verified Firebase identity, retaining original Today/Moments screens and assets. Explicit Spark transport replaces the callable-error fallback.
- Rule-enforced transactional task requests/actions, quotas, protected personal tiers, one-use seven-day invitations, revocation, member removal/leave, and consenting ownership transfer. Stable operation IDs make task retries idempotent. Former-member assignments are released; a concurrent orphan assignment is presented as claimable.
- Shared check-ins and plans use author-owned documents. Selected-person tasks carry the actual requested UID; people filters retain that selection.
- Space selector uses radio circles. Space background extends behind the top safe area; account and Plus panel refreshed. Owner/member actions and sign-out have confirmation.
- Remembered email/name with explicit opt-in, forget/use-another controls and secure password autofill. No password storage or silent reauthentication after sign-out.
- Add Moment is a centered rounded bottom sheet with keyboard-aware scrolling, draft-discard confirmation and preserved camera return. CameraPreview keeps its native orientation/aspect handling; centered shutter and pastel clay controls.
- Login has existing clay artwork, flat illustrated accents, a waving GIF, and reduced-motion still.
- RevenueCat binds Firebase UID at session entry, clears stale account state, uses the canonical entitlement, and fails closed on unavailable offerings. Firestore protected tier is authoritative. Public checkout is disabled; no client demo unlock.

## Live operations performed

Existing `stewardie` records migrated atomically: one space, two accounts, ten document updates, update-time preconditions, private backup in ignored `.local/`. No records deleted. Verified founder `gadielmanalo19@gmail.com` retains personal Plus; other accounts Basic. Restrictive Spark Firestore rules and indexes deployed successfully. Billing was not enabled and Functions were not deployed.

RevenueCat default offering now contains monthly/yearly only; lifetime removed from the offering, with its product/history preserved. Existing monthly Test Store price remains $9.99 (the inspected editor exposes title only); prior audited yearly price is $79.99. Replacement products at planned $3.99/$34.99 and sandbox allowlisting/restore policy are still launch configuration work. No real purchases were performed.

## Minimal verification performed

- Eight Spark emulator rule tests passed, covering authorization, protected tiers, atomic transitions, task creation/history queries, invitations, removal, and ownership consent.
- Ten focused media/polish widget tests passed after fixing sheet scrolling: cancellation, failed-completion retry, unavailable camera, export failure, TV paging/filtering, small-screen/large-text layouts, remembered identity, sheet positioning, and reduced-motion login.
- Paywall unavailable-offering check passed. Login asset renderer generated the GIF/still successfully.
- Final static analysis found no errors or warnings; eleven informational brace-style lints remain (the analyzer exits nonzero for these). `git diff --check` passed. These checks are not native hardware, real-store purchase, or two-device end-to-end verification.

## Explicit remaining release gates

The current no-billing trial does not include shared cloud photos: photos remain on the signed-in account's device. No Storage upload is claimed. Spark mood expiry and Basic completed-history access use UTC days, not the proposed per-space IANA time zone. RevenueCat trusted webhook/reconciliation, expiry/refund projection, paid subscriptions, app-store configuration/publication, shared media storage/retention, and native camera/export checks remain blocked by future infrastructure/product decisions or require real devices. `ENABLE_TEST_PURCHASES` is development-only and is not a substitute for trusted entitlement synchronization. The founder grant does not depend on a purchase.

Do not restore the permissive old rules. The migration backup is for reviewed data recovery, not blanket rollback. Historical docs retain earlier scope; this record and the current README supersede old claims about default fixtures or production-ready billing.
