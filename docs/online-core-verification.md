# Online core — local Firebase emulator

Updated September 23, 2026. The user chose a **local trial first** and founder Plus for their account only. Firebase is the selected core for this trial. No live Firebase project, Blaze billing, developer-store account, in-app purchase, deployment or publication was created.

The separate `lib/main_online.dart` client uses only the `demo-stewardie` Firebase emulators. It has email/password entry, verification and password-reset request, account tier display, space creation/switching, invitation preview/redeem, member list, member-scoped active tasks, accept/decline/help/handoff/complete actions, and paged Done history. Server Functions own space/member counters, task transitions and the founder entitlement; Firestore rules deny client writes, revoked/nonmember access, and direct completed-history reads. Basic Done history is today plus the previous three dates in the space time zone; Plus can page through retained history. Both tiers can complete shared tasks. The founder grant resolves an exact verified Auth record to its UID and does not grant anyone else Plus.

The local visual/photo prototype at `lib/main.dart` is unchanged in behavior and still has fixed identity and fixture spaces. The online entry point currently has an empty Moments destination and does not connect photos, moods, calendar plans, notifications, location, routines or the full task detail UI. The local seed script can mark a mock Auth account as verified; that demonstrates entitlement wiring but does not verify ownership of a real Gmail inbox. No production founder grant has occurred.

## Checks performed

- `npm test`: six pure domain tests passed, including space-local history date boundaries and founder target validation.
- Firestore emulator: three security-rule tests passed for member-only reads, verification, completed-history denial and client-write denial.
- Auth/Firestore/Functions emulator: two accounts exercised Basic caps, Plus grant, invitation preview/redeem/revocation, member task actions, Done history, and a simultaneous claim. Exactly one claimant became owner.
- `flutter analyze`: passed after the online UI was added and updated.
- `flutter test`: 47 existing tests passed for the local visual/photo prototype.
- `flutter build web -t lib/main_online.dart` and `flutter build apk --debug -t lib/main_online.dart`: passed. The Android build emitted a future Kotlin-plugin compatibility warning.
- Browser review: a local seeded account signed in, displayed its Plus badge, created a space and task, accepted responsibility, marked it done and saw it in Done. The browser review used both a narrow phone-sized view and a larger view. Android runtime and iOS were not exercised.
- September 23 account-flow follow-up: the browser showed the Forgot password form, the Auth emulator recorded a `PASSWORD_RESET` request for the seeded account, and an unknown address received the same neutral success message. A wrong password produced clear sign-in feedback. After signing in, a browser reload restored the same account, space and personal Plus badge. `flutter analyze`, 47 Flutter tests, and the online web build passed. The reset link was not opened and the password was not changed; the emulator sends no real email. Android/iOS runtime remains unverified.

## Remaining work and launch gates

The current code is a first online slice, **not a complete release**. The highest-priority implementation work is to merge the online repository into the full Soft Pop Today/Moments/Space UI; finish server-authorized task detail, media upload/processing and quota enforcement; persist and share moods/calendar plans; implement member management, account recovery/deletion, privacy controls, notifications, routines, and location flows; and test offline conflicts, revocation and two physical devices. Storage rules deliberately deny all reads/writes until private upload and download handling is implemented and tested.

Before a store release, the user still needs to choose child-account policy and launch markets, set an operating budget, obtain Apple Developer and Google Play Console accounts and Mac/iOS build access, complete privacy/legal and name-clearance work, provision a real Firebase project with billing/budget controls as needed, configure signing and store listings, verify the founder's real account, and finish store/subscription policy decisions. Those gates are separate from the local build authorization.
