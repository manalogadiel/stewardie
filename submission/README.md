# Next Gen submission assets

- `stewardie-icon-face-v3.png`: revised submission icon with hands moved toward the outer edges, a large centered Butter mascot face and layered pastel clay waves, exactly 1024 × 1024 pixels, opaque background. Use this version for submission.
- `stewardie-icon-face-v2.png`: earlier face icon, retained as an alternative.
- `stewardie-icon-1024.png`: earlier full-body icon, retained as an alternative.
- `stewardie-today-1179x2556.png`: actual Flutter Today UI rendered at exactly 1179 × 2556 pixels without a device frame. Uses local sample data; this is not evidence of live synchronization or an iOS device capture.
- `stewardie-onboarding-plus-1179x2556.png`: actual optional onboarding Plus page, exported without a device frame. It uses the face-v3 logo now applied to Android/iOS launcher assets.

Screenshot reproduction:

```powershell
flutter test tools/capture_submission_test.dart
```

## RevenueCat purchase recording

The existing native integration uses `purchases_flutter` and a RevenueCat Test Store public key. Enable simulated purchasing explicitly:

```powershell
flutter run --dart-define=ENABLE_TEST_PURCHASES=true
```

On the signed-in authorized test/founder account, open Space → View Plus benefits, choose a displayed package, start the purchase, and select the successful Test Store outcome. These are simulated purchases without real charges. Public production purchases remain disabled; release builds reject the test key.

Record both the Test Store result and what the app reports afterward. Confirm `stewardie_plus` in RevenueCat's returned CustomerInfo/dashboard. A completed Test Store transaction and a server-confirmed Stewardie Plus upgrade are separate outcomes: Firestore quota exhaustion can prevent entitlement persistence and leave secure synchronization pending. Do not present pending synchronization as successful activation.

October 1 verification: screenshot export passed, both image dimensions were checked, and the screenshot and icon were visually inspected. The capture tool passed focused analysis. The Test Store Android debug build compiled, installed, and ran on the connected Samsung phone. Native SDK logs confirmed the monthly `stewardie_plus_monthly_499` product at US$4.99, a Test Store purchase, successful POST `/v1/receipts` HTTP 200, and a CustomerInfo update. This verifies a RevenueCat Test Store transaction; server-confirmed Plus persistence and feature unlocking have not been established while Firestore quota is exhausted. Test Store does not by itself establish that the competition accepts this purchase environment; disclose it in the video and description.

Official setup: https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store

The phone owner also confirmed that the purchase flow finished with a synchronization-pending message and did not grant Plus. Therefore, the end-to-end upgrade remains incomplete; do not describe the current demo as a successful Plus feature unlock.

No app-store publication, billing activation, private credential changes, or purchases with real charges were performed.
