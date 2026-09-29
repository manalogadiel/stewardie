# Stewardie welcome and account onboarding

Status: proposed implementation plan, September 29, 2026. No application code or cloud configuration is changed by this document. The user confirmed **Firebase email/password with an email verification link**, rather than numeric codes or passwordless signup.

Subsequent login-only visual implementation: [static front-facing mascot and playful headline](login-static-mascot-polish.md). The new `login-sky-front.png` is available for reuse; the seven-screen flow and post-login tutorial below remain unimplemented by that change.

## Outcome and boundaries

Build a seven-screen welcome flow using the user's selected static 3D clay illustrations, with one character visible per step. The four JPGs below supersede the earlier GIF/single-blue-character direction for this flow. Preserve the existing Firebase identities, account recovery, founder Plus grant, and Today / Moments / Space destinations. Existing signed-in users keep their access; returning users have a direct Sign in route. This work does not activate paid services, OneSignal, or public publishing.

Use the approved [UI tokens](ui-plan.md) and [character reference](soft-pop-character-reference.png). Camera, location, and notifications are optional. Completing onboarding never starts location sharing, joins a space, or grants permission on the user's behalf.

## 1. Screens and copy

| Screen | Content and interaction | Mascot direction | Progress on arrival |
|---|---|---|---|
| 1. Hi! Welcome | “Little things, together.” One primary **Get started** button. A quiet **Already have an account? Sign in** text link preserves returning access. | Butter welcome image; soft entrance scale. | 0% |
| 2. What should we call you? | One name field, **Continue**. Accept real names with spaces and Unicode; trim surrounding whitespace. Use the existing profile limit and support long names without shrinking essential text. | Mint attentive image; calm whole-image float. | 1/6 |
| 3. Add your email | Email and password with autofill, a visibility toggle, and clear validation. Include the existing adult-account confirmation and available privacy/terms links. **Create account** sends the verification email. Do not invent published policy links. | Sky holding a key, appropriate for account access. | 2/6 |
| 4. Check your email | “We sent a verification link to [email].” **Open email**, **I've verified**, **Resend email**, and **Change email**. The verification state comes from Firebase. | Mint attentive now; optional matching envelope asset later. | 3/6 |
| 5. Make it yours | Three optional permission cards, one at a time as needed, plus **Continue**. Show actual granted/denied/unavailable states. | Rose peekaboo; vector highlights indicate each card. | 4/6 |
| 6. A little less to juggle | Three short swipeable feature cards, page dots, **Next**, then **Let's go**. Provide buttons as alternatives to swiping. | Alternate the selected illustrations; optional task/photo/calendar assets later. | 5/6 |
| 7. All set, [Name]! | Brief restrained confetti and **Open Stewardie**. The button is immediately usable; do not force the user to wait for an animation or automatically navigate before assistive technology can read the message. | Butter welcome reused for celebration with a single gentle lift. | 100% |

Steps 1–6 are the six completed actions. The last card's **Let's go** transition fills the remaining sixth as screen 7 arrives. Feature-card swipes do not move the main progress bar. Back reverses to the relevant step's progress; screen numbers are not visible.

Suggested feature-card copy:

1. **Share the everyday** — “See what needs help, who's covering it, and what's done.”
2. **Keep the little moments** — “Share photos and celebrate things you finish together.”
3. **Stay in the loop** — “Check moods and plans in each of your spaces.”

Screen 7 enters the current space when one exists. An account without spaces reaches the existing useful empty state with **Create a space** and **Join with a code**. Preserve an invitation being redeemed through authentication; resume its preview and confirmation rather than silently joining it.

After this handoff, offer the optional [in-app tutorial showcase](#9-post-login-tutorial-showcase). The three onboarding cards introduce the benefits; the showcase teaches where the features are and how to use them.

## 2. Visual and motion system

- Warm near-white canvas, a subtle sky-tinted backdrop behind the mascot, cream surfaces, charcoal text, and the existing electric-blue primary accent. Keep Nunito Sans and existing spacing/radii. Pastel blue is decorative; meaningful text and focus indicators must have adequate contrast.
- Use one mascot stage, roughly 160–200 logical pixels tall on ordinary phones. Reduce its height or hide decorative idle motion when the keyboard opens. Avoid moving the field or primary button as the mascot changes pose.
- A thin rounded progress pill sits beneath the safe area, with a 48-pixel Back target alongside it after Welcome. Use a critically damped spring or restrained ease-out spring, clamped to 0–1. Announce progress to screen readers even though no numbers are visually shown.
- Forward transitions fade and translate about 16–24 pixels left/right over 340 ms with ease-out; Back reverses direction. Stagger title, supporting copy, and field entry by about 60 ms. Keep focus out of the outgoing page and move it to the new heading after navigation.
- Focus glow supplements a clearly visible input boundary. Primary buttons press to about 0.98 scale. Loading swaps the label for a labeled progress indicator without changing width; success can crossfade to a checkmark only after the operation succeeds. Block duplicate submissions, not Back or cancellation of unrelated work.
- Respect reduced motion: approximately 100 ms fades, no translation, spring, bounce, scaling, or confetti; use a still mascot. Pause all animation when the app is backgrounded. Validation uses inline text and a screen-reader announcement; no code-box shake is needed for the selected link-verification flow.

## 3. Mascot assets

Confirmed asset direction: use the following existing JPG illustrations from `assets/illustrations/` for login, onboarding, and the tutorial. All four were visually inspected during planning. Replace the GIF playback path in `lib/online/login_scene.dart` during implementation; do not load, precache, or cycle the old GIFs in the new flow. This planning change does not physically delete existing files. Remove obsolete files only after a repository-reference check during implementation.

| Existing file | Onboarding use |
|---|---|
| `login-butter-welcome.jpg` | Yellow character with raised arms: Welcome and All set |
| `login-mint-attentive.jpg` | Mint character with hands near its chest: name entry and waiting |
| `login-rose-peekaboo.jpg` | Seated rose character peeking: permission education and tutorial cues |
| `login-sky-key.jpg` | Sky character holding a yellow key: account entry and sign-in |

- Match new illustrations to these files' soft clay texture, simple dark faces, pastel colors, proportions, and soft lighting. Show one mascot at a time; no collage or return to the old procedural GIF model.
- Animate presentation in Flutter: a 3–5 pixel float, restrained whole-image tilt, entrance scale, and fade-through between pictures. Static JPGs cannot blink or move individual hands; do not claim articulated character motion without additional pose frames. Reduce motion uses the same static pictures without transforms.
- The JPGs contain opaque pale backgrounds and have different framing/aspect ratios. Use `BoxFit.contain`, normalize displayed character scale, and design a deliberate pale illustration panel. Do not stretch/crop feet or pretend JPGs have transparency. Avoid floating a visible rectangular image boundary over a gradient.
- For seamless floating illustrations, prepare transparent PNG/WebP derivatives in a separate asset-production step, preserving these originals. Keep transitions anchored to a common visual center and baseline; precache only the current and next asset.
- Select art from onboarding state and actual successful actions rather than a random timer. Review the screen-to-screen transition preview before integration is complete.

### Suggested assets to generate

These are static additions in the selected JPG style, not GIFs. The four existing images are sufficient to build the initial flow; prioritize additions that explain a missing concept.

| Priority | Suggested file | Visual and use |
|---|---|---|
| First | `onboarding-sky-envelope.png` | Sky holding one cream envelope with a blue seal; email verification. No text baked into the envelope. |
| First | `tutorial-mint-guide.png` | Mint with one arm gesturing toward open space to its side; tutorial coach. Export separate left/right variants if needed rather than mirroring readable props. |
| First | `tutorial-butter-task.png` | Butter holding a small rounded checklist with one blue check; task introduction. Flutter renders all actual labels/statuses. |
| Next | `tutorial-rose-camera.png` | Rose holding a simple cream camera; Moments introduction. Keep the camera visually distinct from a phone. |
| Next | `tutorial-mint-calendar.png` | Mint beside a small blank calendar with a few blue date squares; shared plans. No dates or text embedded. |
| Next | `tutorial-sky-place.png` | Sky beside a separate soft clay location pin; maps. Keep the live-sharing timer and Stop control in Flutter. |

Asset production brief: use the matching existing image as the character reference; create one full-body character with one clear prop, consistent front/three-quarter camera and soft upper-left lighting, generous transparent padding, and no typography, watermark, UI chrome, or baked confetti. Target a 1024×1024 transparent PNG master and optimized display derivatives. If a transparent derivative is made from an existing JPG, check fine edges and pale halos. Keep confetti, progress, arrows, badges, and spotlights as lightweight Flutter graphics.

## 4. Firebase registration and verification

Retain `OnlineBackend.register`, `signIn`, and password recovery as the starting point. Firebase's Flutter integration supports password accounts and `sendEmailVerification()`; this plan uses that verified-link behavior, not an OTP UI. [Firebase password authentication](https://firebase.google.com/docs/auth/flutter/password-auth), [Firebase user management](https://firebase.google.com/docs/auth/flutter/manage-users).

- Validate name, email, password, and adult confirmation before creating the account. Respect the configured password policy; never trim or persist the password in the onboarding draft.
- Separate **account created** from **verification email sent**. If creation succeeds and email sending fails, keep the authenticated unverified account and offer resend; do not retry account creation and produce an email-already-in-use loop.
- **Open email** launches an available mail app, with a clear fallback if none can be opened. Opening mail is not evidence of verification. **I've verified** reloads the Firebase user and refreshes the ID token; only a confirmed verified account advances. Also check on foreground resume after visiting email.
- Resend has a persisted next-allowed timestamp of at least 30 seconds and honors Firebase throttling/backoff. Show time remaining and a useful retry state. Never promise delivery based only on a button tap.
- Before account creation, Back can edit email normally. After creation, **Change email** uses Firebase's supported verified email-change path with recent reauthentication when required; retain the UID, invalidate the displayed verification target, and wait for the updated verified address. Do not create a second account or let editing a local field change identity. Verify the exact Flutter API behavior against the installed Firebase SDK during implementation.
- Preserve existing-password sign-in, forgotten-password recovery, remembered email/name, and accounts created by older app versions. A returning user does not have to repeat first-use feature education merely to sign in.
- Shared data remains protected by Firebase verification and existing rules. A local onboarding flag cannot bypass authentication, email verification, membership, or account-tier checks.

## 5. Optional permissions

Present one card per capability with its own **Allow** and **Not now** controls. Trigger one OS prompt only after that card's Allow action. Never queue all three prompts automatically.

| Capability | Suggested reason | Behavior |
|---|---|---|
| Camera | “Scan invitations and take photos for your space.” | Request camera access only. Microphone and photo-library access are not bundled into this prompt. Keep code entry and the system photo picker available where supported. |
| Location | “Center maps on you when you choose.” | Request foreground/while-in-use access only. Do not fetch or upload a coordinate just because permission was granted. Live sharing and any background permission remain a later explicit action with recipients and expiry. |
| Notifications | “Get reminders and updates from your spaces.” | Ask only when the mobile push integration is configured and can deliver. `PushService.available` is currently configuration-gated; until ready, the card says **Set up later**, leaves Continue usable, and explains that updates remain in the in-app inbox. |

After denial, continue normally and do not immediately prompt again. When the OS prevents another request, offer an explicit **Open Settings** action with a return/resume status refresh. Re-read actual permission state after resuming and before using a feature; stored onboarding choices do not represent current OS permission. Web/desktop and unsupported platforms receive an honest unavailable state.

## 6. State, persistence, and routing

- Introduce an onboarding coordinator/state machine: `welcome → name → email → verify → permissions → info → done`. Keep navigation/validation in its controller and presentation in the screens.
- Persist schema version, step, name/email draft, adult confirmation, resend timestamp, selected feature-card page, and permission-card decisions. Before authentication, scope the draft to this installation; after authentication, bind it to the Firebase UID and reject mismatched drafts.
- Never persist passwords, verification links, action codes, or Firebase tokens in the draft store. Firebase's SDK owns session persistence. Discard the previous email's resend/verification state after a confirmed identity change.
- On restart, wait for Firebase session restoration, then reconcile the draft against the actual user and verification state. An expired or signed-out session returns to sign-in; a verified account never gets stuck behind a stale Verify step.
- Use a versioned, UID-scoped completion record rather than one installation-wide Boolean. Persist completion when screen 7 is reached so a crash on the payoff does not replay the entire flow. Existing verified users default to completed for this rollout; offer feature education later from Help if desired, without forcing it on them.
- Add a small account-owned server completion/version field after verification for reinstall and cross-device consistency, with corresponding narrow Firestore rules. Keep a local cache; a failed completion-metadata write must not block verified app access. Older accounts without this field are handled explicitly as legacy accounts.
- On sign-out, account switch, or account deletion, clear transient onboarding data and integrate the new local record into existing cleanup. Keep remembered-account behavior separate and opt-in.
- `OnlineApp` currently routes verified users directly to `OnlineHome`. Replace that decision with the coordinator so verification does not skip Permissions, Info, and All set for a genuinely new signup.

## 7. Implementation sequence and files

1. **Foundation and selected illustrations:** replace the planned GIF renderer with a state-driven component using the four selected JPGs; reuse `lib/core/theme.dart` tokens. Normalize framing and plan opaque-background treatment or separate transparent derivatives. Build the shell with available art; generate the prioritized static additions only when asset production begins.
2. **Coordinator and shell:** add `lib/features/onboarding/` with state, persistence, progress, motion wrapper, responsive layout, and Back handling. Integrate `lib/online/online_app.dart` without breaking returning sign-in.
3. **Welcome, name, and account entry:** implement screens 1–3 with keyboard/autofill behavior, adult confirmation, inline validation, and recoverable registration errors using `lib/online/online_backend.dart`.
4. **Verification:** adapt the existing verification screen into screen 4; add resend cooldown persistence, resume/reload, mail-app fallback, and secure change-email handling.
5. **Permissions:** reuse the camera/location/push services through a small permission adapter; check existing dependencies before adding one. Add denied/permanently-denied/configuration-unavailable states.
6. **Education and finish:** add the three cards, accessible controls, personalized completion, and routing into existing-space or no-space UI. Keep pending invitations intact.
7. **Integration and polish:** wire state-driven mascot actions, completion persistence/rules/cleanup, reduced motion, accessibility, and focused tests. Update this document and a verification record with observed results.
8. **Post-login showcase:** implement the optional anchored tour in section 9, connect its targets to the existing screens, and add replay and account-scoped resume behavior.

## 8. Acceptance and verification

- Fresh install, signup restart at every step, password omitted from saved drafts, account switch, returning account, sign-out, and old-version upgrade routes behave correctly.
- Registration success with email-send failure recovers without duplicate creation. Wrong email, expired verification link, still-unverified refresh, resend throttle, no mail app, and verification on another device are handled.
- Progress has six increments and reaches 100% on the payoff; Back and rapid navigation do not stack transitions or lose valid input. Resuming screen 6 preserves its feature-card page.
- Each permission can be skipped or denied without blocking completion. Background location is never requested here; granting location never starts sharing. An unconfigured push service never claims notifications are enabled.
- Narrow phones, large text, keyboard open, screen readers, and reduced motion retain usable fields, 48-pixel controls, readable labels, and stable focus. Error/loading/success states do not shift the button layout.
- New account completion enters the correct space/no-space/invitation path. Existing user data, personal Plus, and Today / Moments / Space remain intact.
- Run controller/persistence/routing tests, focused widget tests, and any changed Firestore rules tests. Native prompts, email delivery, and mascot motion quality receive device verification. Record limitations rather than calling those verified from a widget test.

## 9. Post-login tutorial showcase

### Entry and pacing

After account setup and the All set screen, show a compact invitation over the app: **A quick look around?** with **Show me around** and **Explore on my own**. Do not automatically launch the tour on every login. Aim for roughly one minute of concise content, but let the user control the pace with **Back**, **Next**, and always-visible **Skip tour**. Finish with **You're ready** and **Start using Stewardie**.

The onboarding progress bar stays completed. The tour uses its own small progress dots and accessible stop count; it is optional education, not more account setup.

If authentication began from an invitation, let the user finish the existing preview/join or approval flow first. If no space exists, highlight **Create a space** and **Join with a code**, and offer an optional illustrated feature preview. Do not create a sample shared space or insert tutorial tasks/photos. After the user enters their first space, offer the real-screen tour once. Keep waiting-for-approval and offline empty states usable.

### Tour stops and visual demonstrations

Use a warm translucent scrim, a softly rounded spotlight around the actual control, and one cream explanation card. Place one of the selected clay illustrations beside the explanation at a smaller scale so the UI remains the focus. Each stop has one clear idea and at most two short sentences.

| Stop | Real screen or target | Explanation | Animated visual |
|---|---|---|---|
| 1. Your spaces | Centered top space selector | “Keep each group in its own space. Switch, create, or join here.” | Butter welcome or Rose peekaboo; the selector gets one gentle highlight pulse. A small example shows two space pills switching, without changing membership. |
| 2. Your day, together | Today person filters, mood, and calendar | “Everyone brings the space together. Choose a person to see their mood and plans.” | A small in-memory preview switches Everyone to one example member and updates the illustrated mood/calendar together. It never submits a check-in. |
| 3. Ask, cover, finish | Add-task control and task sections | “Add something that needs doing. Members can accept it, ask for help, and mark it done.” | A clearly labeled example task moves through Help → Covered → Done, with acceptance shown before ownership. Use a shallow card lift and a single success check. No real task is changed. |
| 4. Keep a moment | Moments tab and Add moment | “Share a photo, or add one when you finish a task. Completion photos appear here too.” | A bundled example photo settles into the existing clay TV frame; show a swipe cue and an expand cue. No camera prompt, upload, or save action occurs. |
| 5. Your people and routines | Space tab, members, Invite members / Routines | “Bring people in and organize repeating tasks.” | Mint attentive illustration; invite and repeat icons brighten in sequence. Show only controls the current member is allowed to use and explain owner-only management when relevant. |
| 6. Places and sharing | Top map button | “Photo pins mark a fixed place. Live location is separate: choose who can see it and for how long.” | A fixed photo pin stays still while a separate illustrated live marker displays a 15-minute timer and Stop control. Keep this illustrative; do not open GPS, fetch personal location, or begin sharing. |
| 7. Updates in one place | Notification bell | “Find task requests and updates from your spaces here.” | A small example unread badge resolves into an inbox row. Mention phone reminders only if push is configured; the in-app inbox is available independently. |

End on Today, with the user's selected space and person filter restored. For a replay, also restore the original tab when the user skips or closes early. Do not modify remembered filters or other durable preferences merely to position tutorial targets.

### Animation and layout

- Crossfade the scrim while the spotlight moves to its new target over roughly 280–340 ms with ease-out. For cross-tab steps, use the app's normal tab navigation, wait until the target is laid out, then reveal its highlight. Avoid animating a spotlight across unrelated or unloaded screens.
- Explanation cards fade up about 12 pixels; example cards use soft shadows and restrained motion. Give examples an explicit **Example** label inside the tutorial. Use actual app widgets with isolated presentation data where practical so the demonstration matches the app.
- Reuse the four selected JPG illustrations. The spotlight and a simple vector connector indicate the target; the proposed mint guide is an optional static addition. Apply one small Flutter scale/lift to Butter on completion rather than loading a GIF.
- Play each visual demonstration once, with a small **Replay animation** action if useful. Do not auto-advance, repeatedly pulse the screen, or block Next until an animation finishes. Back/Skip remains responsive throughout.
- Measure anchors from their widgets, not hard-coded device coordinates. Reposition the explanation above or below the target within safe areas; scroll the target into view before showing it. Use a compact bottom card when text is enlarged or the target has little surrounding room. Do not cover the target or bottom navigation with explanatory controls.
- Reduced motion uses still diagrams and short fades. Screen readers receive the stop title, explanation, progress, and navigation in order; decorative mascot/spotlight layers are excluded. Prevent focus and taps from leaking to underlying actions while the tour overlay is active. Back exits or returns a stop predictably; Skip always dismisses immediately.

### State and integration

- Keep tutorial state independent from onboarding completion: tutorial version, `notStarted / inProgress / skipped / completed`, current stop, and account UID. Persist it in the existing local account-scoped store and clear it through account cleanup. No new tutorial-specific cloud service is needed.
- After interruption, offer **Continue tour** rather than trapping the user in an overlay. Validate the saved stop against current membership, screen availability, and role; missing targets get a concise fallback or are skipped. Sign-out, account switch, or access loss closes the tour immediately and prevents old account content from remaining visible.
- Add **Take a tour** under Space's Help/account area, including the no-space account view. Replay should work for existing users without repeating registration or permission prompts.
- Add `lib/features/onboarding/tutorial/` with a small coordinator, stable target registry, overlay, and illustrative cards. Connect targets in `OnlineHome`, the top selector/map/bell controls, Today cards, Moments, Space actions, and the dock. Keep step descriptions and target availability separate from layout code.
- Tutorial demonstrations use local presentation state only. They must not call task mutations, invitations, membership APIs, camera/gallery acquisition, location collection, photo upload, push permission, or notification read-state writes.

### Acceptance checks

- New signup receives one optional tour invitation; returning login is not interrupted repeatedly. Skip, resume, and replay work independently for each account.
- A member with no spaces, pending approval, removed membership, an owner role, and a nonowner role each receives valid guidance without inaccessible targets or fake shared records.
- Targets stay aligned during scroll, tab changes, screen rotation, large text, and layout updates. Every stop works using buttons without requiring a swipe or precise tap through the spotlight.
- The tour leaves no changed tasks, moods, calendar plans, media, memberships, location sessions, notification read states, or unexpected permission prompts. Restore the user's original navigation context on early dismissal.
- Check spotlight placement, animation interruption, screen-reader focus, reduced motion, and lifecycle resume with focused widget tests and the later physical-device review. Distinguish these checks from the ongoing map/backend verification.

## Setup and launch gates

No new email provider is required for the confirmed Firebase verification-link route. Check the existing email template and sender configuration during implementation. OneSignal remains a later setup; this onboarding flow must work with that integration absent. Missing mascot assets, final public privacy/terms URLs, and native-device verification are explicit deliverables/gates, not reasons to activate billing automatically.
