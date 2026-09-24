# RevenueCat Test Store, Camera Framing, and Space Header Polish Verification

Implemented September 24, 2026 according to [revenuecat-camera-layout-plan.md](revenuecat-camera-layout-plan.md).

## What changed

### 1. RevenueCat Test Store & Backend Reconciliation
- **Environment & Safety Isolation:**
  - Added `RevenueCatEnvironment` enum (`off`, `test`, `production`).
  - Added release guard in [lib/features/subscription/revenuecat_service.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/features/subscription/revenuecat_service.dart): in `kReleaseMode`, any API key starting with `test_` automatically forces `RevenueCatEnvironment.off` to ensure development test store keys never leak into production releases.
  - Added rich outcome types `PurchaseExecutionResult` and `RestoreExecutionResult` with `PurchaseStatus` and `RestoreStatus` preserving distinct states (`cancelled`, `pending`, `syncPending`, `syncFailed`, `notAllowed`, `error`).
- **Paywall Experience:**
  - In [lib/features/subscription/soft_pop_paywall.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/features/subscription/soft_pop_paywall.dart), purchase cancellation is cleanly handled without false error snacks; pending purchase informs the user; sync delays show accurate notification; restore provides discrete feedback.
- **Backend Edge Reconciliation:**
  - Created Supabase edge function [supabase/functions/reconcile-subscription/index.ts](file:///c:/Users/Diel/Documents/GitHub/stewardie/supabase/functions/reconcile-subscription/index.ts) that validates caller Google Firebase RS256 JWT tokens, queries RevenueCat subscriber entitlement status (`stewardie_plus`) via server secret, isolates founder grants from subscription expiration, and writes to Firestore `accounts/{uid}` (`tier`, `subscription`, `subscriptionExpiresAt`, `lastReconciledAt`).
  - Updated [supabase/functions/media/index.ts](file:///c:/Users/Diel/Documents/GitHub/stewardie/supabase/functions/media/index.ts) and [backend/firebase/firestore.rules](file:///c:/Users/Diel/Documents/GitHub/stewardie/backend/firebase/firestore.rules) to be expiry-aware: Plus checks require either `founderGrant == true` or a non-expired `subscriptionExpiresAt` timestamp.
  - Updated [lib/online/firebase_repository.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/online/firebase_repository.dart) account listener to verify expiration date locally.

### 2. Camera Framing & TV Presentation
- **Non-destructive Framing Model:**
  - Added `FramingRect` class in [lib/features/media/media_library.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/features/media/media_library.dart) supporting preset ratios (`Original`, `1:1`, `3:4`, `4:3`, `Free`) with normalized `[0..1]` coordinates and JSON serialization.
  - Added `FramedPhoto` widget utilizing `ClipRect` and `Align` with `widthFactor`, `heightFactor`, and alignment offset to render compositions without re-encoding, distortion, or stretching.
  - Carried `framing` through `PhotoDraft`, `processPhoto`, `MediaAttachment`, and `MediaLibrary.add()`.
- **Camera Screen:**
  - In [lib/features/media/camera_screen.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/features/media/camera_screen.dart), added a compact clay ratio selector bar (`Original`, `1:1`, `3:4`, `4:3`) wrapped in a horizontal scroll view for accessibility text scaling, framing guide overlay on the natural camera feed, and a centered 80×80 shutter with balanced 52×52 side controls.
  - Returns captured photo with normalized `FramingRect`.
- **Photo Composer:**
  - In [lib/features/media/photo_composer.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/features/media/photo_composer.dart), added ratio selector bar (`Original`, `1:1`, `3:4`, `4:3`, `Free`) and `FramedPhoto` preview, enabling non-destructive framing for both captured camera shots and gallery photos.
- **TV Presentation:**
  - In [lib/features/moments/moments_screen.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/features/moments/moments_screen.dart), updated `ClayTelevision` to render `FramedPhoto` with `BoxFit.contain` inside the TV screen container, ensuring consistent screen dimensions with neutral inset space without face distortion or stretching. Full photo viewer retains full composition with zoom and export.

### 3. Space Account & Heading Hierarchy
- **Space Header:**
  - In [lib/online/online_home.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/online/online_home.dart) and [lib/features/spaces/space_screen.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/features/spaces/space_screen.dart), the actual space name is now the large headline title (up to 2 lines, ellipsized), and "Space" is the supporting label.
  - The yellow hero background dynamically adapts to long names and enlarged text scaling (`heroContentHeight` derived from text scale and name length), and the white cards start cleanly below the hero with `topPadding: heroHeight + 12`, scrolling over the fixed hero as intended.
- **Account Panel Polish:**
  - Replaced the standalone bordered plan Chip with a compact borderless label beside the account name: `[Name] · Plus` (or Basic), preserving accessible "Personal Plus" semantics.
  - Using `LayoutBuilder`, the name flexes and ellipsizes while keeping the badge whole at standard text scales, and wraps cleanly below the name at large text scales (> 20pt).
  - Replaced `OutlinedButton.icon` with a quiet borderless text button `TextButton.icon` for "View Plus benefits", retaining a minimum 48dp touch target and ripple feedback.

### 4. Shorter Today Yellow Card
- In [lib/online/online_home.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/online/online_home.dart):
  - Reduced greeting illustration height from 112px to 96px (width 132px).
  - Reduced bottom padding from 18px to 12px (saving 6px).
  - Derived top clearance locally from floating controls plus gap: `MediaQuery.paddingOf(context).top + (scale > 22 ? 116.0 : 68.0)` (saving 22px at normal scale).
  - Total logical height reduction: ~28px (within the 24–32 logical px target).
  - Bottom rounded corners, centered space selector, and circular inbox are preserved; height grows gracefully with accessibility font size.

---

## Verification Results

| Check | Result |
|---|---|
| Dart static analysis (`dart analyze`) | Passed (0 errors, 0 warnings) |
| Dart test analysis (`dart analyze test/`) | Passed (0 errors, 0 warnings) |
| Full Flutter test suite (`flutter test`) | 58 tests passed (0 failures) |
| Task selection fixture fix (`demo_ui_test.dart`) | Passed (DropdownButtonFormField selection verified) |
| Framing calculation & serialization (`media_library_test.dart`) | Passed (`FramingRect.fromAspectRatio`, bounds clamping, `MediaAttachment` serialization) |
| RevenueCat result types & error handling (`subscription_paywall_test.dart`) | Passed (cancelled, pending, syncPending, restore outcomes) |
| Small phone (360 width) & 200% text scale layout (`media_ui_test.dart`) | Passed (Moments TV and photo composer render without RenderFlex overflow) |

---

## Limitations & Open Items

- Tests were run using Flutter unit/widget testing on the Windows runner. Real physical iOS/Android camera hardware, native sensor rotation freezing, and live App Store/Play Store sandboxes were not physically exercised.
- Public paid purchases remain disabled (`ENABLE_TEST_PURCHASES` controls test store initialization; `kReleaseMode` blocks test keys).
- Supabase edge functions require deployment with production environment secrets (`REVENUECAT_SECRET_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`) when published to remote infrastructure.
