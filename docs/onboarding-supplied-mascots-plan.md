# Onboarding art and transitions: supplied mascot assets

Status: implementation plan, September 29, 2026. This refines the [onboarding correction plan](onboarding-gemini-correction-plan.md). The user's new images are the source of truth for onboarding steps 2–5 and 7. Keep the existing Butter welcome asset for step 1 and the existing three purpose-made feature-card assets for step 6. This plan does not itself change the Flutter UI.

## Findings and exact screen mapping

The current `MascotPose` enum points to `onboarding-mint-attentive.png`, `onboarding-rose-peekaboo.png`, `onboarding-sky-key.png`, and `onboarding-celebrate.png`, none of which exist. `MascotStage.errorBuilder` silently substitutes a face icon, masking missing assets. `LoginBackdrop` still requests deleted `login-butter-welcome.jpg` and `login-rose-peekaboo.jpg` and paints an `auto_awesome` sparkle. Because the whole seven-step flow uses `LoginBackdrop`, its missing background files and sparkle affect onboarding too. The supplied PNGs appear transparent but have noticeable pale/colored halos at their silhouette edges; inspect them against the actual near-white/sky canvas before shipping.

| Screen | Use this source file from `assets/illustrations/` | Direction |
|---|---|---|
| 1. Welcome | `onboarding-butter-welcome.png` | Preserve current Butter hero and framing. |
| 2. What should we call you? | `onboarding - attentive.png` | Mint character listening/attentive. |
| 3. Add your email | `onboarding sky key.png` | Sky character with key. |
| 4. Verify email | `onboarding - email verification.png` | Mint character holding the envelope; no numeric-code imagery. |
| 5. Make it yours | `onboarding - make it yours.png` | Rose character, playful/curious. |
| 6. A little less to juggle | `onboarding-butter-task.png`, `onboarding-rose-camera.png`, `onboarding-mint-calendar.png` | Preserve three distinct task/photo/mood-and-calendar concepts, one per swipeable card. Review their visible edges and actual card sizing. |
| 7. All set | `onboarding - done.png` | The single raised-arms Butter character is the main hero. Use a brief Flutter confetti burst in the Soft Pop palette. |

`celebrate.png` is a group illustration with baked stars. It is not the main All set mascot and should not become a large low-opacity background layer; preserve it for other approved app uses. Keep the exact user-supplied original files untouched. Prefer making clean, optimized derivatives with predictable filenames and document source-to-derivative mapping. If any derivative cannot be made without an obvious halo, report that limitation rather than hiding it with a colored card or adding a border.

## Asset and background treatment

1. Verify dimensions and alpha channels of every mapped file. Preview each over warm near-white and pale sky at the size it will occupy on a 360-pixel phone. Remove edge contamination/white or cyan fringing from derivative assets while retaining the soft clay outline and shadows. Do not use a hard crop that cuts off raised arms, feet, key, envelope, or camera. Normalize visual height and baseline across steps in `MascotStage` with `BoxFit.contain`, not a stretch.
2. Wire every screen and the enum to existing assets. Keep image loading errors visible during development rather than silently replacing an intended mascot with a generic icon. The `pubspec.yaml` illustration directory registration already includes these files; a new dependency is unnecessary.
3. Replace the broken `LoginBackdrop` decorations. Remove the `auto_awesome` sparkle and any other sparkling background asset from the onboarding/login composition. Add restrained, low-opacity clay props or character silhouettes from valid transparent assets at the outer edges, away from headings, fields, and buttons. Use two or three different placements/colors across the flow rather than the same ghost image on every page. Background elements are decorative only: `IgnorePointer`, `ExcludeSemantics`, and omitted in high-contrast mode.
4. Paint one or two soft, irregular wavy lines or curved ribbons in Flutter behind the content, using sky/butter/rose tints at low opacity. No bright outline behind text, no dense pattern, and no motion required. The page gradient, waves, and faint art should form one coherent system while the front mascot remains the clear focal point. Keep the front asset full opacity with no framed rectangle, border, or baked image background.

## Screen transitions and motion

Use a consistent scene change between the seven steps: outgoing content fades and moves about 16–20 logical pixels toward the departure side while incoming content fades from the opposite side over about 300–380 ms; Back reverses both directions. Keep the progress pill and background anchored so forms do not jump. Transition the mascot within its reserved stage with a brief fade and small settle; avoid a second competing slide. Precache only the current and next mascot after route state is known, so stepping forward does not flash or show an empty frame. Do not crossfade to an old JPG or a placeholder icon.

Stagger the heading, supporting text, and input/card entrance subtly (roughly 50–60 ms), without re-triggering on typing or validation. Keep the primary action fixed and usable during the All set confetti. Step 6 must keep swipe, Next, dots, and restored page index in sync. Avoid double-advance on rapid taps. For reduced motion, use a short fade without translate, scale, mascot lift, or confetti. Pause any active controller when the app is backgrounded. Decorative waves and low-opacity art remain static.

## Scope and checks

Follow the larger correction plan for age-question removal, tutorial fidelity, and one-time first-login invitation; this art refinement does not replace those requirements. Preserve Firebase password sign-in and verification links, Today/Moments/Space, and existing shared-data behavior. Do not enable paid services or publish.

Review all seven steps on small and larger phones, keyboard open for steps 2/3, long names, enlarged text, and high contrast. Inspect still frames for halos and backdrop failures and watch forward/back/repeated taps for smoothness. Run focused Dart analysis and relevant onboarding tests. Verify every referenced asset exists and loads. State which visual/device checks were actually performed.
