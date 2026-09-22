# Soft Pop redesign implementation

Implemented September 22, 2026 after approval of [the redesign plan](ui-redesign-plan.md). This record supersedes the initial [foundation review](demo-foundation.md) for the changed UI and current verification.

## What changed

- Warm near-white canvas, centered transparent space bar, bottom-rounded Today card, and four new transparent clay illustrations based on the approved trio.
- People strip followed by personal mood and calendar columns; larger text uses stacked cards. Help / Covered / Done labels sit below their totals.
- Sticky Pending / Done task tabs. Newly created tasks enter Pending, including Request me; acceptance moves responsibility to Covered. Help requests retain the owner until confirmed. Completed overdue work appears under its actual completion date.
- A floating glass-clay Today / Moments / Space dock with labels, safe-area spacing and an opaque accessibility/build fallback. No full-width navigation background or overlapping floating Add button.
- An activity-square month preview and expanded month sheet with day agenda, previous/next month and Today. Everyone combines current-space plans once; person views include authored and participating plans.
- Schedule creation, edit and removal, with title, dates, all-day/timed ranges, participants, optional note, audience and author checks. Timed instants store UTC; all-day values use floating dates and an exclusive end.
- Product copy without demo/AI/developer banners or simulation controls. Unavailable photo controls are omitted. Moments has an empty-state presentation; Space shows the current space's members.

The Flutter/Riverpod/go_router stack and personal Plus boundaries remain unchanged. Schedules do not contribute to task counts. Basic retains unfinished work and four completion dates. New code lives in `lib/features/calendar/`, reusable clay/person components, the shell and Today/task presentation. Artwork provenance and prompt summaries are in [the asset manifest](../assets/illustrations/README.md).

## Verification

Run with Flutter 3.47.4 / Dart 3.13.3 on Windows:

| Check | Result |
|---|---|
| Dart analysis of the Flutter project | No issues |
| Standard Flutter tests with `--dart-define=CAPTURE_DEMO=true` | 28 tests passed; normal test asset compilation used |
| `flutter build web` | Passed; output in ignored `build/web` |
| Widget render review | 360 × 780, 430 × 932, 360 × 800 at 200% text, and 780 × 360 landscape |
| Calendar/task behavior | Creation, acceptance, pending/failure/retry, completion, direct Done access, filtering, month navigation, author edit/remove and cancellation |
| Schedule model | Leap/non-leap February, 30/31-day months, year rollover, all-day exclusive ends, timed midnight crossing, deduplication, space/person scope, invalid intervals and author/member checks |
| Accessibility checks | Labeled controls and 48dp targets on Today and expanded calendar; selected dates expose a semantic tap action; theme/material contrast tests pass |
| Keyboard/safe areas | Mood and calendar editors exercised with simulated insets and enlarged text |

The earlier foundation run was blocked by `impellerc.exe` policy. Standard tests and a full web build succeeded during this redesign; no Windows security policy was changed. The web build reported a Cupertino font-family warning; no Cupertino icon package is used by the app. Native platform review remains outstanding.

These images are Flutter widget renders, not physical-device captures. TalkBack/VoiceOver sessions, native keyboard behavior, blur performance on devices, Android startup and iOS builds have not been verified. Reduced-motion state changes use no custom decorative animation; the dock has an opaque fallback for high-contrast/accessible-navigation settings and `--dart-define=REDUCE_TRANSPARENCY=true`.

## Reviewed screens

- [Today — small phone](redesign-review/today-small.png)
- [Today — large phone](redesign-review/today-large.png)
- [Month calendar](redesign-review/calendar.png)
- [Calendar — large text](redesign-review/calendar-large-text.png)
- [Plan editor and audience](redesign-review/calendar-editor.png)
- [Plan editor with simulated keyboard](redesign-review/calendar-keyboard.png)
- [Done tab](redesign-review/tasks-done.png)
- [Today — large text](redesign-review/today-large-text.png)
- [Moments](redesign-review/moments.png)
- [Space members](redesign-review/space.png)

Generate fresh review images with `flutter test --dart-define=CAPTURE_DEMO=true`; full output goes to ignored `build/review/`. Selected images above are retained in the repository.

## Local scope

All members, tasks and schedules remain local fixtures and in-memory writes. Jamie is the fixed current identity; data resets on restart. Author checks demonstrate application behavior and are not production authentication or server authorization. There is no external calendar connection, recurrence, durable storage, online synchronization, media upload, payments or notification service. Production time-zone and calendar quota decisions remain open. No paid services, cloud resources or publication were enabled.
