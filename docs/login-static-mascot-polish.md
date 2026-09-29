# Static login mascot and typography

September 29, 2026. This implements the login-page visual change only; the multi-step onboarding and tutorial remain planned in [the onboarding plan](onboarding-implementation-plan.md).

- Login uses `assets/illustrations/login-sky-front.png`, a new front-facing, transparent clay character closely based on `login-sky-key.jpg`, without the key. `LoginScene` no longer loads GIFs or runs an animation timer. Older GIF source files are retained, but the login page does not use them.
- “A little more together” uses locally bundled Fredoka. Form copy retains Nunito Sans. Fredoka is sourced from the [official Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/fredoka); its license is included as `assets/fonts/Fredoka-OFL.txt`.
- A warm/sky background and Butter/Rose artwork at 8.5% opacity frame the page. Decoration ignores taps and screen readers and disappears in high-contrast mode. The mascot shrinks when the keyboard is open; the form remains scrollable.
- Firebase registration, sign-in, recovery, and email verification behavior are preserved. No new service or runtime font download is introduced.

## Asset provenance

Generated with the built-in image-generation tool using `login-sky-key.jpg` as the reference, with transparent background enabled. The selected output was copied into the project's illustration directory; the original reference remains intact.

Prompt:

> Create a production PNG asset for the Stewardie Flutter login screen, based closely on the supplied sky-blue clay mascot reference. Same matte softly textured pale sky-blue clay, rounded chubby silhouette, tiny dark curved smiling eyes and friendly mouth, short rounded arms and stubby feet. One full-body character, exactly front facing and symmetrically facing the viewer, no three-quarter angle. Remove the key and all props. Arms open slightly in a welcoming pose, cheerful relaxed expression. Preserve the reference's rich soft 3D studio rendering and proportions; do not make a flat drawing or plastic toy. Soft upper-left light and subtle ambient occlusion, transparent background with no baked white rectangle, no typography or decorative objects. Entire feet and hands visible, centered square composition, about 12 percent transparent padding. Output suitable for a small mobile login hero.

## Verification

The generated image and the 360 × 780 login composition preview were visually inspected. The focused login widget test passed with reduced motion enabled and artwork explicitly loaded before capture (`build/review/login-polish-360.png`). This preview exercises the shared visual components, not the complete authenticated entry flow. Focused Dart analysis of `login_scene.dart`, `online_app.dart`, and `polish_review_test.dart` reported no issues. No live authentication or physical-device verification is claimed by this visual change.
