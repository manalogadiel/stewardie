# Optional onboarding Plus and launcher logo

Implemented October 1, 2026.

New accounts see an optional Personal Plus introduction after the three feature cards and before All set. View Plus plans initializes the existing RevenueCat service for the authenticated account and opens the existing paywall. No purchase starts automatically. Skip for now stays available while loading or after failure and proceeds to All set. Completed accounts retain their completed state.

Progress includes the new step. Draft schema version 3 stores stable step names; legacy version-2 numeric All set drafts continue to All set rather than being reinterpreted as Plus. The accessibility label derives its count from the flow.

The approved face-v3 icon is copied to `assets/branding/stewardie-icon.png`, displayed on the Plus page, and exported at all existing Android and iOS launcher sizes. The default Flutter icon is replaced. Existing welcome mascot art is preserved.

Verification: 23 focused onboarding, tour, migration and subscription-page tests passed. Skip was checked while a plan request was pending and after failure; the page was tested at 320 × 640 with 200% text. Focused analysis reported no issues. Native GPS/cloud quota changes are outside this change. Test Store purchasing remains opt-in with `--dart-define=ENABLE_TEST_PURCHASES=true`; this addition does not enable production billing or bypass backend authorization. Firestore exhaustion can still leave a verified test purchase pending secure activation.

The page was rendered and visually inspected at 1179 × 2556. Android debug build passed and was installed/launched on the connected Samsung phone. Existing completed onboarding was not reset for recording. iOS icon files were exported but iOS compilation was not available on Windows.
