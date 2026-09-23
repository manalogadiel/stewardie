# Firebase and RevenueCat setup review

Reviewed September 23, 2026, against commit `5ec6db3` and the connected service dashboards. This is a review, not a deployment or approval to accept payments. No application code, live rules, billing settings, purchases, or customer data were changed during this review.

## Result

Firebase app registration and RevenueCat Test Store configuration are present. The integration is **not ready for other people's private data or paid use**. The deployed Firestore rules lack membership and role isolation, and the app can announce a successful upgrade without a RevenueCat purchase.

## Confirmed setup

| Area | Observed result |
|---|---|
| Firebase project | `stewardie`, active; project number matches generated Flutter config |
| Registered apps | Android, iOS, web app IDs match `lib/firebase_options.dart`; Android/iOS identifiers match `dev.stewardie.demo.stewardie` |
| Authentication | Email/password enabled, password required |
| Auth domains | `localhost`, `stewardie.firebaseapp.com`, `stewardie.web.app` |
| Firestore | Default native database exists in `asia-east2`, free-tier eligible |
| Cloud billing | `billingEnabled: false` at review time |
| Cloud Functions | Listing returns 403: Cloud Functions API unused or disabled; server callables are unavailable through this setup |
| Entry point | `main.dart` uses the Firebase session and original `StewardieApp`; `main_online.dart` aliases it. Live Firebase is now the default; emulators require `USE_FIREBASE_EMULATOR=true` |
| RevenueCat | Stewardie project `16df0c31`; Test Store public key matches the Flutter service |
| Entitlement | `stewardie_plus`, matching the code |
| Offering | Current/default offering `default`; `$rc_monthly`, `$rc_annual`, `$rc_lifetime` map to Test Store products |
| Test prices | Monthly USD 9.99; yearly USD 79.99. These differ from the approved target USD 3.99/34.99 |
| Sandbox access | Anybody; not restricted to the founder |
| Restore policy | Transfer to new App User ID; needs an explicit account-ownership decision before release |
| Integrations | RevenueCat dashboard shows zero active integrations |
| Store readiness | Only Test Store configured; no App Store/Play Store configuration shown; no live transactions shown |

RevenueCat Test Store is appropriate for testing without developer store accounts, but its key is not a production store key. See [RevenueCat SDK configuration](https://www.revenuecat.com/docs/getting-started/configuring-sdk).

## Findings, in repair order

### 1. Critical: deployed rules expose private spaces to any signed-in account

`backend/firebase/firestore.rules:21` and its nested rules grant all signed-in users read/write access to every space, member, task, plan, mood, and moment. There is no membership, role, author, or verified-email check. Removed members and unrelated registered users retain API access even if the UI hides controls. Invitation records are also readable and writable by any signed-in user.

The same rules were retrieved from the live `projects/stewardie/releases/cloud.firestore` release, updated September 23 at 13:12:21 UTC. This is a deployed problem, not only a proposed rules file. No live data was used to demonstrate unauthorized access; reproduction used the local emulator.

`firestore.rules:13` also lets a user write their entire account document, including `tier`, quota counters, and their `spaceRefs`. That makes personal Plus and membership/cap enforcement forgeable. The existing four security-rule tests all fail because prohibited requests succeed.

Repair: implement and test member/author/role isolation and protected entitlement/counter fields before sharing real data. Firebase's [rules guidance](https://firebase.google.com/docs/firestore/security/rules-conditions) distinguishes authentication from authorization. If staying on Spark, design a rules-enforced direct-write model explicitly; simply restoring the old server-only rules will block current direct writes until a compatible backend exists. Deploying corrected live rules is a separate action from this review.

### 2. High: missing products are treated as a successful purchase

`lib/features/subscription/soft_pop_paywall.dart:274` calls `setPlusSimulated(true)` when the selected RevenueCat package is absent, then shows “Welcome to Stewardie Plus!”. This path is not restricted to debug builds. RevenueCat initialization failures and the deliberately skipped web SDK path both lead to missing offerings. Thus a configuration failure becomes a free local unlock, available to any account. The separate debug “Judge Demo Unlock” also conflicts with the earlier founder-only trial decision.

Repair: fail closed on missing offerings; do not announce purchase success without verified customer information. Keep simulations in a separate test harness. Preserve a controlled founder entitlement independently of public checkout.

### 3. High: direct task creation violates the repository response contract

`lib/online/online_backend.dart:231` returns only `{task: data}` after committing a task. `lib/online/firebase_repository.dart:324` expects `result['taskId'] as String` to fetch the new record. With Cloud Functions unavailable, creating a task writes it and then throws on the missing ID. Retrying can create duplicates.

Repair: unify callable/direct response contracts and add tests for the actual direct-write path, including retry behavior.

### 4. High: the fallback bypasses domain guarantees and can downgrade the founder

`online_backend.dart:131` falls back after **any** callable exception, including permission denials, quota failures, conflicts, and uncertain timeouts. The direct implementation lacks server transactions, operation-ID deduplication, ownership checks, and quota enforcement. Concurrent acceptance can overwrite ownership; a lost response can lead to another write.

Every fallback `createSpace` also merges `tier: basic`, `ownedSpaceCount: 1`, and `membershipCount: 1` into the account (`:194`). Creating a space can therefore erase a backend founder Plus grant and reset counters regardless of existing memberships. Completed-history fallback returns all completed records without the Basic date boundary. Invitation codes derive from the current timestamp, lack expiry/use limits, and the fallback has no `revokeInvite` handler.

Repair: choose one explicit execution mode, preserve errors, protect entitlements, and enforce transitions/counters/idempotency atomically. Do not use a broad catch as backend selection.

### 5. High: RevenueCat status is not synchronized to backend authorization

`FirebaseTimelineRepository.isPlus` and the Space badge combine Firestore tier with a singleton client flag. Backend Functions use only `accounts/{uid}.tier`. No purchase-verification/webhook handler exists in the repository; RevenueCat shows no active integration, and Firebase Functions are unavailable. A legitimate test entitlement does not establish a server-maintained personal Plus lifecycle. Conversely, a simulated client upgrade changes local capabilities without server authorization.

Repair: define a trusted UID-bound entitlement source and handle activation, expiry, refunds, restore, and account switching. Keep test entitlements separate from paid production access. RevenueCat documents [Firebase integration](https://www.revenuecat.com/docs/integrations/third-party-integrations/firebase-integration); installing an extension/backend is a separate cost and deployment decision. It is not automatically configured merely by adding the Flutter SDK.

### 6. Medium: RevenueCat initialization and account switching need lifecycle tests

`revenuecat_service.dart:37` configures Purchases again for a different UID, adds another customer-info listener, and marks initialization successful even after errors. Its `logIn` method is not called by application code. Initialization is owned by the Space/onboarding widget rather than the authenticated session, so a returning user can enter Today before purchase status has been loaded.

Repair: configure once, bind login/logout to the Firebase session, remove obsolete listeners, clear stale state, and retry initialization failures explicitly. Test A → sign out → B, restores, offline starts, and expired entitlements.

### 7. Medium: product settings and documentation disagree with the approved trial

The Test Store includes a lifetime product, while the subscription plan excludes lifetime offers. Prices differ from the planned targets. The paywall hardcodes “Save 27%” and “US$2.91 / month” even when the actual loaded annual product costs USD 79.99. Sandbox entitlement access is set to Anybody, conflicting with the founder-only trial. These are test products, not evidence of real charges.

README and the integration plan still describe an emulator-only/unimplemented setup. `docs/live-firebase-setup.md` describes the permissive rules as tested and secure; the executed security tests contradict that claim. Update the instructions only after the execution model and safeguards are settled. Cloud Functions deployment requires the Blaze plan; do not enable it as part of a no-paid-services trial. See [Firebase Functions setup](https://firebase.google.com/docs/functions/get-started).

## Checks performed

- Dart analysis of `lib` and `test`: no issues, successful exit on rerun with SDK cache access.
- `flutter test --no-pub`: 53 passed. The paywall tests exercise simulated unlocking; they do not prove a RevenueCat transaction or secure backend integration.
- Backend domain tests: 7 passed. These validate the server domain logic, which the direct fallback bypasses.
- Existing Firestore rules tests on isolated project `demo-stewardie-rules`: **0 passed, 4 failed**. Emulator shut down afterward. No production writes were performed.
- Read-only Firebase CLI/API checks: app registrations, Auth settings, Firestore database, billing flag, deployed rules, Functions API availability.
- RevenueCat dashboard inspection after user sign-in: entitlement, offering, package mapping, test prices, store configuration, public key match, sandbox policy, restore policy, integration count.

Not verified: real email delivery, native-device purchase/restore, cross-device entitlement renewal/refund, physical camera/export, production Storage, actual founder account entitlement, or deployed application UI. Existing device-local Moments photos remain distinct from cloud media. No paid services were enabled, purchase attempted, or live rules changed.

## Recommended next implementation

First secure database access and resolve the direct-write/backend architecture; then repair task contracts and account counters; remove fake purchase success; bind RevenueCat to the auth session and a trusted entitlement source; align test products and founder-only access; rerun rule, account-switch, two-member, and purchase-failure tests. Preserve the existing Today/Moments rendering and assets throughout.
