# Notification reads and Android launch icon

Implemented October 1, 2026.

## Notification worker

The five-minute worker previously scanned complete task/event/photo histories and every account's activity history. These reads grew with retained history even when nothing changed.

- Tasks, space events, moods and photo reactions now use timestamp/document cursors, limited to 100 changes per stream per run. Progress advances only after the batch succeeds; deterministic inbox IDs keep retries idempotent. Cursor timestamps retain server precision.
- Published photos use an independent Supabase publication-time/ID cursor. Reactions on older photos remain discoverable through a Firestore descendant query.
- Push delivery queries only pending items, rotating its cursor so quiet-hours or failed items cannot indefinitely block later notifications.
- Unchanged unfinished tasks are revisited once daily after 9am for due reminders. Calendar queries cover the reminder window rather than all historical and future plans.
- Cleanup/review queries filter eligible states. Space cleanup removes its worker progress records. Membership, opt-outs, quiet hours and entity access are still rechecked before delivery.

This reduces repeated history reads; it does not eliminate all reads. Spaces, accounts, routines, preferences and pending work still require reads. Larger backlogs may take multiple worker intervals. The first cursor run processes eligible records since the existing rollout cutoff; it does not create pre-rollout historical notifications.

Deployed the scheduled-work function and the reactions/createdAt collection-group index. No billing, OneSignal or public publication was enabled. An exhausted Firestore quota cannot be reset by these changes; live delivery requires available quota. Index creation can take time to become ready, and a failed query does not advance its cursor.

## Android splash

Android 12+ now uses an explicit light launch background and a dedicated adaptive splash drawable containing the full approved mascot icon, without the launcher's padded white container. The home-screen icon is unchanged. Both light and dark system themes use this launch treatment.

## Verification

- All 12 scheduled worker Node regression tests passed, including recipient restrictions, deterministic IDs, rollout filtering, cursor ordering/precision and pending-only push selection.
- Firebase index deployment succeeded; Supabase function deployment succeeded.
- Android debug APK built successfully with the existing explicit Test Store flag.
- The phone was disconnected during installation (`adb: no devices/emulators found`). The corrected splash still needs a cold-launch visual check on the device after installing the new build; no live push delivery was verified during the quota outage.

Run `flutter run --dart-define=ENABLE_TEST_PURCHASES=true` for the same Test Store configuration, or normal `flutter run` without simulated purchases. Cold-start the updated app from its home icon to check the native splash.
