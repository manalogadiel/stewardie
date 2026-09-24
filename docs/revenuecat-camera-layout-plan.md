# RevenueCat testing, camera framing and header polish

Date: September 24, 2026. Status: proposed implementation plan; awaiting approval. This document does not enable purchases, change cloud settings or alter the app.

## Scope and evidence

Preserve Flutter, the existing clay artwork, Today / Moments / Space, private Supabase photos, and Firebase identity/membership. Follow subscription-plan v1. Keep public paid checkout disabled and the existing founder grant personal. Use the project Soft Pop UI skill and focused UI/UX guidance for responsive text, compact labels and safe-area clearance.

Code inspection found:

- `purchases_flutter: ^10.13.1`, a Test Store public key, Firebase UID binding, offering fetch, purchase and restore methods already exist. Checkout is disabled by `ENABLE_TEST_PURCHASES`; `stewardie_plus` is the canonical entitlement. The protected Firestore account tier is separate from SDK state. No deployed subscription reconciliation is established by this inspection.
- Purchase/restore currently collapse distinct outcomes into booleans. The paywall can report success while backend synchronization is still absent. Account changes during a purchase/restore need the same session guards as initialization.
- Camera uses the native preview without ratio controls. Photo processing already bakes orientation, compresses to the approved limits and retains aspect ratio. TV and expanded viewer already use contain fitting: preserve these working paths and correct measured layout issues only.
- Space currently renders “Space” as its headline and the space name as secondary text. The account plan is a separate Chip. Today has top-controls clearance plus a 112px illustration and bottom padding; tune this screen locally, rather than shortening every screen's safe area.

Dashboard catalog correctness and native camera behavior have not been verified in this planning pass.

## 1. RevenueCat: working Test Store integration

Use Test Store first. It supports simulated purchases without App Store/Play Store setup. The installed Flutter SDK meets the documented minimum. This validates RevenueCat integration, not real Apple/Google billing.

1. Inspect the existing project/catalog; reuse correct resources. Check monthly/yearly Test Store products, current offering/packages, `stewardie_plus`, and sandbox access. Align test prices with the approved $3.99/month and $34.99/year targets; display package-provided prices. If an existing Test Store product has the wrong price, replace its offering mapping with a new correct test product; preserve purchase history.
2. Introduce explicit off/test/production configuration. Test checkout works only in the intended development build and allowed account. Prevent a release from silently falling back to a `test_` key. Production checkout remains off. Preserve verified founder-only access unless separately authorized to add testers.
3. Keep Firebase UID as the RevenueCat identity. Serialize identity changes, ignore late callbacks from previous accounts, and handle loading, missing offerings, retry, cancellation, pending payment, restore, and confirmed entitlement separately. Do not display activation success until trusted synchronization succeeds.
4. Add a subscription reconciliation endpoint on the existing Supabase Functions platform. Verify the Firebase caller, obtain current subscription status from RevenueCat with a server-only secret, and write only protected subscription fields through a least-privilege Firebase server identity. Clients never submit their own tier or another UID to upgrade. Secrets stay in service settings, never Flutter or Git.
5. Track founder grants separately from subscription grants, including environment, entitlement, expiry and last verification. Preserve founder Plus when a test subscription expires. For this account, show the test subscription lifecycle separately so the founder grant does not hide test failures. General public access remains Basic.
6. Reconcile on purchase, restore, sign-in and foreground refresh. Add authenticated, idempotent webhook handling if included in the existing RevenueCat account without a paid upgrade; deduplicate deliveries and refetch current state so delayed events cannot reinstate an expired grant. If webhook access requires an upgrade, use authenticated refresh for the pilot and retain event synchronization as a public-launch gate.
7. Make protected feature checks expiry-aware in Firestore rules, backend checks and Supabase media quotas. This prevents a cached `tier=plus` value from granting indefinite access when a webhook or refresh is delayed. Cancellation retains valid remaining time; expiry/refund removes only the subscription grant. Never delete tasks/photos or alter memberships on downgrade.

Completion criteria: a local native build loads real Test Store packages, handles success/cancel/failure distinctly, restores the same Firebase account on another device, and agrees with protected backend state. Verify duplicate events, expiry/refund reconciliation and sign-out during an in-flight operation. Founder Plus survives all subscription tests. No real payment is taken.

Access likely needed during implementation: signed-in RevenueCat dashboard and securely configured RevenueCat/Firebase backend credentials. Reuse available configuration first; ask only if access is missing. Do not request secrets in chat or enable Blaze/paid plans.

## 2. Camera and TV photo presentation

- Add a compact clay ratio selector: Original, Square 1:1, Portrait 3:4 / 9:16, Landscape 4:3 / 16:9. A Free option in the framing editor allows other proportions without a crowded preset list.
- Keep the shutter geometrically centered with balanced side controls. Use responsive portrait/landscape layouts and orientation-correct preview geometry; never stretch the camera feed to match a box. Freeze the capture orientation at shutter time and normalize saved orientation.
- Ratio selection is non-destructive framing. Retain the full processed photo and save normalized framing coordinates/aspect metadata for presentation. Show the selected frame before sharing; gallery photos receive the same optional framing controls. Existing photos default to their full frame.
- Keep the TV's screen dimensions consistent. Fit the selected composition inside that screen with neutral inset space when ratios differ; do not distort faces or silently crop just to fill the TV. Swiping and next/previous controls remain.
- Tap opens the full processed photo at its original aspect ratio, with zoom and save. “Original” here means full composition, not the untouched camera file: existing compression, metadata stripping and upload limits remain. No extra original-resolution cloud copy is introduced.
- Carry framing metadata through local drafts, durable retry, gateway validation, metadata storage and cross-device reads. Validate crop coordinates against image bounds; thumbnails and full photos must agree.

Completion criteria: portrait, landscape and square capture/gallery images have correct orientation and proportions; rotation does not squeeze the preview; TV frames remain stable; opening/saving preserves the full photo. Check permission denial and camera resume once on native hardware.

## 3. Space account and heading hierarchy

- Replace the standalone bordered plan Chip with a compact borderless label beside the account name: `Gadiel  ·  Plus` (or Basic). Preserve accessible “Personal Plus” semantics. Keep the label whole; allow the name to flex/ellipsis, with full name available in account details. At large text sizes, wrap the label below the name rather than overlap it.
- Make “View Plus benefits” a quiet borderless text action, retaining a 48dp touch area and pressed feedback.
- Make the actual space name the large hero title; “Space” becomes the small supporting label. Allow up to two lines for long space names.
- Retain the fixed yellow hero and the white cards scrolling over it. Size for long names and enlarged text rather than a rigid title height.

## 4. Shorter Today yellow card

The supplied screenshot refers to the Today card. Keep its yellow palette, bottom rounded corners, centered space selector and circular inbox.

- Reduce the gap between the floating controls and the Today row; target approximately 24–32 logical pixels less total height at normal phone text size.
- Reduce the greeting artwork from 112px toward 96px, bottom padding toward 12px, and derive required top clearance from the actual controls plus a small gap. Do not remove status-bar/notch clearance or shrink hit targets.
- Keep Today/date/supporting text readable. Let height grow for accessibility; use constraints rather than one fixed height on all phones. Check the result against the supplied screenshot before finalizing values.

## Implementation order and minimal checks

1. Audit RevenueCat catalog/access and configuration while retaining completed work.
2. Implement backend reconciliation and test-only checkout/state handling.
3. Add non-destructive camera framing and persist it through the existing media path.
4. Apply account/title hierarchy and Today spacing changes together.
5. Run focused analysis and existing affected checks once if the Windows runner is available. Add only meaningful subscription/crop-state checks; no broad repeated builds. Verify one small/large-text layout and one portrait/landscape camera session when a device is available. Record unavailable checks honestly.

No app/store publishing, paid-service upgrade, new mascot generation, navigation redesign or public paid launch is included.

## Official references

- [RevenueCat Test Store](https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store): supported SDKs, test products, build keys, simulated purchase outcomes and accelerated lifecycle.
- [RevenueCat webhooks](https://www.revenuecat.com/docs/integrations/webhooks): account-plan availability, authentication, retries and current-state reconciliation.

Documentation consulted September 24, 2026. Recheck account-specific access during implementation.
