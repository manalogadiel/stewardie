# Stewardie — Technical and Launch Plan

Updated: September 21, 2026  
Status: proposed implementation decisions for discussion. No cloud services, billing, accounts, or application code were created by this plan.

Related: [Product plan](shared-spaces-product-plan.md) and [UI plan](ui-plan.md).

## 1. Actual starting point

The repository at `C:/Users/Diel/Documents/GitHub/kalinga/` currently contains `kalinga.md` and `kalinga-pitch.md`, plus Git metadata. No Flutter scaffold, Dart source, or `pubspec.yaml` was found during this inspection.

Treat the older document's descriptions of built demo features as historical planning claims, not verified code. Start by scaffolding the app while preserving existing documents and Git history.

## 2. Recommended decisions and open choices

| Area | Recommendation | Status |
|---|---|---|
| Client | Flutter, feature-based structure, reusable Soft Pop components | Existing direction |
| Initial development | Android on the current Windows environment; keep iOS in scope | Proposed |
| State and routing | Riverpod and go_router, with dependency versions verified at scaffolding | Proposed implementation choice |
| Backend | Firebase Auth, Firestore, Cloud Storage, Functions, FCM | Proposed |
| Offline model | Cached reads and explicit pending operations; server-confirmed ownership changes | Proposed |
| Adult login | Verified email/password plus password reset for the pilot; social sign-in can follow | Proposed |
| Child login | Guardian-managed sign-in versus adult-managed profiles | Awaiting user decision |
| Maps | Mapbox Flutter SDK for embedded maps; external app for directions | Proposed, subject to pilot geography/cost check |
| Invitations | Own HTTPS domain, platform app links, QR and code fallback | Proposed |
| Live location | 15/30/60-minute opt-in sessions, initially one active session per account | Proposed limit |
| First audience | Small invitation-only pilot with families and housemates | Proposed |
| Budget | Low-usage design; monthly ceiling not yet provided | Awaiting user decision |
| Monetization | Basic and personal Plus; account entitlement across spaces, not a space-wide upgrade | Subscription v1 and pilot quotas approved; target pricing/cost validation pending |
| Name and markets | Stewardie selected; commercial naming checks and initial countries still needed | Name selected; clearance open |

These recommendations do not override accepted product behavior. Approval of this plan is not approval to enable paid services or publish the app.

## 3. Backend reasoning

Firebase is the recommended default because native Firestore clients support cached reads, local writes, and resynchronization. That matches the shared timeline and unreliable-connection requirement. This is an engineering recommendation, not a claim that Firebase is always cheapest or automatically resolves business conflicts. Firestore's ordinary document conflict behavior is last-write-wins. [Firestore offline documentation](https://firebase.google.com/docs/firestore/manage-data/enable-offline)

Supabase is a reasonable alternative if SQL, relational reporting, and Postgres ownership are the priority. It has an official Flutter client. For this project's offline behavior, explicitly budget a local queue/sync design or an integration such as PowerSync rather than treating realtime subscriptions as a complete offline solution. [Supabase Flutter](https://supabase.com/docs/guides/getting-started/quickstarts/flutter), [PowerSync integration](https://supabase.com/partners/integrations/powersync)

Choose one main backend. Do not combine Firebase and Supabase databases in the first build without a demonstrated need.

### Service responsibilities

| Service | Responsibility |
|---|---|
| Firebase Authentication | Identity, sign-in, session recovery |
| Firestore | Spaces, memberships, tasks, moods, moments metadata, current location sessions |
| Cloud Storage | Private processed photos and thumbnails |
| Cloud Functions | Authorized joins, task claims/handoffs, privileged membership changes, scheduled work |
| FCM | Push delivery for relevant updates; device tokens are private |
| Small HTTPS web endpoint | Invitation landing page and app association files |
| Mapbox | Maps and markers; place-search service evaluated separately |

## 4. People, family roles, and permissions

Keep three separate concepts:

1. **Account age status:** account-level classification and any guardian relationship. Do not infer it from the selected space type.
2. **Family label:** Parent, Child, Grandparent, Guardian, Relative, or a custom label, offered in Family spaces. A label is not proof of age or guardianship.
3. **Space permissions:** owner/admin/member capabilities. Other space types use these neutral labels.

A young person in a Friends or Crew space remains a young person. Switching categories cannot remove account protections or grant adult authority. A college dormmate is not assumed to be a child. A grandparent label does not imply administrative control.

### Child-account decision

Two release paths remain open:

- **Adult-managed profile:** a dependent is represented in a Family space without credentials or an independent session. An adult can assign/record routines on their behalf. Display “Recorded by [adult]” where attribution matters. Do not fabricate a self-reported mood.
- **Guardian-managed child sign-in:** a separate authenticated identity linked to a guardian. Define eligibility, enrollment/consent, recovery, allowed spaces, sharing controls, and age transitions before enabling it publicly. Do not simulate this by sharing an adult login or by an unrestricted role-switch dropdown.

Recommended scope if child sign-in is chosen: introduce it in Family spaces first. Invitations to other categories must enforce the approved account/guardian policy server-side. Exact age thresholds and country-specific treatment need a documented release policy once target countries are selected; a Family dropdown is not an age-control system.

Guardianship and space administration are different relationships. Space owners must not automatically acquire guardian powers over all young members.

## 5. Authentication and invitations

Start adult pilot login with email/password, email verification, and recovery. Use the platform password manager where supported. Avoid SMS login as a default until cost and phone-number needs are established.

If adding social login for public release, plan provider linking and review Apple's login-services requirements before selecting the iOS options. [Apple App Review Guidelines, section 4.8](https://developer.apple.com/app-store/review/guidelines/)

Invitation design:

- Backend creates an invitation with a high-entropy link token, short unambiguous code, expiry, usage limit, revocation state, and approval policy.
- Store token/code verifiers server-side; rate-limit lookup and redemption. Avoid logging raw invitations.
- QR encodes the same HTTPS invite URL. Code entry resolves the same invitation.
- Valid preview exposes only the intended space name/image, not private membership or content.
- Redemption is authenticated and atomic; an approval-required request is not membership.
- Default proposed expiry: seven days, with owner revocation/regeneration at any time.
- Installed app opens through Android App Links / iOS Universal Links. Without the app, a landing page offers the store route and a copyable code. After installation, re-open the link or enter the code; do not promise automatic post-install invite recovery without implementing it.

Do not use Firebase Dynamic Links: its documented shutdown was August 25, 2025. [Firebase notice](https://firebase.google.com/support/dynamic-links-faq) Use verified platform links; Flutter documents the Android association flow. [Flutter App Links](https://docs.flutter.dev/cookbook/navigation/set-up-app-links)

## 6. Data and synchronization

Use feature repositories so initial mock data can be replaced by real services without changing screen contracts. Keep a single source for theme tokens and shared controls.

Suggested feature areas: accounts, spaces, invitations, timeline, responsibility, moods, moments, media, maps, live sharing, notifications, settings.

### Proposed records

| Record | Key design point |
|---|---|
| Account | Private auth-linked details and age-policy state |
| Membership | Space-specific public profile and permission role |
| Dependent profile | Optional non-login identity, with attribution of managing adult |
| Guardian relationship | Separate, verified relationship if child access is supported |
| Task/event | Space, creator, requested/accepted owner, participants, schedule, version |
| Task operation | Idempotency ID, actor, intended transition, expected version |
| Mood | Author, space, text/state, shared time, expiry |
| Moment | Author, space, optional task, attachment state, caption |
| Media | Private object key, dimensions, size, source, optional explicit location |
| Invitation | Protected redemption data and minimal preview |
| Location session | Sender, fixed recipient set, start/expiry, stopped state, latest point |
| Notification job | Event/version, recipients, delivery state, deduplication key |

Use UTC timestamps for instants and a named time zone for recurring schedules. Decide daylight-saving behavior for local-time routines and test it.

### Offline behavior

- Read cached timelines with a clear last-synced indication where freshness matters.
- Allow drafts and queue local intent for suitable edits; distinguish pending from server-confirmed results.
- Task claims, handoffs, membership changes, and invitation acceptance require server validation. Transactions must resolve simultaneous attempts; cached optimism cannot confirm an exclusive claim. Firestore client transactions fail offline. [Transaction documentation](https://firebase.google.com/docs/firestore/manage-data/transactions)
- Use an operation ID and expected version for retries. A queued completion after a handoff must be reconciled, not silently overwrite the current owner's state.
- Avoid an unbounded extra sync engine: start with Firestore caching plus a small durable outbox for operations requiring explicit server acknowledgment and photo uploads.
- On logout, account switch, or known membership revocation, clear scoped in-app content and caches as appropriate. Revocation cannot erase screenshots or information already seen, and an offline device may not receive a removal instantly; do not promise otherwise.

### Recurring routines

Store a recurrence template with its time zone. Generate a bounded rolling window of task instances with deterministic IDs. Template edits define whether they affect future uncompleted instances; past completions remain historical records. Reminder jobs reference the instance/version to avoid notifying for deleted or rescheduled work.

## 7. Photos and storage

Provide in-app capture and gallery selection. Compress to a practical display size, produce thumbnails, validate actual file type and dimensions, and remove embedded location metadata from shared copies. Preserve only the location explicitly added by the user.

Proposed pilot limits: one photo per moment/completion, processed upload at most 2 MB, no video, and quota limits enforced server-side. These limits are cost-control assumptions to tune with pilot use.

Use private storage and current-membership checks for upload/download. Avoid permanent shareable download-token URLs for private media. If short-lived signed URLs are used, document their residual validity until expiry after removal; prefer an authenticated access path where immediate server-side revocation matters.

Suggested lifecycle: reserve attachment ID → upload to a restricted temporary path → validate/process → publish metadata → cleanup abandoned objects. Retries must not duplicate moments. Photo failure does not roll back an already confirmed task completion.

Cloud Storage for Firebase now requires the Blaze billing plan. Small usage may fall within allowances, but this architecture is not a guaranteed card-free or zero-cost deployment. [Storage billing requirements](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024)

## 8. Notifications

- Push for direct requests, accepted handoffs, changed responsibilities, and selected reminders.
- Use scheduled server work for shared reminders; optional local reminders must be deduplicated/cancelled when the event changes.
- Send to current authorized members only. Membership and task changes invalidate obsolete notification jobs.
- Keep lock-screen copy discreet; retrieve full task details after authenticated opening.
- Provide per-space controls, quiet hours, and in-app activity when notifications are denied.
- Notifications are best-effort, not an emergency or medication-adherence guarantee. FCM behavior depends on permissions and application state, including force-stop restrictions. [FCM Flutter delivery behavior](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)

## 9. Maps and temporary sharing

Mapbox is the proposed embedded map provider because it has a supported Flutter SDK for iOS/Android. Test address/place coverage in pilot countries. Begin with pin placement and optional typed address; evaluate search/geocoding pricing separately. Open turn-by-turn directions in an external app. [Flutter SDK](https://docs.mapbox.com/flutter/maps/guides/)

Mapbox's mobile-map pricing is based on monthly active map users; search and other services require their own pricing review. Do not assume all map services are included in one free allowance. [Pricing guide](https://docs.mapbox.com/flutter/maps/guides/pricing/)

### Fixed locations

Task location is a destination. Photo location is an optional fixed capture-time point with timestamp/accuracy/source. Do not attach upload-time GPS to an older gallery photo as its capture location. Denied permissions do not block photos or task completion.

### Live sessions

- Server creates a 15/30/60-minute session with an immutable expiry ceiling and a snapshot of authorized recipients. New members are not silently included.
- Proposed first-release constraint: one active session per account. Starting a new one explicitly ends the old one.
- Accept updates only from the sender's authorized active session. Use server time for access decisions and reject stale replay/out-of-order updates.
- Start with an adaptive movement/time threshold, approximately 15–30 seconds while moving as a tuning target, not a delivery guarantee. Back off when stationary. Show last-update time and accuracy.
- Only authorized recipients currently viewing the relevant map subscribe; close listeners when the view closes. Maintain latest position, not a breadcrumb trail.
- Authorization checks expiry and revocation independently of cleanup. Firestore TTL deletes asynchronously, so TTL is cleanup only, never the permission boundary. [TTL documentation](https://firebase.google.com/docs/firestore/ttl)
- On stop/expiry, hide positions and cancel collection; schedule coordinate cleanup. When offline, stop local collection immediately and show pending server confirmation until acknowledged or expired.
- Foreground sharing is the first technical spike. Background sharing is a separate gate requiring platform permissions, battery testing, and applicable store declarations. Do not advertise continued background updates until tested; Android applies background location restrictions. [Android background location](https://developer.android.com/develop/sensors-and-location/location/background)

## 10. Retention, support, and launch safeguards

Proposed defaults for discussion:

| Data | Proposed retention/behavior |
|---|---|
| Current mood | Expires at end of the space's local day; no trend history in v1; cleanup within seven days |
| Live coordinates | Latest point only; access ends at stop/expiry; operational cleanup within 24 hours |
| Photos/moments | Until author or space deletion, within published quota; orphaned uploads cleaned within 24 hours |
| Tasks | Retain history until removal; define archive/export limits before paid plans |
| Deleted account content | Begin removal immediately; proposed live-system deletion target within 30 days, with backup exceptions documented |

Retention targets must be implemented and tested before becoming public promises. Server checks prevent expired data access before asynchronous deletion completes. Backups/logs require their own retention configuration. Never log precise location, mood notes, raw invite tokens, passwords, or photo contents in routine diagnostics.

Public release needs a published privacy/retention policy, account deletion flow, support contact, reporting and blocking behavior, and an operational response path for shared-content abuse. Private groups do not make photo moderation irrelevant. Apple's rules address user-generated content, deletion, and privacy; review the actual intended release against current policies. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

Document which operators can access data. Do not advertise end-to-end encryption without implementing and verifying it. Keep space membership/role checks on the server; client-hidden buttons are not authorization.

## 11. Pilot costs and launch strategy

Assume a small invitation-only pilot rather than a broad acquisition campaign. Confirm the actual budget before enabling paid projects. Separate development and production data; use local emulators where appropriate.

Cost levers: bound member counts and uploads, thumbnail media, paginate history, scope realtime subscriptions to active views, throttle live updates, limit function scaling, and monitor unusual invitation or media traffic.

Illustrative workload, not a price quote: 100 accounts posting two processed 500 KB photos daily produce roughly 3 GB of new photo data per 30 days before thumbnails/backups; downloads add egress. A 30-minute location session at a 15-second interval produces about 120 updates, with additional reads for each subscribed viewer. Use measured pilot behavior for cost estimates.

Set budget notifications and supported service limits. Alerts-only budgets do not stop spending; currently documented Firebase spend caps cover selected services, not every database/storage charge. [Firebase budget controls](https://firebase.google.com/docs/projects/billing/budget-alerts)

The user confirmed Basic and personal Plus: one account subscription works across authorized spaces without upgrading other members. See the [Stewardie subscription plan](stewardie-subscription-plan.md). Store entitlements and pooled upload allowances per account; enforce them separately from membership/role checks. Basic completed-task history covers today and the previous 3 days; Plus exposes full retained authorized history. Unfinished/overdue tasks and privacy/safety controls remain available in both tiers. Shared tasks remain usable by Basic recipients. Recommend a free pilot before payments implementation. The subscription plan v1 defines approved pilot quotas and enforcement rules. Target pricing is US$3.99/month or US$34.99/year; final launch price approval, the 5 GB cost check, retention policy, and store purchase design remain open. Free access for users does not mean zero hosting costs; a strict zero-hosting-budget requirement would require revisiting the proposed Firebase architecture before provisioning.

International-ready does not require launching everywhere at once: support Unicode names, flexible roles, localized date/time display, and translation-ready strings. Select initial countries for support, account policy, map validation, and data-region choice before provisioning production storage.

## 12. Execution milestones and completion gates

| Milestone | Deliverable | Evidence to proceed |
|---|---|---|
| 0. Setup | Flutter scaffold, plans/skill copied into project, theme and architecture | App starts on Android; existing docs preserved; analysis passes |
| 1. UI slice | Today, person filters, task detail, mood sheet with demo repositories | Reviewed screenshots, text scaling, state transitions, explicit demo status |
| 2. Online core | Accounts, spaces, invitations, tasks and handoffs | Two real accounts/devices coordinate; unauthorized space access denied; conflict/offline tests pass |
| 3. Photos and moods | Real storage, capture/gallery, optional check-ins, reactions | Membership-controlled media, retry/deduplication, denied permissions, deletion verified |
| 4. Fixed maps | Task destinations and photo pins | Capture/upload location distinction, directions, permissions and audience verified |
| 5. Live sharing | Time-limited sessions behind a feature gate | Real-device expiry, stop, removal, stale state and background behavior verified |
| 6. Pilot release | Distribution, support/reporting, deletion, cost monitoring, release policies | Selected households can onboard and use the app; no unverified functionality advertised |

Measure second-member activation, repeat household use, successful handoffs, and whether check-ins/photos receive useful responses. Gather feedback on coordination friction rather than optimizing streaks or mood submission counts.

On the current Windows machine, start Android development. iOS building/release requires macOS and Xcode; arrange a Mac or macOS build service and real-device testing before claiming iOS readiness. [Flutter iOS release guide](https://docs.flutter.dev/deployment/ios)

## 13. Decisions still needed

1. Child access in Family spaces: guardian-managed sign-in or adult-managed dependent profiles for the first release.
2. Monthly pilot service budget and willingness to enable usage-based billing.
3. First countries/test households and Android-only pilot versus simultaneous iOS testing.
4. Commercial clearance of Stewardie, domain availability, and production app identifiers before store registration.

Scaffolding and the demo UI slice can proceed before these decisions. Paid provisioning, child sign-in rollout, and public release depend on their relevant answers.
