# Notification coverage — September 30, 2026

This inventory describes the current Firebase/Supabase pilot. FCM transports optional push; it does not schedule routines or govern access. Inbox writes are server-only. It is not a device-delivery certification.

| Operation | Implemented treatment |
|---|---|
| Assignment/reassignment | Live request, versioned event and worker activity for the recipient. |
| Accept/cover/handoff confirmation/completion | Atomic activity to the affected creator/participants; actor suppressed. |
| Decline/help offer/request | Validated task transition and event. Offers go to the owner; help requests go to current members. |
| Material title/note/place edit or cancellation | Atomic event; affected participants receive generic activity. Subtask toggles and autosave without material changes deliberately do not alert. |
| Task/plan arrival | Atomic event with the self-reported arrival record; relevant participants receive activity. No claim of GPS verification. |
| Plan create/edit/remove | Revision-bound atomic events for the author/old/new participants, restricted to current membership. |
| Due tasks/calendar reminders | Existing deterministic worker jobs; stale revision/action/deleted/membership checks cancel delivery. |
| Routine generation failure/cap | Private manager notice and automatic retry; assigned occurrences reuse ordinary task requests. |
| Pending join/approval/decline | Worker reads the durable request. Owner gets a request linking to Space; requester gets a generic private decision notice without restricted space content. Requests before this rollout are not backfilled. Decline status persists so it can be delivered. |
| Join/leave/removal | Existing immutable events; removed member gets only a private access-ended notice. |
| Ownership offer/acceptance/rename | Existing events; stale ownership offers do not push. |
| Space deletion/failed cleanup | Generic account notice survives removal of space history. Owner can tap a failure notice to request retry. Cron retries failed/expired leases. Successful retry updates the notice to complete. |
| New photos | Optional per-space setting, off by default. Worker uses ready, published Supabase records only; stable photo ID deduplicates activity. Tap opens Moments after checking current space access. |
| Photo reactions | Optional author setting, off by default; grouped into one notice per photo/local day, from current members. Removed/replaced reactions may disappear before the worker samples them; no claim of an exhaustive reaction log. |
| Moods | Optional inbox-only setting, off by default; one generic notice per member/local day. No note/mood content in notifications. Rapid changes are grouped and expired moods are skipped. |
| Live location | Persistent sender session indicator and OS service notification remain authoritative. No social start/stop alerts or GPS-sample notifications in this pilot. Opening a map does not share. |
| Upload/offline outbox failures | Private inline retry/pending state already present; no duplicate remote alert for a device-local failure. |
| Subscription | Verified server reconciliation and account/paywall status; no client-generated payment-success notification. Purchases stay gated. |
| Reports/account deletion | Private acknowledgements and existing operator queues; no disclosure to reported members or space-wide alert. |

Core activity remains enabled independently of push. Optional social switches are separate from the push master switch. Enabling optional activity starts from the saved preference timestamp, never floods the inbox with historical photos/moods. Push respects global/per-space settings and quiet hours, uses discreet text, and rechecks current membership and the photo/task/plan before sending. Foreground push presents a generic in-app snackbar with View; background notification taps open the protected inbox.

## Pilot limits and checks

- The five-minute worker samples durable state. Immediate task/ownership requests still come from Firestore. Join and social history may take one worker interval.
- The worker scans current pilot records; before wide enrollment replace broad scans with indexed cursors/durable delivery state, bounded concurrency and explicit backoff. This is a cost/scale release gate.
- Account-wide unread query includes generic account notices without space access. Space history is hidden after departure. Unresolved task/ownership cards remain actionable even after read.
- Completed task deep links use the authenticated space-local history gateway; direct Basic Firestore reads cannot bypass the four-date window. Photos and completion summaries are separate shared records, not a grant to expired task details.
- Verify real FCM HTTP v1 permission, two Android devices, deny/allow, foreground/background, sign-out/token rotation, quiet hours and taps. Also test join decline/approve, calendar edits/removal, repeated worker runs, photo opt-in and deleted-photo suppression. iOS APNs remains external setup.
- Focused local authorization suite: 18 passed. History/delivery policy tests: 9 passed. Changed Edge routes passed Deno checking. Changed Flutter areas passed analysis with info-level lints, no errors/warnings. No physical-device or purchase tests were run in this continuation.
