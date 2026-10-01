# Optional onboarding Plus and launcher logo

Implemented October 1, 2026.

New accounts see the full-page Personal Plus paywall after the three feature cards and before All set. The approved logo stays at the top, above “A little more together” and “Basic is free. Personal Plus is optional.” The former View Plus plans button and extra sheet are removed: store plans load immediately on entering the page. No purchase starts automatically. Skip for now stays pinned below the scrollable content, including while loading or after failure, and proceeds to All set. Completed accounts retain their completed state. The account's benefits/paywall sheet remains available outside onboarding.

Progress includes the new step. Draft schema version 3 stores stable step names; legacy version-2 numeric All set drafts continue to All set rather than being reinterpreted as Plus. The accessibility label derives its count from the flow.

The approved face-v3 icon is copied to `assets/branding/stewardie-icon.png`, displayed on the Plus page, and exported at all existing Android and iOS launcher sizes. The default Flutter icon is replaced. Existing welcome mascot art is preserved.

Latest verification: 21 focused onboarding and subscription tests passed; the screenshot export also passed after the compact layout refinement. Skip was checked while a plan request was pending and after failure; the page was tested at 320 × 640 with 200% text. Focused analysis reported no issues. The full-page layout was rendered and visually inspected. Native GPS/cloud quota changes are outside this change.

RevenueCat Test Store now defaults on in debug builds, so ordinary `flutter run` loads simulated purchases. It can be explicitly disabled with `--dart-define=ENABLE_TEST_PURCHASES=false` or `--dart-define=REVENUECAT_ENVIRONMENT=off`. Profile/release builds do not default to test purchasing, and release builds still reject test keys. Production billing still requires explicit production configuration; no paid cloud/store activation was enabled. Firestore exhaustion can still leave a verified test purchase pending secure backend activation.

The normal debug APK was installed and cold-launched on the Samsung phone. RevenueCat offerings and product requests returned HTTP 200 and built an offering with both `stewardie_plus_monthly_499` and `stewardie_plus_annual_3999`, without purchase flags. This verifies product availability, not a new completed transaction or backend Plus activation. Retry plans is available after a transient load failure, and initialization retries when no current offering was obtained.

The page was rendered and visually inspected at 1179 × 2556. Android debug build passed and was installed/launched on the connected Samsung phone. Existing completed onboarding was not reset for recording. iOS icon files were exported but iOS compilation was not available on Windows.
