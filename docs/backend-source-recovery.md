# Backend source recovery and verification

Updated October 4, 2026.

## Recovered source

The private backup at `C:/Users/Diel/Documents/GitHub/stewardie_private_backup` contains the Supabase source removed during public-repository cleanup. Recovered into this checkout:

- `supabase/migrations`: the existing SQL migrations.
- `supabase/functions`: Firebase-token gateways, private media, subscription reconciliation, and the scheduled FCM worker.
- `tools/supabase-core`: database regression tests and migration tools.

Only SQL, TypeScript, JavaScript and reviewed package manifests were copied. Environment files, private credentials, build caches and customer exports were excluded. A scan found no embedded private keys, service-role JWTs or secret API tokens in these copied sources. This is a local recovery; it does not prove the deployed functions match the backup.

These folders remain ignored by the existing public-repository policy. Keep the private backup. A public source handoff would require explicitly selecting safe source files; do not remove all privacy exclusions or copy credentials.

## Implemented locally

- Reduced fallback document polling from 15 to 45 seconds; pauses in background, refreshes on resume, retains immediate mutation invalidation and existing coalesced reads.
- Retained space summaries during loading, corrected read-notification counting, added per-space inbox filtering/navigation.
- Clay member pins, nearby member grouping, local self-avatar in place selection, optional Geoapify search and nearby provider places.
- Daily Moments filtering at space-local midnight, date-grouped archive UI without duplicate photo uploads, membership/removed-photo guards.
- Fullscreen photo canvas, thumbnail-derived cached pastel gradient, original framing, compact six-reaction row, location icon/sheet, zoom reset/back handling.
- Branded verification screen and concise verification/spam-folder guidance.
- One 401 token-refresh retry with the same operation ID, plus account-change response guards.
- New additive `202610040001_location_requests.sql`: current-membership checks, recipient-only response, 15-minute expiry, one pending request per sender/recipient, 10-minute pair cooldown across spaces, 10 requests per sender/day and five per recipient/hour. Requests never start GPS sharing. One private notification is emitted atomically; retries do not duplicate it.

## Validation

The recovered backend suite passed 60 tests; the new location-request SQL suite passed five tests. The final focused Flutter suite passed 28 tests, and both viewer layout tests passed. These checks cover parsing/grouping, notification counts, avatar and Moments behavior, permission serialization, optimistic reaction updates, lifecycle polling and safe token refresh. Viewer tests cover a 360×640 viewport at normal and doubled text scale. Mocked map-tile errors in widget tests are expected network isolation, not a production map-provider verification.

## Still required

- Test real FCM delivery, notification-slider routing, GPS permissions/grouped pins, iOS safe areas and two-device membership removal. No device/cloud success is claimed from local tests.
- Confirm sender domain/SMTP ownership before changing verification email delivery. UI branding cannot guarantee inbox placement or configure DNS.
- Geoapify is configured and its autocomplete/Places APIs returned public Philippine results. Broader provider coverage and actual device selection still need verification; pin selection remains the fallback.
- Storage cleanup/retention and usage measurements remain review gates. No new cloud deletion, billing change or old Firebase migration occurred.

## Cloud deployment update — 2026-10-04

The user connected the existing Supabase dashboard. Applied only additive migrations `202610040001_location_requests.sql`, `202610040002_media_archive.sql`, and `202610040003_notification_summary.sql`; deployed matching `core-data`, `media`, and `scheduled-work` functions. New SQL passed rollback-only live workflow checks. Invalid-token gateway checks returned 401. Geoapify public-place queries returned 200; the client key stays in ignored local configuration.

The new archive APIs use cursor pagination and server date stamps. The notification bell now reads a summary rather than every space's tasks. Earlier "not deployed" items above are superseded for these three migrations/functions. Hardware FCM/GPS checks, verified email sender configuration, and cleanup/retention gates remain outstanding. No new test authentication accounts were created: automatic approval review rejected lasting live fixtures, so verification used rolled-back SQL fixtures instead.
