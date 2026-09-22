# Floating top controls, person labels and mood colors

Status: requested planning update, September 23, 2026. The user confirmed the floating-header correction and requested person-aware calendar/mood cards, shortened names, a more distinct Today card and a mood color selector. This document records the next implementation scope; application changes in this follow-up have not started. Preserve the existing Flutter stack and no-paid-services constraint.

This supersedes the header interpretation and always-personal mood card in the earlier [UI/photo plan](ui-polish-camera-moments-plan.md). That earlier slice remains implemented as documented in [verification](ui-polish-media-verification.md); it did not achieve the requested full content-under-header effect.

## 1. Truly floating top navigation

Observed cause: `AppShell` uses a transparent AppBar but still reserves a 72px toolbar above its body. Transparency reveals the scaffold canvas, so the header continues to look like a full-width rectangle.

Replace that reserved toolbar with floating controls over the page body, using a Stack and a positioned SafeArea control row. Keep the selector geometrically centered with balanced side space and the Inbox circle on the right. The overlay itself has no fill, blur, border, gradient, elevation or full-width shadow. Only the capsule and circle have their own cream surfaces and restrained shadows.

The body paints from the top of the screen. On Today, extend the Today card's colored surface behind the controls and into the available top backdrop. Put safe-area/control clearance **inside the card's content padding**, so the title, date and mascots start below the controls without reintroducing a blank rectangular strip. Retain square upper corners and rounded lower corners. On Moments and Space, similarly inset the initial page content within its scrollable body, rather than placing a separate opaque header above it.

The controls stay fixed while page content scrolls behind them. Transparent gaps pass scroll gestures through to the page; only the actual buttons intercept taps. Preserve notch clearance, status-icon readability, at least 48px touch targets, long space names and Inbox access. The reference's purple frame is not a requested app color.

## 2. Calendar labels and short names

The calendar title currently says `Your calendar` for every filter. Derive the title and supporting scope copy from the same active space/person state that already filters the schedules:

| Filter | Calendar title | Plans shown |
|---|---|---|
| Everyone | Shared calendar | All authorized plans in the current space, deduplicated |
| Me | Your calendar | Your authored/participating plans |
| Another member | Alex’s calendar | That member's authored/participating plans |

Use a shared short-display-name helper for compact calendar and mood headings: prefer an explicit preferred/given name when available; for the current fixtures use the first non-empty word of the display name. Preserve the original full display name in the data, accessible label and expanded view. Do not treat the first-word fallback as a legal-name parser.

Constrain the name segment and use Flutter's measured ellipsis overflow when the first name is still too wide; do not truncate by arbitrary character count. Keep “calendar” or “mood” readable, placing it on a second line when needed. The name itself stays on one line with an ellipsis. Apply bounded name handling to compact scope subtitles and member chips as well; expose full names through semantics and a tooltip/expanded view. Keep equal-height card measurement and enlarged-text stacking.

Examples: `Jo María Santos` becomes `Jo’s calendar`; a long first name becomes a width-dependent `Alexand…’s calendar`. The exact cut point depends on text size and available space. Everyone never displays “Your calendar.”

## 3. More distinct Today card

Proposed token: **light butter `#F8E7B0`**, against the existing off-white canvas `#FAF9F6`. This stays in the approved blue/yellow/pink clay palette, makes the greeting region visibly separate from the canvas, and gives the floating cream controls a colored backdrop. Retain charcoal text and electric-blue actions.

Apply it to the Today greeting card and its continuous area behind the top controls, not to the whole page. Keep mood/calendar cards distinct. Check actual text/control contrast and the yellow companion's silhouette in rendered screenshots before finalizing the token. This exact hex is a proposed visual choice, not a claim of rendered approval.

## 4. Mood follows the selected person

| Filter | Mood card | Interaction |
|---|---|---|
| Everyone | Your current mood | Check in / Update mood |
| Me | Your current mood | Check in / Update mood |
| Another member | Alex’s current shared mood | View shared details; no edit/remove/color controls |

Resolve the mood subject as `selectedPersonId ?? currentUserId`, scoped to the current space. Selecting a member changes the displayed subject, never the signed-in identity or write permissions. Show the subject's mood label, selected color and current shared timestamp/note in the details view. Use the same compact-name policy as the calendar.

If another person has not checked in, or their check-in has expired, show “No check-in yet” without guessing a mood or falling back to the current user's character. Use a neutral placeholder with explicit text. Do not show “How are you?”, “Check in” or “Update mood” on another member's card. A space switch must clear stale subject data immediately. Local fixtures must remain documented as fixtures, not live updates from other people.

## 5. Mood color selector

The selector itself is requested. Proposed interpretation: choose the **clay character color**, accompanied by a matching pale mood-card tint. Offer three named swatches from the existing family: Sky, Butter and Rose. Sky is the default for check-ins without a stored color. Keep mood/expression and color as independent choices; any of the six moods can use any color. No good/bad color ranking and no automatic availability or task-state changes.

Place “Choose your color” below the mood choices in the current user's composer, with a live preview. Swatches have readable names, a distinct selection outline/indicator and screen-reader selected state. Labels and facial poses continue to communicate mood without relying on color.

Store a stable color identifier with the space-scoped check-in, rather than changing the account/avatar or global theme. Reopening Update restores it; changing the mood keeps the draft's selected color; cancelling discards draft edits; sharing updates mood, note and color together. Removing/expiry clears the current check-in, with Sky as the next draft default. Other members see the shared color but cannot change it. Retain the current documented local storage scope for moods; cloud synchronization is not part of this change.

The existing six mood poses are blue raster illustrations. Prepare consistent Butter and Rose versions of all six poses during the approved implementation/artwork phase, using the approved shapes, lighting and transparent framing. Reuse a suitable existing pose only after visual inspection. Avoid a flat color overlay that loses the clay shading or tints the face. No new artwork is generated during this planning update.

## Implementation order and acceptance checks

1. Refactor the shell overlay and page insets; apply the proposed Today surface token. Verify the card actually paints behind both buttons at rest and page content passes behind them while scrolling. Confirm gestures work between buttons.
2. Introduce shared compact-name formatting and person-aware calendar titles/subtitles. Preserve existing calendar filtering/month state and arrow touch targets.
3. Resolve the mood subject from the filter and add a read-only shared-mood view with absent/expired states. Verify viewing another person never opens the current user's composer or permits writing their check-in.
4. Extend the check-in model/composer with a color identifier, prepare matching assets, and connect draft/save/cancel/remove behavior.
5. Review 360px and 430px widths, landscape, status/notch insets, long space/member names, 200% text, and a scrolled state on all three destinations. Compare Everyone/Me/Alex labels, moods and colors directly. Verify missing/expired moods, cross-space isolation, unchanged task/calendar filtering, keyboard layout, contrast and accessible labels. Run Flutter analysis and focused/regression tests; document actual platform verification.

Primary files: `lib/app.dart`, `lib/core/theme.dart`, shared name/card helpers, `lib/features/calendar/calendar_view.dart`, `lib/features/timeline/presentation/today_screen.dart`, check-in models/repository, `lib/features/moods/mood_sheet.dart`, mood assets and relevant tests. Preserve existing implementation and user changes.
