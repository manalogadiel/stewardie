# Onboarding notices

Implemented October 1, 2026. The account-creation page's former plain consent line now has visible Privacy Notice and Community Guidelines buttons. Both open local, readable sheets without an account or network request. Account Settings also links to the Privacy Notice. Reading/dismissing them preserves entered signup values; no age gate was added.

The Privacy Notice describes the current pilot's account/shared content, optional location/camera use, notification and subscription data, Firebase/Supabase/MapTiler/RevenueCat processing, and current deletion limitations. It avoids promising instant erasure or permanent retention. This is a product disclosure, not a completed public-release legal/compliance review; final support identity, retention periods and provider terms still require the existing release review.

Focused analysis passed. The account screen test opens both notices, closes Privacy Notice, and confirms the email draft remains intact. Onboarding regression tests also pass.

Account deletion follow-up: confirmation uses a scrollable dialog and owns/disposes its text controller. A 320 × 640 layout with 160% text and a 300-pixel keyboard inset passed without overflow; Cancel preserved the no-deletion result. Focused analysis passed. No account deletion was submitted during verification.
