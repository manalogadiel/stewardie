# Local Firebase trial

This is an **emulator-only** online-core slice. `demo-stewardie` is a Firebase demo project ID, not a provisioned cloud project. The Flutter entry point refuses to fall through to a live Firebase project. The normal `lib/main.dart` visual/photo prototype remains separate.

Requirements: Flutter, Node.js 22 for Functions (Node 24 also passed locally with a warning), Java 21 or newer for the Firestore emulator, and npm. In `backend/firebase/functions`, run `npm ci`. Start the emulators from the repository root:

```powershell
.\backend\firebase\functions\node_modules\.bin\firebase.cmd emulators:start --project demo-stewardie --only auth,firestore,functions
```

If Java 21 is not the system default, set `JAVA_HOME` to a Java 21 installation and prepend its `bin` directory to `PATH` in that terminal. The Emulator UI is at `http://127.0.0.1:4000`.

In a second terminal, run the Flutter client:

```powershell
flutter run -d chrome -t lib/main_online.dart
```

For an Android emulator, add `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2`. For a physical Android device connected by USB, forward ports 9099, 8080 and 5001 with `adb reverse tcp:<port> tcp:<port>`, then use `FIREBASE_EMULATOR_HOST=127.0.0.1`. This has not yet been exercised on-device.

An account created in the app needs email verification. The Auth emulator captures verification links in its UI and does not send real email. To generate a **simulated verified founder account** for a local trial, set `FOUNDER_EMAIL` to the chosen email, `GCLOUD_PROJECT=demo-stewardie`, and both `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099` and `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080`, then run `npm --prefix backend/firebase/functions run seed:local-founder`. This writes a generated local password to `%TEMP%\stewardie-local-access.txt` and grants Plus to that emulator UID only. It does **not** prove ownership of the real email address. A live grant instead requires a real verified Firebase Auth account, trusted credentials, an explicit `--production` flag, and a separately reviewed deployment.

The sign-in screen has **Forgot password?**. In this local trial, the Auth emulator captures password-reset links at `http://127.0.0.1:4000/auth`; it does not email them to Gmail. If you reset the seeded account's password, the generated password in `%TEMP%\stewardie-local-access.txt` will no longer sign in. The app does not display whether an email address belongs to an account.

The emulators forget data when stopped unless exported. Use `firebase emulators:export <private-directory>` while running, then restart with `--import=<private-directory> --export-on-exit=<private-directory>`. Keep exported Auth data and the local access file outside Git and private to this computer.

Run backend tests from the repository root:

```powershell
npm --prefix backend/firebase/functions test
.\backend\firebase\functions\node_modules\.bin\firebase.cmd emulators:exec --project demo-stewardie --only auth,firestore,functions "npm --prefix backend/firebase/functions run test:rules && npm --prefix backend/firebase/functions run test:integration"
```
