# Soft Pop UI redesign — implementation proposal

Status: awaiting user approval to implement. Planning only; no application code or production assets changed for this proposal.

This records the user's redesign request after the first Flutter UI slice. The requested visual changes below supersede the older appearance where they differ. Detailed behavior and token values marked proposed are for review. Implementation starts only after the user says to proceed.

## 1. Requested direction

- Bring the approved sky-blue, butter-yellow, and soft-pink mascots into the interface. Combine readable 2D controls with soft 3D clay artwork and restrained pop accents.
- Move the background closer to white without using a stark pure-white canvas.
- Remove visible local-demo banners, AI/development explanations, and testing controls from the normal product screens.
- Center the space name/selector and remove the solid navigation backgrounds.
- Put Today information inside a card with square top corners and rounded bottom corners.
- Keep Everyone / Me / member filters immediately below that card.
- Follow with two columns: mood on the left, calendar on the right.
- Use GitHub-like activity squares in the compact calendar. Open a clay-pop month calendar on tap, showing one month at a time with month navigation.
- Everyone sees the space's combined schedules; selecting a person shows that person's plans.
- Show three statistics with numbers above the labels: Help / Covered / Done.
- Put newly created pending tasks first and covered tasks below.
- Provide browser-inspired Pending / Done task tabs so completed work has a direct destination.
- Replace the flat bottom navigation with a floating rounded glass-and-clay dock, inspired by the attached reference without copying its exact appearance.

Keep Flutter, Riverpod, go_router, Nunito Sans, the existing responsibility rules, and Today / Moments / Space destinations. No paid services or backend provisioning are part of this redesign.

## 2. Proposed screen composition

```text
                  Home crew ⌄             Inbox
            Transparent top navigation area

  ┌────────────────────────────────────────────┐
  │ Today                         Clay trio    │
  │ Tuesday, September 22         illustration │
  ╰────────────────────────────────────────────╯

  [✓ Everyone] [Me] [Alex] [Sam] [Jo] →

  ╭──────────────────╮  ╭──────────────────────╮
  │ Your mood        │  │ September       ↗   │
  │ Clay companion   │  │ ▫ ▪ ▫ ▫ ▪ ▫ ▫      │
  │ How are you?     │  │ ▪ ▫ ▫ ▪ ▪ ▫ ▫      │
  │ Check in         │  │ Monthly plan grid  │
  ╰──────────────────╯  ╰──────────────────────╯

           3               4              2
          Help           Covered         Done

  ╭ Pending (7) ╮╭ Done (2) ╮        + Add task
  │ Pending tab connected to the task surface │
  │                                           │
  │ Pending                                   │
  │ New / awaiting acceptance / needs help     │
  │                                           │
  │ Covered                                   │
  │ Accepted responsibilities                 │
  ╰───────────────────────────────────────────╯

          ( Today   Moments   Space )
            Floating glass-clay dock
```

The wireframe describes hierarchy, not final artwork, exact sizing, or fixed content counts. The Today header uses a rectangular top edge and approximately 28px bottom corner radii. Other cards remain fully rounded. Keep the header compact enough that the task area remains discoverable on a small phone.

The top selector is centered against the screen, not just the space left over beside Inbox. Reserve equal side widths. Long names can wrap within a bounded title area; the selector sheet shows the full name. The page canvas continues behind the transparent top bar.

## 3. Appearance and mascots

Proposed token changes, to be consolidated in `docs/ui-plan.md` and `lib/core/theme.dart` after approval:

| Element | Proposal |
|---|---|
| Canvas | `#FAF9F6`, a very light warm off-white |
| Cards | `#FFFEFB`, with a slightly warmer Today header for separation |
| Accent | Preserve electric blue `#244BFF` |
| Text | Preserve charcoal `#202633` and secondary `#596171` |
| Character palette | Preserve sky `#A9CDE8`, butter `#F5D76E`, rose `#EAB8C5` |
| Clay depth | Diffuse upper-left light, short soft contact shadows, rounded silhouettes |
| Glass | Milky translucency, subtle light rim and limited blur, with a solid fallback |

The pastel trio should be recognizable from the approved character reference. Produce separate transparent assets; never crop the reference board into UI elements or bake labels into artwork.

First asset pass after approval:

1. Compact greeting trio for the Today header.
2. A quiet check-in companion for the mood card.
3. A small calendar companion for the expanded month view.
4. A gentle celebration pose for an empty Pending state or completed work.

Use scalable labeled faces for the six mood choices, harmonized with the mascot expressions. Keep functional icons native/vector. Restrict halftone and sparkle accents to empty decorative areas, and avoid repetitive animation. No emotion ranking or reward for choosing a positive mood.

## 4. Clean product presentation

Remove `DemoNotice` from screens, demo suffixes from titles/space labels/history, explanatory technical paragraphs, and the visible simulation dropdown in Space. Remove any AI/process language found during the copy audit.

Keep simulation controls in tests or an explicit development-only configuration. Keep environment and verification information in repository documentation, outside the normal interface. This preview continues using local repositories until online work is separately approved.

Retain useful state messages in ordinary product language: Saving…, Could not save. Try again., Awaiting acceptance, and Handoff pending. A pending responsibility change must not appear remotely confirmed. Do not invent online members, successful uploads, or synchronization receipts. Omit unavailable action controls from this review surface rather than route them to implementation-explanation dialogs.

## 5. Mood and calendar row

At ordinary text sizes use two balanced columns with a 12px gap. The left card contains the user's current mood or a check-in invitation plus a small clay companion. The right card contains the month label, compact grid, scope label, and open-calendar affordance.

Proposed mood behavior: it remains **Your mood** when a different person is selected. Person filtering changes tasks and the calendar, not who can post a check-in. The existing composer keeps optional notes, visible space audience, skip, update, removal, and expiry.

On narrow layouts or enlarged text, stack the cards in the same order rather than shrink text or create tiny hit areas. Both cards should have a coherent visual height at normal scale without constraining larger text.

### Compact calendar

- One square represents one date in the displayed month, arranged as a seven-column month grid with blank leading/trailing cells. Borrow the density treatment from a GitHub activity grid, not the year-long layout.
- Start on the current month. Use pale-to-blue fills for 0, 1, 2, and 3+ visible plans. Today receives a separate outline. This represents scheduled activity, not streaks, achievement, or mood scores.
- Show the scope in text: Everyone's plans or Alex's plans. The fill count recalculates immediately when the person filter changes.
- Treat the compact grid/card as one comfortably sized button; its tiny cells are not individual touch targets. Its semantic label describes month, scope, and plan count.

### Expanded calendar

- Open a large root-level sheet, or a full-screen presentation where space is limited, above the dock.
- Show only one month at a time with previous/next controls and a Today shortcut. Navigating months changes the viewed month, not the date of the user's schedules.
- Provide readable day numbers, clay-pop selected-day treatment, count/dot indicators, and a selected-day agenda below. For large text, use a scrollable date/agenda alternative to preserve touch sizes.
- Calendar opens on the current month initially; preserve the viewed month and selected day while filtering people within the current space. Reset to the current month when switching spaces.
- Everyone combines authorized plans in this space, deduplicating shared entries. A person's view includes plans they own or explicitly participate in.
- Keep the person filter accessible inside the expanded calendar, synchronized with Today.
- The calendar's selected day controls its agenda. It does not silently replace the task list's Today scope in this first redesign.

### Add and edit a plan

Proposed interpretation of “their own calendar”: people enter their schedules inside Stewardie and share them with the selected space. External Google/Apple calendar connections are outside this implementation.

Tap Add plan, enter a title, date, all-day or start/end time, optional note and participants, review the space audience, then save. Require a title and a valid date/time range. Members can edit/remove their own plans; another person's filter does not authorize posting as that person. In that view, label the action Add my plan and retain the real author.

Represent schedules as a dedicated model/repository rather than forcing them into task responsibility statuses. Include ID, space, author/owner, participants, title, start/end or all-day date range, optional note, and explicit time-zone handling. Shared events appear once in Everyone and under each participant. Multi-day plans appear on each intersecting date. Recurrence and external imports can follow later.

Schedules and task counts remain separate. The first calendar revision shows schedule entries; task creation does not silently create a duplicate calendar entry. The initial implementation remains local; multi-device sharing depends on the separately approved online foundation.

## 6. Task statistics, tabs, and ordering

Proposed definitions make the three totals disjoint for the same space/person/Today scope:

| Label | Meaning |
|---|---|
| Help | Unclaimed tasks, requests awaiting acceptance, and accepted tasks needing help/handoff confirmation |
| Covered | Accepted tasks with no outstanding help request |
| Done | Tasks completed today, based on completion date |

Render a large number above each label in three evenly spaced columns. Icons/shapes may support the labels; color is not the only distinction. Schedules never contribute to task totals.

Use two browser-inspired tabs attached to one task panel: **Pending** and **Done**, with counts. These are task tabs, not additional bottom navigation destinations. Make their row sticky while scrolling the task section so Done remains reachable without crossing the entire Pending list. Remember a separate scroll position for each tab within a space/person scope.

The Pending tab contains all unfinished work in scope, in two sections:

1. **Pending:** newly created/unclaimed tasks, requests awaiting acceptance, and tasks needing help. Show explicit status and current owner where applicable; new items appear near the top, with overdue items clearly flagged.
2. **Covered:** accepted tasks, ordered by time, followed by Anytime.

To match the request that new tasks enter Pending, creation saves an unclaimed task or a request; the current immediate self-accept checkbox becomes an optional Request me assignment. Acceptance is a separate explicit action that moves the task to Covered. This is a proposed change to the existing creation flow.

An offered handoff remains Pending and retains the original responsible person until confirmed. Task state and write state are separate: call in-flight storage work Saving… rather than confusing it with the Pending task category.

Done displays completed cards directly, replacing the long trailing expansion section. Today is the default completion-date scope; optional recent-date controls stay within Basic's today-plus-three-days history window. Preserve all unfinished and overdue work for Basic. No subscription changes, upgrade prompts, or automatic deletions are introduced.

Place Add task beside the task tabs when space permits, wrapping below them at large text sizes. Remove the overlapping floating action button from Today so it does not compete with the new dock or cover cards.

## 7. Floating bottom dock

Use the attached reference for the floating capsule, inset round selection, translucent material, and compact grouping. Retain Stewardie's light surfaces, electric blue, pastel clay warmth, and three labeled destinations; do not copy the dark green color or four-icon arrangement.

- No full-width opaque strip behind the dock; the canvas continues around it.
- Rounded capsule with a soft rim, subtle shadow, and restrained background blur.
- Selected destination uses a softly raised clay pill/disc with icon and visible label. Inactive labels remain readable.
- Keep each target at least 48 logical pixels, respect the bottom safe area, and pad scroll content so the last card can move fully above the dock.
- Sheet/modal content always sits above the dock. Hide/reposition the dock for full-screen editors and keyboards.
- Provide a sufficiently opaque, non-blurred fallback for reduced transparency or renderer limitations. Reduced motion uses an immediate selection change.

## 8. Implementation order after approval

1. Update the governing UI specification with approved tokens, structure, and behavior; preserve product/subscription boundaries.
2. Produce and review the mascot asset pass against the existing trio; document source, crop, intended sizes, and accessibility role.
3. Refactor the shell: centered transparent top bar, clean copy, floating dock, root-level sheets, safe-area spacing.
4. Build Today components: bottom-rounded header, person strip, mood/calendar row, vertical statistics, task tabs, Pending/Covered sections, and relocated Add action.
5. Add the schedule model, local repository, shared filter state, compact activity calendar, month sheet/agenda, and plan composer/edit/remove flow.
6. Apply the same materials and clean copy to details, mood composer, Moments, and Space so the redesign feels consistent.
7. Run behavioral, visual, accessibility, and platform checks; review screenshots before calling the redesign complete.

Likely code areas: `lib/app.dart`, `lib/core/theme.dart`, shared widgets and state, timeline presentation and creation, mood presentation, and a new `lib/features/calendar/` domain/data/presentation area. Refactor the existing large Today widget into focused reusable components. Reuse repository injection and routing; evaluate new packages only if native Flutter is insufficient.

## 9. Acceptance checks

- No demo/AI/developer instructions in the normal product UI; documentation continues to state real implementation limits.
- The exact approved mascot family appears with clean transparency, no stretched art, no baked-in labels, and no text overlap.
- Centered long space names, transparent bar surroundings, square header top corners, rounded header bottom corners, and a safe floating dock are visible in captures.
- Person selection filters both tasks and schedule counts/agenda without changing identity or leaking another space's data.
- Calendar covers 28/29/30/31-day months, year boundaries, empty days, multi-day entries, shared-entry deduplication, all-day plans, invalid times, and scoped editing.
- New task → Pending; accept → Covered; Need help → Pending with owner preserved; confirm handoff → Covered; complete → Done. Failure leaves the previous state intact.
- Done is directly reachable, task tab counts remain correct, old unfinished work stays visible, and overdue work completed today appears under today's Done.
- Mood skip/update/remove/expiry behavior remains intact. Filtering another person never changes the check-in author.
- Check 360px and 430px phones, large text, landscape, keyboard, safe areas, touch targets, labels, actual material contrast, and reduced motion/transparency.
- Run analysis, relevant existing/regression tests, and a clean build when the machine permits it. The existing Windows shader-compiler restriction and missing Android device remain verification limitations, not reasons to claim platform readiness.

## 10. Proposed defaults for approval

The plan can proceed as written if approved. The main interpretations to review are: built-in schedules rather than external calendar sync; the mood card always showing the current user's check-in; Help including all tasks needing attention; Pending containing Pending and Covered sections; and new tasks requiring a separate acceptance step before moving to Covered.

No implementation, image generation, cloud configuration, purchase setup, or publication is authorized until the user gives the next instruction.
