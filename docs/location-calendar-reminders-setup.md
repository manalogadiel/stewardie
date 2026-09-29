# Location, calendar, and reminders rollout

The Flutter implementation keeps Today / Moments / Space. Task and plan pins, member-reported arrival, optional capture-time photo pins, and 15/30/60-minute location sessions are in the app. The scheduled worker is in `supabase/functions/scheduled-work/index.ts`; version 3 was deployed September 28, 2026, and one scheduled invocation returned HTTP 200. Real reminder delivery still needs a two-account check; see [pilot verification](pilot-completion-verification.md). The old client-on-open routine generator was removed so a routine is not silently tied to someone opening Today.

## Enable the free-plan worker

1. Deploy the current `backend/firebase/firestore.rules`, `backend/firebase/firestore.indexes.json`, and the Supabase media migration `supabase/migrations/202609270001_media_pins.sql` before using the new data fields. Keep the already configured private media function and bucket. Verify the deployed rules and index match the checked-in files in the Firebase console.
2. In the existing Supabase project `ulexhxfxatzlobabitpr`, configure Edge Function secrets `FIREBASE_PROJECT_ID=stewardie`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, and a long random `STEW_WORKER_SECRET`. The Firebase service account needs only Firestore document access. Reuse the already configured server credentials if present; never put their values in Flutter, Git, or the Cron SQL text.
3. Deploy `scheduled-work` with JWT verification disabled **only for this function**. It authenticates each POST using the private `x-worker-secret` header. A bare URL request must return 401. One successful authorized call returns `{ "spaces": ..., "errors": 0 }`; a nonzero error count returns 503 and should be investigated before scheduling.
4. Enable Supabase Cron and `pg_net`. In Supabase Vault, create `stewardie_project_url` with `https://ulexhxfxatzlobabitpr.supabase.co` and `stewardie_worker_secret` with the same worker secret. After those exist, run this SQL in the Supabase SQL editor:

   ```sql
   select cron.schedule(
     'stewardie-scheduled-work',
     '*/5 * * * *',
     $$
     select net.http_post(
       url := (select decrypted_secret from vault.decrypted_secrets where name = 'stewardie_project_url') || '/functions/v1/scheduled-work',
       headers := jsonb_build_object(
         'Content-Type', 'application/json',
         'x-worker-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'stewardie_worker_secret')
       ),
       body := '{}'::jsonb,
       timeout_milliseconds := 30000
     );
     $$
   );
   ```

The worker uses space time zones, deterministic occurrence IDs, and a Firestore commit to create each routine task with the active-task count. Routine tasks appear by about 00:05 in the space's time zone; due reminders begin at 09:00 local time, and direct requests are processed on the next five-minute run. It writes an in-app activity item for requests and due tasks; repeat runs cannot duplicate an item. At the 300-active-task cap, it records a blocked-routine activity item. It deletes expired live-location documents; Firestore rules block reads at expiry even before cleanup.

The worker scans spaces, tasks, accounts, and pending activity. This is suitable for a small trial; add indexed work queues or partitioning before a larger launch. Check Cron run history and Edge Function logs for 503s. Free-plan project pausing or service outages pause server work, while existing task data remains in Firestore.

## Optional push and Google Calendar

Mobile push uses Firebase Cloud Messaging. Android requires its `google-services.json`, Google-services Gradle plugin, and the Firebase Cloud Messaging API enabled for the existing Firebase project. The app registers a token only for an authorized notification permission and deletes its account-bound token at sign-out. The Supabase worker uses `FIREBASE_CLIENT_EMAIL` and `FIREBASE_PRIVATE_KEY` server-side to call FCM HTTP v1; never place them in Flutter. iOS still requires APNs setup. The worker uses generic lock-screen wording. The in-app inbox, routines, and task access do not depend on FCM delivery. Google Calendar OAuth remains unconfigured.

To add calendar import, create Android and iOS Google OAuth clients for the app's real package/bundle IDs and signing fingerprints. Add the clients to the corresponding native Google service configuration. Supply any required `GOOGLE_OAUTH_CLIENT_ID` / `GOOGLE_OAUTH_SERVER_CLIENT_ID` as Flutter dart defines. Enable Google Calendar API and the read-only `calendarList.readonly` and `events.readonly` scopes. Members connect privately, preview events on-device, select copies to share, refresh on open, and can disconnect while removing shared copies. Public release needs Google consent/verification as applicable.

## Device verification before release

On two authorized accounts and one nonmember, verify sharing recipients, membership removal, Stop, and expiry. On real Android and iOS devices, test permission changes, lock/background operation, network loss, and OS force-quit; the interface does not promise updates after force-quit. Test camera versus gallery pin labels, EXIF stripping, arrival attribution, Google import/unshare/refresh, routine retries, quiet hours, disabled push, and reminder cancellation after task completion. iOS push and store release still require the Apple developer/APNs setup. No OneSignal Growth or paid tier is required for this trial.
