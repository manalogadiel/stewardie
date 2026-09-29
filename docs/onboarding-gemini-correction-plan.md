# Onboarding and tutorial correction plan

Status: implementation plan after reviewing the September 29, 2026 Flutter changes. This document records work to do; it does not claim these corrections are implemented. It supersedes the asset, age-confirmation, and tutorial-visual directions in the earlier [onboarding plan](onboarding-implementation-plan.md) where they conflict with the latest user request. Preserve Firebase email/password and verification links, and the Today / Moments / Space app.

The later [supplied mascot mapping and transition plan](onboarding-supplied-mascots-plan.md) governs onboarding artwork, background decoration, and step transitions using the user's newly added PNGs.

The [empty-space header and tour-visual plan](empty-space-and-tour-visual-plan.md) governs the no-space Today layout and accurate, account-aware tutorial examples.

## What the current code does

| Finding | Evidence | Correction |
|---|---|---|
| Mascots have a framed rectangle and visible source background. | `MascotStage` adds a border, shadow, ceramic fill, and clipping around opaque `login-*.jpg` assets. The login's newer `login-sky-front.png` is transparent, but most onboarding steps do not use it. | Prepare transparent, edge-checked clay assets; render them without a card, border, or baked backdrop. Keep the page's subtle background art separate from the character. |
| The tour offer can recur. | `OnlineHome.initState` calls `checkAndPromptTour` on each home creation. `TutorialStore.getStatus` returns `notStarted` when its nullable database is unavailable; the coordinator has no active-prompt guard. Its status also is not explicitly tied to completion of a new account's onboarding. | Offer once after first successful setup, per Firebase UID, then persist a terminal choice. Debounce within the running session. Never auto-offer from opening Space or a normal returning login. |
| Tutorial illustrations can misrepresent the app. | `TutorialExampleCard` cycles every 1.8 seconds through invented pills and generic cards. It combines a fixed place pin with a live-sharing badge, uses a generic photo row rather than the clay TV Moments viewer, and represents Today filtering with text instead of the actual mood and calendar treatment. | Use reviewed, small Flutter previews of actual app components and state changes. Keep fixed pins and live sharing visibly separate. Show examples only where the corresponding real control exists; no changes to shared data. |
| Some tour targets may be absent. | Tab targets and Today targets live in different tab subtrees. `TutorialOverlay` computes a rect immediately after requesting a tab and falls back to a generic screen position when it cannot find the key. | Wait for the destination tab's frame, resolve a visible target, and scroll if necessary. If a target is unavailable for that account/space, use an honest fallback card or skip that stop. |
| The requested age question remains. | `AccountScreen` blocks registration without an 18+ checkbox, and `OnboardingFlow`/`OnboardingStore` keep `adultConfirmed`. The legacy `OnlineAccountEntry` also has an age checkbox. | Remove the question, error, persisted draft field, and related UI from both entry paths. Review the adult-only public-release assumption separately before launch; removing this prompt does not establish an age policy. |
| Motion is only partially applied. | The shell has a 340 ms slide/fade and progress fill. `MascotStage` runs an endless float controller, even when reduced motion hides its transform. Feature-page movement and example timers do not have a common reduced-motion/lifecycle policy. `AllSetScreen` draws a one-shot confetti overlay but reuses the welcome pose. | Define short, purposeful entrances and one-shot celebrations; pause or dispose loops on backgrounding, and suppress them for reduced motion. Verify outgoing and incoming directions, focus, and interruption on a device. |

## 1. Art and screen layout

Create four production transparent PNG or WebP masters based on the approved clay character reference and the current front-facing mascot. Keep the same soft texture, proportions, light direction, and face. No rectangular background, border, text, or composited UI. Export with enough transparent padding for arms/props; inspect alpha edges against both the cream and sky login gradients at actual phone size. Preserve the original JPGs as source references until no UI points to them.

- General welcome/name/verification/permission poses: reuse or produce transparent versions only where a pose adds meaning. Do not simply erase a pale JPG background if it leaves a halo; regenerate or carefully cut out from the master art.
- Feature card 1, **Share the everyday**: a front-facing Butter mascot holding a tiny blank clay task card with one blue check, with a separate small helping-hand icon. This is an illustration, not a fake task control.
- Feature card 2, **Keep the little moments**: Rose holding a clay camera or a small photo print, echoing the app's old-TV photo treatment. No fake likes, uploaded image, or fabricated caption baked into art.
- Feature card 3, **Stay in the loop**: Mint presenting a small calendar grid beside a blue mood token; keep these as distinct props so the card represents both plans and check-ins.
- All set: a dedicated jubilant front-facing pose with raised arms, a stronger smile, and one slight upward lift. Draw a brief Flutter confetti burst in Soft Pop blue, butter, rose, and sky. Confetti remains separate from the asset so it can be disabled for reduced motion.

Change `MascotStage` to use a transparent artwork slot with no border, shadow, fill, or clipping card. Normalize each asset's visible character height and baseline; `BoxFit.contain` must show every foot and prop. Keep background art at low opacity behind content, with no pointer or semantics role. On small phones or keyboard open, reduce illustration size without moving primary form actions offscreen. The feature cards can retain an intentional surface for their text, but the mascot itself must float visually on the page.

## 2. First-use flow and age removal

Remove adult-confirmation validation and display from the new `AccountScreen` and the older account-entry path. Migrate saved onboarding drafts by ignoring/removing `adultConfirmed`; do not reset names, email drafts, or verified accounts. Keep account creation, verification-link recovery, sign-in, and founder Plus checks unchanged. Update onboarding copy and tests to omit the age question. Treat public age eligibility and store declarations as a separate release decision in the technical launch plan.

When a newly verified account finishes **All set**, record the onboarding completion for its UID and present a single optional tour invitation only after the app is ready. Persist `shown/accepted/skipped/completed` or equivalent UID-scoped state before or during display so a remount cannot duplicate it. Keep an in-memory guard for concurrent calls. Returning users, account switches, and opening any tab must not trigger the automatic invitation. If local storage is unavailable, avoid an automatic repeating invitation; a manual **Take the tour** action in Space remains available. Explicit replay should work without resetting first-use completion. Account deletion must clear local tour state.

## 3. Tutorial fidelity

Keep the existing seven-stop idea only where it matches the live product. Review each stop with the current phone UI before coding:

1. **Spaces:** spotlight the centered selector, then show the real selector sheet's Create/Join placement in a small captured or shared-component preview. Do not imply that merely switching grants membership.
2. **Today:** spotlight person chips; illustrate Everyone versus a person with the actual mood and calendar mini-card styling. Another member's mood is read-only.
3. **Tasks:** spotlight Add task and show a realistic Pending → Covered → Done sequence. Acceptance is an explicit action and completion can include an optional photo.
4. **Moments:** spotlight the Moments tab/Add moment. Show the actual old-TV image frame and optional task completion photo. Never imply a photo was shared until publication succeeds.
5. **Space:** point to the current member and Invite/Routines controls. Respect owner/member visibility; if the member cannot access an action, explain the visible alternative rather than showing a control they lack.
6. **Map and places:** use the top map button. Present an optional fixed photo/task pin separately from an explicit 15/30/60-minute live-sharing session. Opening a map does not start sharing.
7. **Notifications:** point to the actual bell and show a current-style inbox item and actionable request state, without claiming push is configured.

Replace `TutorialExampleCard`'s timer-driven mockups with small deterministic previews built from the same visual tokens or extracted production components. Label examples, keep them read-only, and offer a user-controlled replay only if an actual animation teaches a state transition. Wait for tab navigation and scrolling to settle before placing the spotlight. An absent target must not create a spotlight on an unrelated screen area. Skip unavailable stops gracefully for a no-space or approval-pending account. Keep Skip, Back, and Next reachable at enlarged text and with screen readers.

## 4. Unified motion rules

Use the existing 340 ms shared-axis slide/fade as the base, but ensure the outgoing page travels opposite the incoming page and Back reverses both. Stagger title, supporting text, then field/card by roughly 60 ms when entering; avoid replay on validation changes. Keep progress fill smooth and clamped, button presses brief, and focus on the new screen heading after navigation. Feature-card swipes and Next must land on the same page state; a rapid second tap cannot skip a card.

Use a one-time mascot entrance or subtle pose change rather than persistent bouncing. The All set mascot may rise once with the confetti burst; the action button works immediately. For `disableAnimations`, use a short fade only: no movement, scaling, page-swipe animation, idle float, tutorial auto-cycle, or confetti. Pause any active controller or timer when the app goes inactive and resume only if its screen remains visible. Keep touch feedback and status changes understandable without animation.

## Build order and acceptance

1. Produce and inspect transparent art, including all three distinct feature props and the new celebration pose. Confirm no pale JPG rectangle or halo on both login and onboarding backgrounds.
2. Refactor the mascot stage and feature/all-set layouts using those assets. Review 360 px and larger phones, keyboard open, and enlarged text.
3. Remove age UI/state from both auth paths and migrate drafts safely. Verify signup and older-account sign-in still use Firebase verification links.
4. Fix the UID-scoped tutorial invitation lifecycle and manual replay. Test fresh account, app restart, sign-out/sign-in, Space tab revisits, local-store failure, and another account on the same phone.
5. Replace the seven tour examples and target timing. Compare each preview against the production screen, including permissions/role-dependent controls and no-space states.
6. Consolidate motion and reduced-motion behavior. Inspect actual playback, Back, fast taps, app background/resume, and focus, not only still widget renders.
7. Run focused analysis and meaningful widget/state tests. Test the invite is offered once, skipped/completed states persist, returning logins do not re-offer, replay is explicit, and each spotlight resolves to the intended visible control. Record any device-only verification limits.

No paid service, cloud deployment, or store publishing is part of this correction.
