# Supabase shared-data migration

## Current deployment — October 1, 2026

The owner approved **new Supabase spaces now**, preserving the old Firebase data for later. The live Supabase project is `ulexhxfxatzlobabitpr`. Core migrations 001–012 and the coordinated `core-data`, `media`, `reconcile-subscription`, and `scheduled-work` functions are deployed. `STEW_CORE_ENABLED=true`; normal `flutter run` selects Supabase shared data by default. Firebase Authentication remains the identity provider. No billing activation or public publication was performed.

Firestore's read-only export returned `RESOURCE_EXHAUSTED`. No old Firebase records or stored photos were deleted or imported. Old spaces, task history, profile records and associated photos will not appear in the new space list until a later reviewed migration. Existing Firebase sign-in credentials still work.

## Implemented behavior

- Spaces, memberships, invitations, join approval, rename, departure/removal, ownership offers/acceptance and deletion use protected SQL workflows. Successful create/join returns the authoritative space ID to the existing selection flow. Pending approval is not membership.
- Tasks, assignment, acceptance, decline, help offers/handoff, completion, editing, subtasks and deletion use current membership, version checks and stable operation receipts. A retried successful operation cannot duplicate its task or event. Task IDs match durable local draft IDs.
- Basic supports three spaces, and completion history covers today plus the previous three space-local dates. Unfinished tasks remain accessible. Personal Plus grants retained authorized history and personal higher limits; it does not grant roles or upgrade other members. Space limits remain 20 members and 300 active tasks.
- The private schema holds ancillary profile, mood, calendar, routine, location, inbox/read-state and notification preference/device records. Client document writes cannot create tasks, memberships, activity history, or paid entitlements. Profiles can be written only by their owner and read by current co-members.
- Location sharing is explicitly started, scoped to one space and its recipient snapshot, and expired by server time. New members do not inherit an earlier sharing session. Stop remains possible after removal. Daily moods expire at local midnight.
- Photo upload, authenticated download, reactions, membership checks and task completion proofs use Supabase. Existing private storage objects remain intact. The media gateway rechecks current membership without its old membership cache in core mode.
- RevenueCat reconciliation writes trusted Supabase entitlement state. Sandbox/test-store eligibility retains the configured tester policy. This cutover does not claim a successful new purchase or enable commercial billing.
- Immutable operation events generate deterministic inbox IDs, suppress the actor, preserve read state, and revalidate membership/history visibility. Ordinary worker activity, routines, calendar reminders, social activity and FCM delivery run on the existing five-minute schedule. Notification permission is still an explicit OS choice; creating defaults cannot overwrite an existing preference.
- Deleted spaces disappear immediately. The scheduled worker subsequently cleans their new Supabase records and media; it never targets preserved Firebase spaces. Account deletion requests remain a manual pilot review workflow, not an automatic account-erasure claim.
- Existing typed Flutter screens use a temporary `CoreFirestore` compatibility view. Unsupported SDK operations fail instead of falling back to Firestore. Business transactions stay in SQL. Simultaneous screen reads are batched, active task reads exclude completed history, and subscriptions cancel their polling on disposal. Gateway access failures stop location polling. Transient network failures keep task edits queued for retry.
- Old Firebase edit/photo queues and photo records retain their original local namespaces. New Supabase queues use separate `core-` namespaces, so old pending work is preserved rather than uploaded into new spaces.

## Verification

Real deployed tests used three disposable Firebase-verified accounts: two members and one outsider. Verified token authentication, create/retry, invitation/join, space-selection data, outsider rejection, acceptance/completion, profile access, forged Plus rejection, batched reads, daily mood expiry, calendar save/remove, location start/read/stop, inbox events, actual JPEG upload/download, reactions, member removal and deletion hiding passed. Disposable authentication accounts were removed afterward. Test space deletion follows the normal scheduled cleanup path.

The existing scheduled worker returned HTTP 200 with zero errors after cutover. A manual production-worker trigger was rejected by automatic approval review because it could send notifications and purge deleted data; verification used read-only inspection of automatic runs instead. This does not establish delivery to a physical device or prove every populated worker/concurrency scenario.

The full Flutter suite passed 231 tests. The core/import/authorization/request-policy suite passed 36 tests. Final affected tests also cover default preferences, SDK/ISO location expiry, document batching, profile permissions, mood expiry and location scope. Flutter analysis of lib/ and test/, Deno checks for the four gateways, and the Android debug build passed. Full-repository analysis reports three unrelated diagnostics in the local video-capture tool. The build was installed on the owner's Samsung phone, opened successfully, without captured startup errors. The owner then signed in and confirmed that creating a new space succeeds and automatically selects it. Native GPS/background sharing, permission prompts, FCM delivery and RevenueCat purchasing still require signed-in device verification; iOS was not built on Windows.

```sh
flutter run
flutter test
flutter analyze
node --test tools/supabase-core/*.test.mjs supabase/functions/core-data/request_policy.test.mjs
```

The SQL tests use PGlite PostgreSQL after `npm ci --prefix tools/supabase-core`. They cover atomic rollback, authorization, version conflicts, quotas, receipts, invitation approval, ownership and import integrity. They are not a multi-session managed-PostgreSQL concurrency test.

## Preserved data and later import

`export_firestore.mjs` provides a bounded, paginated, read-only export with checksum and exclusive output creation. Default bound: 5,000 documents. Incomplete/quota-failed attempts produce no valid snapshot. Application Default Credentials are supported; `--firebase-cli` can use an existing authorized CLI login. Do not print or commit credentials.

```sh
node tools/supabase-core/export_firestore.mjs --project stewardie --live --firebase-cli --output .local/migration/export.json
node tools/supabase-core/prepare_import.mjs --input .local/migration/export.json
```

The current import preserves text UIDs/IDs, roles, dates, task versions/details, invite casing and validated entitlement expiry, rejects inconsistent rosters, and emits no historical notification events. Valid ownership nominees are retained. Pending joins are retained in the raw export but still need reviewed conversion.

**The current importer intentionally refuses an occupied destination.** Since new spaces are now enabled, later importing old data requires a reviewed merge/reconciliation path or an isolated import schema. Do not run the empty-destination importer over the active cloud. Never clear new data to make it fit. Freeze legacy writers before a final snapshot, compare counts/relationships, reconcile current RevenueCat state, and retain recovery copies. `--writes-frozen` records an operator assertion; it does not stop writes itself.

## Operational notes and remaining launch checks

The existing Supabase project did not contain a standard migration ledger. This deployment applied reviewed SQL files through the authenticated Management API. Do not blindly rerun CREATE statements or run `db push` over the existing schema; baseline it first or apply reviewed additive changes. `USE_SUPABASE_CORE=false` is a deliberate legacy diagnostic mode, not automatic failover. Emulator mode keeps its existing Firestore fixture backend. Never dual-write or switch an active account back and forth to hide an error.

Remaining checks: populated routine/reminder/FCM worker runs; real two-device and concurrent mutation behavior; disabled/revoked Firebase account handling beyond JWT expiry; provider usage and backup/restore; private operator-review/account-erasure workflow; later historical-data merge; iOS and real GPS/camera gestures; and a RevenueCat purchase/entitlement demonstration. Free Supabase limits still apply. These are documented verification/launch limits, not a reason to route new spaces through exhausted Firestore.

Security follows [Supabase database function guidance](https://supabase.com/docs/guides/database/functions): locked search paths, schema-qualified records, private RLS tables, and explicit service-role-only grants. The gateway performs its own Firebase JWT verification as described by [function configuration](https://supabase.com/docs/guides/functions/function-configuration); service credentials never enter Flutter.