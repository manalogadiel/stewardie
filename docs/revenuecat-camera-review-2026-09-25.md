# Independent implementation review — September 25, 2026

Reviewed current HEAD `b06f0c5`, the earlier implementation it builds on, and the existing uncommitted Space benefits-button change. Attribution is based on repository history, not an assumption about who authored each line. Application code and cloud configuration were left unchanged.

**Result: changes are not ready for integration sign-off.** Several earlier findings were fixed, and focused Flutter checks pass, but subscription authorization and delivery recovery still have reproducible defects.

## Findings, in priority order

### 1. P1 — Test Store purchases are misclassified as production and bypass the tester restriction

`supabase/functions/reconcile-subscription/index.ts:279–280` reads `store` and `is_sandbox` from the entitlement object. In the RevenueCat REST v1 response, those fields belong to `subscriber.subscriptions[product_identifier]` (or a corresponding non-subscription transaction), not the entitlement. Normal responses therefore produce `store=null` and `environment=production`. Both reconciliation paths then accept the purchase without the tester allowlist.

Reproduced by executing the actual handler with a documented-shape subscriber response: a Basic, unapproved UID with a `test_store`/`is_sandbox=true` subscription received HTTP 200, `active:true`, and a Firestore patch containing `tier=plus` and `environment=production`. No real account was modified.

Resolve the entitlement to its transaction record, validate the environment/store explicitly, and fail closed for unknown purchase metadata. Apply the same interpretation to direct reconciliation and webhooks. Add an actual handler test for an unapproved sandbox subscriber. [Official REST v1 model](https://www.revenuecat.com/docs/api-v1/customer-info-model).

### 2. P1 — A failed subscription update permanently consumes the webhook event

`supabase/functions/reconcile-subscription/index.ts:334–340` calls `recordWebhookEvent` before fetching RevenueCat state or writing the account. That helper stores `processedAt` immediately; it also ignores the create response and uses a non-atomic read-then-create pattern.

Reproduced: the first delivery recorded its ID and then a simulated Firestore PATCH failure produced HTTP 502. After database recovery, retry returned HTTP 200 with `duplicate:true`, without attempting the account update again (one total PATCH). This can lose activation, renewal or refund updates.

Use durable pending/completed states with an atomic claim and retryable failures. Mark completion only after successful persistence, and check every database response. Coordinate concurrent reconciliation so older state cannot overwrite a newer result. The existing harness in `build/review/reconcile-review.cjs` omits the webhook secret in both scenarios, so it now exercises the early 503 guard and does not establish persistence recovery.

### 3. P1 — Expired Plus accounts over Basic limits cannot leave or be removed from spaces

`backend/firebase/firestore.rules:20–21` applies the current plan's absolute membership and ownership caps to every account update, including removals. With the new expiry-aware tier check, a subscriber with 22 memberships becomes Basic at expiry. Leaving one would leave 21 memberships, causing `accountShape` to reject the entire leave transaction. An owner removing that user encounters the same rejection. An account still owning more than three spaces has a similar problem even when reducing memberships.

This contradicts the plan's requirement that downgrade preserve existing spaces and that leaving/removal never require Plus. Enforce capacity when a count increases; allow reductions and unchanged over-limit counts while keeping membership/ownership consistency checks. This is a rule-logic finding; no new emulator claim is made.

### 4. P2 — Camera capture forces one landscape direction regardless of device orientation

`lib/features/media/camera_screen.dart:114–119` maps any landscape viewport to `DeviceOrientation.landscapeLeft` and any portrait viewport to `portraitUp`. Viewport orientation has only two states; it cannot distinguish landscapeRight or portraitDown. A user rotating the phone the other way can get a saved photo rotated relative to the preview. On capture failure the lock also remains until the controller is recreated.

Use the camera controller's actual device orientation at shutter time, preserve preview/capture agreement, and unlock in a guarded finally block when remaining on the camera screen. Physical-device validation is still required. A separate suspected JPEG EXIF crop issue was tested and did not reproduce with the installed image library; it is not a finding.

### 5. P2 — The approved founder account cannot reach the Test Store flow in the signed-in UI

`lib/online/online_home.dart:1104` hides the only signed-in paywall entry when `plus` is true. The plan label beside the name is noninteractive. `SpaceScreen` delegates the authenticated route to this screen, so its fixture-only member tap does not provide an alternative. The founder is the account explicitly intended to test purchases, but has no visible test/restore entry or subscription-lifecycle display.

Provide an account/subscription-details action available to Plus members, with a development-only Test Store entry for an approved tester. Keep normal product copy clear and keep public checkout disabled.

### 6. P2 — Founder Plus can be reported as successful subscription synchronization

`lib/features/subscription/revenuecat_service.dart:311` and `:433` use `reconciled && _isPlus` for purchase/restore success. `_isPlus` comes from the effective account grant and is always true for the founder, even if the backend response has `isSubscriptionActive:false`. That separate field is never retained or checked, and the subscription getters have no UI consumers. Consequently founder access masks a missing or failed subscription activation—the exact distinction the plan required for testing.

Track confirmed subscription activity independently from effective personal Plus, and confirm test checkout against that subscription state/product. Keep founder access intact while showing inactive/pending/expired test status honestly.

### 7. P2 — Off/release environment guard does not prevent Test Store SDK initialization

`lib/features/subscription/revenuecat_service.dart:146–153` calls `Purchases.configure(apiKey)` regardless of `environment`. A release build without explicit production keys selects `environment=off`, but `apiKey` still returns the default Test Store key and initialization still fetches offerings and customer info. The purchase button is disabled, yet the release build still configures Test Store, contrary to the planned release guard.

Honor the environment before configuring the purchase SDK, require explicit valid platform keys for production, and keep any founder/account refresh separate from disabled store initialization. Add configuration-path tests, not only result-object tests.

## What passed / improved

- Framing now round-trips through the cloud adapter and local serialization; the migration/gateway source includes framing support.
- FramedPhoto draws a source rectangle without stretching; the expanded photo viewer retains the full processed photo.
- Previously reported unsafe boundary crop input is handled by the current model.
- Typed purchase cancellation/pending handling and account epoch guards are present.
- Active Today layout was shortened; its existing 200% text clearance test passes.
- Space name hierarchy and inline plan label changes are present. The uncommitted removal of the benefits icon introduces no identified functional defect.

## Checks independently run

- `flutter test --no-pub test/cloud_media_framing_test.dart test/subscription_paywall_test.dart test/floating_header_mood_test.dart`: **12 passed**. Initial sandbox cache access failed; rerun with authorized SDK cache access succeeded. Windows Application Control did not block this run.
- One additional JPEG EXIF/framing regression check: **passed**; no EXIF-framing defect reported.
- Mocked Node execution of the actual reconciliation handler: reproduced findings 1 and 2. Source: ignored `build/review/september25-subscription-check.cjs`. No real secrets, network requests, database writes or payments.
- `git diff --check`: passed for the existing working-tree edit.
- Reviewed the REST response against official RevenueCat documentation.

The two subscription unit tests mainly cover missing offerings and construction of result objects; they do not verify successful purchase, backend activation, webhook retry, expiry, or account switching. Passing them does not establish the billing lifecycle. The report saying all findings are addressed should not be treated as end-to-end validation.

No full-suite rerun, live Supabase deployment/secret audit, RevenueCat dashboard purchase, Firebase rules emulator run, or physical-camera/Space screenshot review was performed in this pass. Native sensor handling, authenticated cross-device subscription behavior, migration deployment, and long-name Space rendering remain unverified.

Fix order: environment interpretation and webhook persistence; downgrade-safe rules; founder testing/status; camera orientation and SDK initialization guard. Then run focused regressions and verify the authenticated Test Store flow before enabling it for the pilot.
