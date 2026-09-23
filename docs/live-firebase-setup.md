# Live Firebase trial setup

The configured project is `stewardie`, Firestore region `asia-east2`. Email/password sign-in is enabled. The current app uses Firebase Spark, with no billing upgrade and no deployed Functions. Run `flutter run` from the repository root; do not use the previous unrelated localhost prototype.

Use the checked-in `backend/firebase/firestore.rules` and indexes. Never use test-mode rules, a blanket authenticated-user allow rule, or client-writable subscription tiers. Verified active membership, authorship, role, counters, and transitions are enforced by rules and transactions.

On September 24 the existing data was migrated atomically (one space, two accounts, ten document updates), with a private ignored backup in `.local/`. Existing records were preserved. The exact verified founder account received protected personal Plus; other accounts remain Basic. The restrictive rules and indexes were deployed successfully.

For an intentional future migration, `node scripts/migrate-spark.cjs` is dry-run by default; `--apply` performs writes with update-time preconditions and a backup. It uses the local Firebase CLI login. Do not publish backups, credentials, emulator exports, or private user documents. Do not roll back to the old permissive rules: fix forward or temporarily disable affected writes.

RevenueCat binds to the authenticated Firebase UID. Purchases are off by default and cannot grant Firestore Plus from a client response. The Test Store is not an App Store/Play Store integration. No real purchases or payments were made. Trusted subscription reconciliation, refunds/expiry, approved catalog pricing, store configuration, and native lifecycle tests remain release gates.

See [current verification](spark-polish-verification.md) for implemented UI and remaining limits.
