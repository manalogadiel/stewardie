# Stewardie — Product Plan

Status: planning draft, updated September 22, 2026. User-selected name: Stewardie (formerly Kalinga). Commercial name clearance remains open.

Confirmed business direction: Basic (free) and personal Plus (paid). One subscription belongs to an account across its spaces; it does not upgrade other members. Basic includes today and the previous 3 days of completed tasks; Plus includes full retained authorized history. All unfinished/overdue tasks remain available in both tiers. The [subscription plan v1](stewardie-subscription-plan.md) is authoritative for approved pilot quotas, shared/account counting rules, and downgrade handling. Target pricing is US$3.99/month or US$34.99/year; final launch approval and the 5 GB cost check remain open.

This document updates the original family organizer concept for an online product. It records the features agreed in discussion; it does not claim they have been implemented. The original document describes a one-hour seeded demo, not the production scope below.

The [technical and launch plan](technical-launch-plan.md) contains proposed service choices, account/age distinctions, synchronization design, and rollout gates. Unconfirmed technical recommendations remain proposals.

September 23 implementation note: the user approved the [camera and Moments slice](ui-polish-camera-moments-plan.md) and [floating-header/mood follow-up](top-navigation-person-mood-plan.md). Optional completion photos, standalone photos, local persistence, a custom capture/preview flow, the TV viewer, person-aware mood/calendar cards and mood colors are implemented locally. This does not establish authentication or delivery to other members' devices. See [photo verification](ui-polish-media-verification.md) and [header/mood verification](floating-header-moods-verification.md).

A separate [Firebase-emulator online core](online-core-verification.md) now tests account-specific Basic/Plus, space membership, invitation codes, and shared task transitions. It has not yet been merged with the full local visual/photo UI or deployed to a live service.

## Product direction

A private shared space for people who do everyday life together: families, housemates, dormmates, friends, and small crews.

**Your people. Your plans. Your little moments.**

Members coordinate responsibilities, share how they are feeling, and attach small moments to their day. The product combines practical coordination with connection. Its differentiation must be validated through real use; individual features or their combination are not claimed to be exclusive.

Platform: Flutter mobile app, with online accounts and synchronization across devices. Preserve useful cached access during poor connectivity.

## Spaces and membership

- Create a space with a name, image, and type: Family, Housemates, Friends, Crew, or Custom. Dormmates can use Housemates with relevant starter examples.
- Types provide onboarding examples and routine templates, using the same underlying product.
- One account can belong to multiple independent spaces. Members switch between them without mixing private content.
- Use neutral member terminology. Optional family labels are descriptive, separate from permissions.
- Start with owner and member permissions. Owners manage invitations and membership; ordinary invitations grant member access only.
- Include explicit guardian controls if child accounts are supported; child account behavior needs definition before that audience launches.

### Join by code, link, or QR

All three entry methods resolve to the same invitation and joining flow. A QR contains the invitation link.

Flow: enter code / open link / scan QR → preview space name and image → sign in or create account → join or request approval.

- Only the space name and image are visible before membership is approved. Member details, tasks, moods, photos, and locations remain private.
- Owners can expire, revoke, or regenerate invitations.
- Owners can require approval for new members, particularly for broadly shared QR posters or codes.
- Codes must resist guessing through adequate randomness and rate limits. Revoking an invitation disables its code, link, and QR entry points.
- A pending request grants no content access. Removing a member revokes further server access to the space and its media.

## Shared day and responsibilities

### Timeline and scheduling

- Shared chronological view of tasks, events, appointments, and recurring routines.
- Members create and edit entries within their permissions.
- Filter by member; use names or avatars alongside color.
- Clearly separate the person responsible from event participants and the member who created a request.
- Daily overview emphasizes what needs attention, what is covered, and what is completed.

### Responsibility flow

Approved September 22 UI refinement: Today groups unfinished tasks in a Pending tab, with unclaimed/requested/help-needed work above accepted Covered work. A separate Done tab shows completion dates within the existing tier boundary. New tasks are unclaimed or requested, never implicitly accepted. Help / Covered / Done statistics describe these disjoint states for the current Today/person scope.

- Create an unclaimed task or request that a particular member handles it.
- The recipient accepts with “I've got it” or declines. A request alone is not acceptance.
- An accepted task can be completed or marked “Need help.”
- Another member can offer to take over. Confirm the handoff before changing the responsible person; keep the existing owner visible while help is pending.
- Prevent simultaneous claims from assigning multiple owners accidentally.
- Keep a short activity history for assignments, acceptance, handoffs, and completion.
- Completion takes one action; notes and photos are optional additions.

### Shared calendar — approved local slice

Members enter schedules inside Stewardie, scoped to one space. Everyone combines all authorized plans once; a person filter includes plans they author or explicitly participate in. Filters do not change the active identity. The implemented [person-aware card update](top-navigation-person-mood-plan.md) gives Everyone/Me your mood and another person's filter their current shared mood read-only. Calendar headings follow the same filter: Shared, Your, or the member's shortened name.

Plans have an author, title, start/end, all-day flag, optional note and participants. Members edit/remove their own plans; participants must belong to the space. Multi-day plans appear on every intersecting date. The month sheet opens on the current month, supports month navigation and a selected-day agenda, preserves that selection while filtering people, and resets on space change. Tasks and schedules have separate counts and models.

This approved implementation is in memory only. Timed values are UTC instants displayed in device time; all-day values are floating dates with an exclusive stored end. Named space time zones, external calendar sync, recurrence, durable storage and multi-device sharing remain future work. Calendar-specific online quotas must be settled before launch; this slice changes no subscription boundaries.

### Reminders and notifications (future online behavior)

- Reminders for relevant tasks and events.
- Notifications for responsibility requests, accepted handoffs, and meaningful changes.
- Per-space preferences and quiet hours. Do not notify every member about every action.
- Completion and acceptance must sync before other members are shown a confirmed remote update.

## Mood check-ins

- Optional daily check-in with a mood and optional short note.
- Local UI slice: the author chooses Sky, Butter or Rose independently of mood; the color is retained with that space's current check-in and changes the clay character and pale card tint. Other members may view, but never edit, that choice. The check-ins are local fixtures, not synchronized across devices.
- Display the member's current shared mood near their name, with a timestamp.
- Make the destination space and audience clear before posting. Do not copy moods across spaces automatically.
- Allow updating or removing a shared mood. Expire the current mood after the chosen daily window so old feelings are not presented as current.
- Offer a separate “Could use a hand” action; mood never automatically changes assignments or signals availability.
- No required check-ins, mood scoring, or rewards for particular feelings.
- Mood-history retention is a later decision; the initial scope needs only the current check-in.

## Photos, moments, and appreciation

- Attach an optional photo and note when completing or updating a task.
- Support small standalone shared moments, such as a meal or a finished project, in the relevant space.
- Provide a simple heart or thank-you reaction.
- Use warm actions such as “Add a photo” or “Add a moment.” Photo proof is contextual support, not guaranteed verification of task completion.
- Keep the default task completion flow short. Do not require photos for every task.
- Dedicated chat, leaderboards, and a separate social network feed are outside the current core scope.

### In-app camera and gallery

Capture flow: open task or compose moment → take photo → preview → optionally attach location and note → confirm audience → post.

- Build an in-app camera with preview, retake, and cancel.
- Request camera access when needed. Denying access does not block task completion.
- Support gallery uploads and distinguish them from in-app captures.
- Show upload progress, failure, and retry. A task may be complete while an optional photo is still uploading; show that accurately.
- Strip unintended embedded location metadata from shared copies. Share only location deliberately attached in the product.
- Store media privately with membership-controlled access. Allow removal of posted photos.

## Locations and maps

These are three independent features. Using one never silently activates another.

| Feature | Meaning | Example |
|---|---|---|
| Task or event location | Fixed destination for a responsibility or gathering | Pick up supplies at this shop |
| Photo location | Fixed, optional location attached to a particular photo | Supplies delivered here |
| Temporary live sharing | Time-limited updates from a member's device | Share with this crew for 15 minutes |

### Task and event locations

- Optional place name, address, map pin, and location note such as an entrance description.
- Show a map preview within entry details and a “Get directions” action that opens an external maps app.
- Provide an optional “I'm here” check-in. It is a member-reported update, not independently verified arrival.
- Do not build turn-by-turn navigation in the first product scope.

### Photos connected to a map

- Offer an explicit location toggle at capture. If enabled and permitted, capture coordinates and their timestamp near the shutter action, rather than collecting the eventual posting location.
- Show the proposed pin in the preview and allow removing it before sharing.
- Store capture time, location time, and available accuracy information separately. Avoid claiming a precise location when the device only provides an approximate result.
- A posted photo can show a place label and “View on map.” Its location stays fixed even when the author moves.
- Never label the uploader's current position as where an old gallery photo was taken.
- If gallery location or a manually selected place is supported, explicitly label the source. A manual place tag is not a verified capture location.
- If location is denied or unavailable, the photo can still be posted without a pin.
- Photos and pins are visible only within their authorized space. Location-tagged photos are useful context, not authenticity guarantees.

### Temporary live location sharing

Included in the agreed product scope, with implementation staged after the core synchronization and fixed-location flows.

- Start sharing intentionally, optionally linked to a task or event.
- Choose a duration in minutes; initial suggested presets are 15, 30, and 60 minutes.
- Explicitly identify the receiving space and members before starting. For the initial design, restrict a session to the recipient members present when sharing begins; newly joined members are not silently added.
- Show an active-sharing indicator, remaining time, and a prominent “Stop sharing” action.
- Stop automatically at expiry, including server-side expiry when the sender is offline.
- End access when the sender or recipient leaves or is removed from the space.
- Request location permissions at use time. Define any background-sharing behavior explicitly and communicate platform limitations.
- Show last-update time and stale or unavailable states. Never present cached coordinates as a current live position.
- Keep only the latest position needed for the active session; route history and long-term tracking are outside scope.
- Stop requests must immediately stop local collection. If connectivity prevents immediate server confirmation, show that pending status; server expiry still limits remote access.
- No permanent tracking, automatic activation from taking photos, or location-sharing requirements for completing a task.

## Online foundation

- Authentication, account recovery, and real space membership replace the demo's role dropdown as the access model.
- Server-enforced permissions on all space data, media, and location sessions.
- Cross-device updates for tasks, assignments, moods, reactions, and moments.
- Private object storage for photos with access checked against current membership.
- Local caching and queued edits with visible pending, synced, or failed states.
- Server-authoritative conflict handling for claims, handoffs, invitation use, and session expiry.
- Device and space time-zone handling; clearly defined time zones for recurring routines and events.
- Stop displaying or accessing expired live positions even if an old update remains cached.
- Account and space deletion behavior, membership removal, and media retention must be defined for release.
- Backend, maps provider, authentication methods, storage limits, and pricing remain implementation decisions. No vendor is selected by this plan.

## Suggested implementation sequence

All agreed features remain in the product scope. The phases below organize implementation rather than removing features.

### Phase 1: shared coordination and connection

Accounts, spaces, code/link/QR invitations, membership, shared timeline, live task creation, recurring routines, assignment acceptance and handoffs, completion, notifications, daily moods, optional photos, in-app camera, gallery uploads, moments, and simple reactions.

### Phase 2: fixed location context

Task/event locations, external directions, optional arrival check-in, capture-location photo pins, and embedded map details.

### Phase 3: temporary live sharing

Duration selection, explicit audience, live map updates, stop and expiry behavior, permissions, background behavior, and stale-state handling.

Pilot with families and housemates first while retaining flexible space templates for friends and crews. Validate participation by multiple members, successful handoffs, useful check-ins, and repeat use of photo moments before widening the feature set.

## Conceptual data changes from the original demo

| Record | Responsibility |
|---|---|
| Account | Identity across spaces |
| Space | Name, image, template, owner, defaults |
| Membership | Space-specific identity, role, color, status |
| Invitation | Token/code, expiry, revocation, approval policy |
| Timeline entry | Task/event, creator, schedule, recurrence, optional destination |
| Responsibility / handoff | Requested owner, accepted owner, help request, confirmed transfer |
| Mood check-in | Author, space, mood, note, visibility, timestamp, expiry |
| Moment / attachment | Author, space, optional task, media, note, capture/upload source |
| Photo location | Optional coordinates, accuracy, timestamp, location source |
| Reaction | Member, target moment or update, reaction type |
| Location session | Sender, recipients, optional event, start, expiry, stop, latest position time |

This is a planning model, not a finalized database schema.

## UI specification

The [UI and asset plan](ui-plan.md) now records the agreed Today / Moments / Space navigation, people filtering, screen behavior, Soft Pop visual direction, and production asset inventory. It supersedes the earlier exploratory UI notes below where decisions have since been made. The product plan remains the source of truth for feature behavior.

### Earlier discussion context

Preserve the requested minimal, cute mix of 2D and soft 3D, with the welcoming atmosphere of a close group. Expand family-only language and examples to include housemates, friends, and crews.

The earlier brand guide is a visual reference; its family-only positioning is superseded by this shared-space direction. Name, mascot, final navigation, and screen layouts remain open for the next discussion.

UI decisions to explore next:

- How Today balances responsibilities, moods, and small moments.
- Where the space switcher and invitations live.
- Whether Moments needs a tab or works within Today.
- How task details connect camera, photo pin, and temporary sharing.
- How active location sharing stays visible without dominating the app.
- How to make empty, offline, uploading, and pending-approval states understandable.

No UI layout or implementation is approved by this product-plan update.
