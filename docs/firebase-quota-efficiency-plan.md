# Firestore quota efficiency plan

## Confirmed diagnosis

The live media gateway returned Firestore `RESOURCE_EXHAUSTED` on October 1. Which exact quota is exhausted still requires the provider's quota details; the status alone does not prove which operation consumed it.

Stewardie already creates auto-ID documents inside one top-level `spaces` collection (`lib/online/spark_backend.dart`, `createSpace`). Subcollections hold space-scoped records. This is not a collection-per-space architecture defect. Moving records into a differently named collection or switching Flutter to the Firebase Web SDK will not restore exhausted quota.

## Keep the existing schema and runtime

- Keep Flutter and its Firebase plugins.
- Keep `spaces/{spaceId}` with current names, owner identity, `memberUids` array and role-bearing member data. Do not replace existing `members` role data with a UID array or rename owner fields without a migration.
- Keep tasks, plans, events and location sessions scoped to their space; subcollections remain useful and valid.
- Preserve account membership counters, Basic/Plus limits, invitation approval/revocation/expiry and operation receipts. Plus never grants private access or roles.

## Create, join and list contracts

1. **Create:** derive the UID from verified authentication, validate the name and quota, allocate `spaces.doc()` once per creation attempt, and atomically create the space plus account membership/counters and the required activity event. Return the acknowledged space ID and select it immediately. Keep the existing transaction and rules protections.
2. **Join:** call the existing Firebase-authenticated `space-actions` gateway. Resolve the invite on the trusted server, verify expiry, revocation, capacity and approval, then atomically update membership and account references. Repeat requests must not duplicate membership or consume another slot. Select the joined space after acknowledgement. A request awaiting approval must not grant access.
3. **List:** retain the account membership index or evaluate an authorized query on `memberUids array-contains auth.uid`. Choose based on measured reads and rules compatibility, not a blanket rewrite. Attach one account-level subscription and cache its results; dispose it on sign-out. Never query every space publicly to resolve an invite.
4. **Invite identity:** randomness reduces collisions but does not guarantee uniqueness. Preserve the existing trusted invite system and reserve each new invite code transactionally; retry collisions. Clients must not grant themselves membership through unrestricted `arrayUnion` writes.

## Measure and reduce reads first

1. Inventory all listeners, polling timers and gateway membership checks. Record aggregate request/document counts by action for a short repeatable session; exclude credentials, coordinates and personal content from diagnostics.
2. Check that only the active space's UI data is subscribed where appropriate, and that switching tabs/spaces, closing maps and signing out cancel obsolete work. Account-wide notifications can retain a bounded authorized subscription.
3. Reuse subscription results rather than issuing identical membership/document reads from rebuilds. Preserve membership revalidation at private media and location boundaries.
4. Review Moments polling and per-thumbnail authorization: measure a bounded, authenticated batched-thumbnail endpoint or pagination/cache improvements before implementing. Do not replace membership enforcement with permanent public URLs.
5. On quota rejection, stop tight retry loops and use bounded backoff rather than continuing frequent polling. Resume on explicit retry/foreground entry with a sensible cooldown. Keep server-side sharing expiry authoritative and pending Stop confirmation truthful.
6. Review the notification worker's query bounds, location polling and task-history pagination. Return only necessary authorized records; avoid repeatedly scanning unchanged historical data.

## Verification

- Before/after aggregate reads for the same account, tab changes, repeated map openings and photo-feed size.
- Two members and a nonmember: invitation, approval, removal and private-photo/location authorization remain intact.
- Creation/join retries preserve membership counters and immediately select the new space.
- Listener/timer cleanup and quota-backoff tests; focused Flutter analysis and affected rules/gateway tests.
- Live success must be checked after quota recovery. No local code change can manually reset the provider's daily quota. No billing activation or full backend migration is part of this plan.

## References

- Firebase usage limits: https://firebase.google.com/docs/firestore/quotas
- Firestore operation-based billing: https://firebase.google.com/docs/firestore/pricing
- Query authorization: https://firebase.google.com/docs/firestore/security/rules-query

Status: proposed efficiency work. Existing collection layout and the observed quota failure are confirmed; reductions and live recovery are not yet implemented or verified by this document.
