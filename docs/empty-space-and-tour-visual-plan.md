# Empty-space Today header and truthful tour visuals

Status: implementation plan, September 30, 2026. This refines the [onboarding correction plan](onboarding-gemini-correction-plan.md) after review of the current Flutter UI and the user's two screenshots. The screenshots illustrate the reported defects; their contents are reference evidence, not instructions. No app code is changed by this document.

## What is wrong now

- `OnlineHome._today` renders the no-space state through `_page`, whose `ListView` applies 20-pixel side padding and `topControlsClearance` before `_hero`. The yellow Today card therefore begins below the floating top controls and has white margins. Populated Today uses `_todayPage`, whose yellow hero begins at the top and reserves clearance **inside** the color surface. The empty state should use that same geometry.
- `TutorialExampleCard` draws standalone miniature UI. The first stop shows a selected `Home` space with an `Active` badge and two horizontal buttons, even though the pictured account has **no space**. The actual selector says `My spaces`, and `OnlineHome._chooseSpace` presents a bottom sheet with **Create a space** and **Join with a code** as full-width list actions. Other examples similarly approximate controls rather than using their actual shape, copy, state, and behavior.
- The tour is an overlay on live tabs. A target can be missing when the account has no space or the destination tab has not laid out. Showing a fabricated preview in that case teaches a screen the person cannot currently see.
- The shared `MemberAvatar` uses a `CircleAvatar` text child whose glyph appears off-center at chip size in the supplied screenshot. The Space account card inserts a literal `·` before Basic, and opens account settings through a text link below the card.
- `NotificationSettingsSheet` opens from the account sheet without a root-level presentation and does not constrain its scrollable content above the floating dock. The supplied screenshot shows the time-zone control and Save action obscured by the dock.
- The top map button is disabled when `selected == null`, and `SpaceMapSheet` requires a non-null space ID. This prevents a new account from opening a private map even though no-space map viewing does not require space membership.

## 1. Make the empty Today hero reach the top

Refactor the no-space Today branch to use the same edge-to-edge header structure as populated Today. Prefer one shared Today-hero widget/sliver used by both branches, with content variants for date/greeting versus the no-space introduction. Paint `SoftPop.today` from the top of the content area behind the centered selector, map button, and bell; place safe-area/top-control clearance **inside** that surface. Keep square top corners and 28-pixel rounded bottom corners. Put the no-space help panel and `Choose a space` action below the hero with normal horizontal page padding and adequate separation. The yellow surface should not be wrapped in `_page`'s outer top/side padding.

Check status-bar and notch backgrounds: the top color should extend to the actual screen top behind system insets without covering text or the floating controls. Preserve existing action taps and the automatic first-entry Create/Join sheet. Do not change the populated Today layout or Space header to fix only the empty branch. If the empty Moments header uses the same visibly inset pattern, apply the same shared header treatment there for consistency after visual review.

## 2. Replace the tour's invented mini screens

Build a small visual reference matrix from the **running app** before redesigning previews. Capture Today with and without a space, the selector sheet, Today person filters/mood/calendar/tasks, a Moments photo in its clay TV frame, Space member/actions, the map entry, and the account inbox. Use the same Flutter components or compact variants driven by local read-only example data where practical. Do not screenshot and bake fake text into an image; examples should adapt to width and text scale. Keep a clear `Example` label only where the preview genuinely shows hypothetical data.

| Tour stop | Accurate teaching target |
|---|---|
| Your spaces, no-space account | Spotlight the real `My spaces` selector. Show the actual Create/Join bottom sheet, or a faithful compact vertical excerpt of its two list actions. Do not show a selected `Home` space or an `Active` badge. |
| Your spaces, member account | Spotlight the selected space selector. If a preview is needed, use the actual sheet's space row, circular selection icon, and Create/Join rows. Use a generic clearly labeled example name only in this branch. |
| Your day, together | Match the real Everyone/Me/person chips with stable avatars and the two equal-height mood/calendar cards. Show that another person's mood is view-only. Avoid generic emoji or a text-only calendar substitute. |
| Ask, cover, finish | Match the current Pending/Done tabs and Help/Covered/Done wording, task card structure, and explicit acceptance before coverage. A sample task must stay local to the preview. |
| Keep a moment | Use the real `ClayTelevision` proportions or an extracted compact visual component with a photo-shaped placeholder, caption/author treatment, and the actual Add moment entry point. Do not claim an upload happened. |
| Your people and routines | Match the Space page's member treatment and two pastel Invite members/Routines tiles. Show only actions the current role can access. |
| Places and sharing | Spotlight the top map control. Keep a saved place pin separate from an explicitly started 15/30/60-minute location session. Match the current map-layer selector style when depicted. |
| Updates | Match the bell/unread badge and actual account inbox row, space label, timestamp, and request state. Do not imply push delivery is configured. |

The seven-stop tour can remain for an account **with** a usable space. For a no-space account, offer a short, truthful selector/Create-or-Join walkthrough and end there; the account should reach the real create/join flow immediately. Do not auto-run the full seven stops against absent Today, Moments, or Space content. After the account joins/creates its first space, it may explicitly choose **Continue tour** once; this must not reopen on every Space tab visit or normal sign-in. Keep the existing manual **Take the tour** replay available.

Keep explanatory text short and let the real highlighted control do most of the teaching. If a target has not appeared after tab navigation, wait for layout and scroll it into view; if it is truly unavailable for the account, skip that stop or use a clearly labeled explanation without a false spotlight. Do not mutate tasks, moods, photos, memberships, location sharing, or notification read state during the tour.

## 3. Layout and interaction polish

The tutorial card must fit inside safe areas on small and large phones with enlarged text. Prefer one compact illustration or preview per stop; avoid nesting multiple bordered panels inside the cream overlay. The Step/Skip header and Back/Next actions remain reachable and at least 48 logical pixels high. Keep reduced-motion behavior: no automatic preview cycling, and state demonstrations advance only from user input. When a real bottom sheet is shown during the no-space tour, do not stack a second tutorial modal on top of it.

## 4. Profile identity and account controls

### Center and extend the shared avatar

Fix `MemberAvatar` once, rather than compensating inside each `ChoiceChip`. Give the initials a fixed square layout with explicit center alignment and text height, preserving the UID-derived pastel color and consistent resolved-name initials. Check one and two letters, a long name, selected and unselected states, radius 12–28, and enlarged system text. The surrounding selection border must not shift the center. When an account has a photo, crop it to the same circular viewport with a stable fallback to centered initials during loading or on failure. Use the same avatar source in Today, Moments, Space, notifications, and map pins.

### Optional profile photo

Add an optional **Add a photo** action beside the name step in onboarding, without adding a required step or altering the six-part progress bar. Offer **Take photo**, **Choose from photos**, and **Skip for now**; ask camera permission only when Take photo is selected. Reuse the app's existing camera/picker and preview/crop behavior where appropriate. The user can review, replace, or remove a selected image before continuing. Keep the name and email flow usable if camera/photo access is denied or an upload fails.

The selection before authentication is a local draft preview. Upload only after Firebase identity and email verification are established; do not lose the chosen image merely because the verification screen opens. Store the final avatar as a private, account-scoped object and save an account avatar reference/revision, not a permanent public image URL. The existing shared-moment media path is space-scoped, so introduce or extend an authenticated avatar upload/read/delete route with account-owner writes and authorized member reads across shared spaces. Resize and strip embedded location metadata before upload. Account switching, sign-out, photo replacement/removal, and account deletion must clear local cache and old objects correctly. Personal Plus status or space ownership must not govern avatar availability.

Expose **Change photo** and **Remove photo** in `AccountSettingsSheet` with the same camera/gallery choices and a clear saved/pending/error state. Editing an avatar must not silently replace the user's name or space image. Keep initials as the default when a photo is skipped or removed. Test visibility between two members in a shared space and denial for an unrelated account.

### Card and field polish

In the Space account card, replace the `Account settings` text link with one settings-gear icon in the upper-right of the name/email card. Use a 48-pixel tap target, accessible label **Account settings**, and enough space for long names and the Basic/Plus pill. Keep Plus benefits/subscription details reachable. Remove the leading literal `·` from the **Basic** pill; retain its simple pastel badge. Plus can keep its existing symbol only if it remains visually balanced.

In `AccountSettingsSheet`, reduce the display-name field's excessive vertical space by using a compact, explicit input height and label spacing within the existing card. Preserve a readable text field and at least a 48-pixel touch area, visible focus, keyboard scrolling, and the current save behavior. Do not compress the email or destructive controls to achieve this.

## 5. Reminder sheet and private no-space map

Present `NotificationSettingsSheet` above the entire app dock, using the root navigator or an equivalent root-level sheet route. Limit sheet height to the available safe-area height and make its content scrollable, with bottom inset for keyboard and gesture navigation. Ensure the time-zone dropdown and **Save reminder settings** can be fully seen and tapped on short phones and with enlarged text. If opening it from account settings, avoid two visually overlapping sheets. Preserve the current disabled push explanation when push is not configured; this is a layout repair, not push activation.

Enable the top map button even when no space is selected. Support a null-space **private map** mode in `SpaceMapSheet` (or a shared map shell): load tiles, locate the device with the current permission/error handling, recenter, and switch Satellite/Streets when available. Do not subscribe to any space sessions, show other members, create sharing records, or offer an enabled Start sharing action in this mode. Display the user's requested explanation, **Join a space to use location sharing**, with a clear Create/Join route into the existing space selector. Opening the map or granting foreground location permission never starts sharing. Once a space is selected, preserve the existing 15/30/60-minute explicit sharing flow and membership checks. A no-space map must not retain markers or data from a previously selected space.

## Build order and acceptance

1. Extract/share the Today hero layout and switch the no-space branch to it. Visually compare with populated Today at 360 and 430 logical pixels, including safe-area and text-scale changes.
2. Inspect live app screenshots/components for every tour stop. Record each preview's real counterpart, then revise `TutorialExampleCard`, `TutorialStops`, and overlay targeting. Remove the invented selected `Home` row in the no-space branch first.
3. Implement the no-space short path and explicit continuation after first space entry, with UID-scoped first-use status. Keep the Create/Join sheet reachable and avoid competing overlays.
4. Verify that all stops point at visible controls, Back/Next/Skip work, manual replay remains available, and visiting Space does not auto-start a tour. Check that the empty Today hero starts at the screen top and that the selector/bell remain legible and tappable.
5. Run focused Flutter analysis and meaningful widget tests for the empty header geometry, no-space versus member tour branches, target availability, and one-time behavior. Inspect rendered screens and transitions; record any device checks that remain open.
6. Fix the shared avatar centering, add account-scoped profile photos in onboarding and account settings, and verify authorized visibility plus account-switch/deletion cleanup. Render small chips and larger account rows at normal and enlarged text scales.
7. Move the settings entry to the card's gear, remove the Basic dot, and compact the display-name field while retaining accessibility. Check the reminder sheet above the dock at small heights and with the keyboard open.
8. Exercise private no-space map mode with location granted, denied, services off, and map tiles unavailable. Confirm that sharing remains unavailable until membership exists, then test the existing explicit sharing path.

Preserve Firebase verification-link authentication, Today / Moments / Space navigation, personal Plus rules, and existing member data. Backend rules for private avatar access need separate review and deployment before cross-device profile photos can be called complete. No paid service or public publishing is part of this plan.
