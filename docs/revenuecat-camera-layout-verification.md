# RevenueCat Test Store, Camera Framing, and Space Header Polish Verification

Implemented and verified September 24, 2026 according to [revenuecat-camera-layout-plan.md](revenuecat-camera-layout-plan.md) and review remediation in [revenuecat-camera-layout-review.md](revenuecat-camera-layout-review.md).

---

## 1. What was Implemented & Review Remediation

### Finding 1: Renewable Server Authentication & Fail-Closed Persistence (P1)
- **Backend Function (`supabase/functions/reconcile-subscription/index.ts`):**
  - Replaced caller ID token fallback with renewable Google service account token generation using `jose` library (RS256 JWT assertion exchange with `https://oauth2.googleapis.com/token`) powered by `FIREBASE_CLIENT_EMAIL` and `FIREBASE_PRIVATE_KEY` environment secrets.
  - When Firestore PATCH write fails (e.g. 403 or non-200), the function immediately aborts with HTTP 502 Bad Gateway (`Failed to persist subscription update to account store`) and does not acknowledge success or return Plus.
  - Missing RevenueCat credentials or API errors throw a retryable failure (503/502) rather than downgrading valid accounts to Basic.

### Finding 2: Fail-Closed Webhook Authentication & Deduplication (P1)
- **Backend Webhook Security (`supabase/functions/reconcile-subscription/index.ts`):**
  - If `REVENUECAT_WEBHOOK_SECRET` is not configured, the function fails closed with HTTP 503 (`Webhook handling is not configured`).
  - Incoming webhook requests require an `Authorization: Bearer <secret>` header matching `REVENUECAT_WEBHOOK_SECRET`; mismatches return HTTP 401 Unauthorized.
  - Added webhook delivery deduplication using Firestore documents at `revenuecat_events/${eventId}` to prevent duplicate processing of replayed events.
  - Updated [supabase/config.toml](file:///c:/Users/Diel/Documents/GitHub/stewardie/supabase/config.toml) with `[functions.reconcile-subscription] verify_jwt = false` so edge functions can handle custom Firebase tokens and webhook authorization headers.

### Finding 3: Restriction of Test Subscriptions to Approved Accounts (P1)
- **Backend & Client Modeling:**
  - In `supabase/functions/reconcile-subscription/index.ts`, subscriptions from `test_store` are gated to the approved tester/founder UID (`APPROVED_TESTER_UID` or default founder). Unapproved accounts attempting test store subscriptions are rejected and remain Basic.
  - Separately modeled `isFounder`, `isSubscriptionActive`, `tier`, and `entitlementSource` in backend records and client state.

### Finding 4: Session Boundaries & Race Condition Elimination (P1)
- **Session Guards (`lib/features/subscription/revenuecat_service.dart`):**
  - Added session epoch and `_currentUserId` validation across all asynchronous boundaries in `reconcileWithBackend()`, `purchasePackage()`, and `restorePurchases()`.
  - Serialized `purchasePackage()` and `restorePurchases()` through the `_queue` so identity switches cannot interleave with in-flight purchase/restore operations.
  - Any callback or HTTP response arriving after a sign-out or account switch is safely ignored and discarded.

### Finding 5: Pixel-Accurate Square Framing & TV Cropping (P1)
- **Custom Painter Cropping (`lib/features/media/media_library.dart`):**
  - Replaced the `Align` size-factor approach in `FramedPhoto` with a dedicated `CustomPainter` (`_FramedImagePainter`) that executes `canvas.drawImageRect()` with source rectangle derived from decoded image dimensions and target fitted via `applyBoxFit(BoxFit.contain)`.
  - Tested with `build/review/review_validation_test.dart`: red edge pixels dropped from 22,500 to 0 on a 400×200 test image cropped to a square in a 300×200 container.

### Finding 6: Cloud Media Framing Persistence & Round-Trip (P1)
- **Database Schema Migration:** Added [supabase/migrations/202609240002_media_framing.sql](file:///c:/Users/Diel/Documents/GitHub/stewardie/supabase/migrations/202609240002_media_framing.sql) to add a `framing jsonb` column to `media_items` and update `reserve_media` and `list_media` RPCs.
- **Edge Function (`supabase/functions/media/index.ts`):** Parses multipart `framing` JSON field, validates bounds, and persists to the database.
- **Client Library (`lib/online/cloud_media_library.dart`):** Sends `framing` in multipart upload request, preserves framing across local outbox retries, and decodes `framing` from responses. Tested and verified in `test/cloud_media_framing_test.dart`.

### Finding 7: PlatformException Handling for Purchases (P2)
- **Error Decoding (`lib/features/subscription/revenuecat_service.dart`):**
  - Caught `PlatformException` in `purchasePackage()` and decoded it via `PurchasesErrorHelper.getErrorCode(e)`.
  - Accurately identifies `PurchasesErrorCode.paymentPendingError` and `PurchasesErrorCode.purchaseCancelledError`.

### Finding 8: Active Today Screen Height Reduction (P2)
- **Active Route Update (`lib/features/timeline/presentation/today_screen.dart`):**
  - Applied the ~28px height reduction directly to the active `TodayScreen` used by signed-in users:
    - Reduced greeting illustration height from 112px to 96px (width 132px).
    - Reduced bottom padding from 18px to 12px (saving 6px).
    - Reduced top clearance from 90px to 68px at standard text scales (saving 22px).
    - Preserved 140px clearance when text scale exceeds 22pt so floating controls do not overlap the Today title. Verified in `test/floating_header_mood_test.dart`.

### Finding 9: Orientation-Aware Camera Geometry (P2)
- **Camera Screen (`lib/features/media/camera_screen.dart`):**
  - Calculates preview aspect ratio based on camera sensor orientation and device orientation.
  - Locks capture orientation via `lockCaptureOrientation()` prior to shooting.
  - Decodes captured image bytes to determine true pixel dimensions for framing calculations.
  - Added `9:16` and `16:9` preset framing ratios in the ratio selector and guide overlay.

### Finding 10: Interactive Photo Composer Framing Editor (P2)
- **Photo Composer (`lib/features/media/photo_composer.dart`):**
  - Added `9:16` and `16:9` presets in addition to `Original`, `1:1`, `3:4`, `4:3`, and `Free`.
  - Added pan gesture drag controls on the preview image to reposition crop offsets.
  - Added interactive sliders in `Free` mode allowing custom width, height, and offset adjustment.

### Finding 11: Robust Framing Bounds & Deserialization (P2)
- **Model Deserialization (`lib/features/media/media_library.dart`):**
  - In `FramingRect.fromMap()`, clamped `x` and `y` to `[0.0, 0.99]`.
  - Clamped width and height upper bound to `(1.0 - valid).clamp(0.01, 1.0)`, preventing `ArgumentError` when coordinates are near 1.0.
  - Handled NaN and infinite values safely, falling back to full frame. Verified in `test/cloud_media_framing_test.dart` and `build/review/review_validation_test.dart`.

### Additional Deployment & Validation Fixes
- **Missing Expiry Handling (Fail-Closed):**
  - Updated [backend/firebase/firestore.rules](file:///c:/Users/Diel/Documents/GitHub/stewardie/backend/firebase/firestore.rules), [supabase/functions/media/index.ts](file:///c:/Users/Diel/Documents/GitHub/stewardie/supabase/functions/media/index.ts), [lib/online/firebase_repository.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/online/firebase_repository.dart), and [lib/online/online_home.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/online/online_home.dart). Non-founders with `tier == 'plus'` but null/missing `subscriptionExpiresAt` are treated as non-Plus.
- **Foreground Expiry Tracking:**
  - Added foreground periodic timer check in `FirebaseTimelineRepository` to re-evaluate active subscription expiry every minute while the app is running in the foreground.
- **Space Header & Plan Label:**
  - In `lib/online/online_home.dart` and `lib/features/spaces/space_screen.dart`, space name is displayed as the primary headline with "Space" as secondary label; account plan label evaluates founder and non-null future expiry.

---

## 2. Verification Checks Performed

| Check Suite | Description | Result |
|---|---|---|
| **Dart Static Analysis** | `dart analyze` across entire project | **Passed** (0 errors, 0 warnings) |
| **Full Flutter Test Suite** | `flutter test --no-pub` (all unit & widget tests) | **62 passed** (0 failures) |
| **Review Regression Test: Boundary Crop** | `build/review/review_validation_test.dart` | **Passed** (`{'x': 1.0, 'y': 0.0}` deserializes without error) |
| **Review Regression Test: Square Crop Pixels** | `build/review/review_validation_test.dart` | **Passed** (red edge pixels dropped from 22,500 to 0) |
| **Edge Function Review Harness** | `build/review/reconcile-review.cjs` | **Passed** (unsigned webhooks rejected 503; failed writes return 502/503; never unauthenticated 200) |
| **Cloud Media Framing Round-Trip** | `test/cloud_media_framing_test.dart` | **Passed** (4/4 tests: bounds, presets, local serialization, cloud upload/download) |
| **Large Text Today Clearance** | `test/floating_header_mood_test.dart` | **Passed** (Today title clears floating selector at 200% text scale) |

---

## 3. Explicit Boundaries & Limitations

- **No Live Paid Operations / Store Release:** All tests were conducted against simulated Test Store flows, mocked Deno edge harnesses, and local memory databases. No real credit cards or live production App Store / Google Play billing systems were charged.
- **Sensor Hardware:** Native camera sensor rotation and physical hardware orientation locking were verified via mocked camera and orientation logic; physical device runs remain subject to native device availability.
- **Secrets Deployment:** Live deployment of `reconcile-subscription` to Supabase requires configuring the production secrets (`REVENUECAT_SECRET_KEY`, `REVENUECAT_WEBHOOK_SECRET`, `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`) in the Supabase management console.
