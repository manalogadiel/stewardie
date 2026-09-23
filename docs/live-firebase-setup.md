# Stewardie — Live Firebase & RevenueCat Setup Guide

This guide walks you through connecting **Stewardie** to your own free **Firebase** project and **RevenueCat** project for real-life production use and Shipathon submission.

---

## 1. Firebase Project Setup (100% Free / Spark Tier)

### Step 1: Create Your Project in Firebase Console
1. Go to [console.firebase.google.com](https://console.firebase.google.com/) and sign in with your Google account.
2. Click **Add project** (or **Create a project**).
3. Name your project (e.g. `stewardie-app` or your choice).
4. Google Analytics: Optional (can disable or enable as you prefer).
5. Click **Create project**.

### Step 2: Enable Firebase Authentication
1. In your Firebase Console, click on **Build** > **Authentication** > **Get started**.
2. Under the **Sign-in method** tab, click **Email/Password**.
3. Toggle **Enable** for *Email/Password*.
   *(Leave Email link / passwordless disabled unless desired).*
4. Click **Save**.

> [!TIP]
> **Why Email/Password is Store-Ready:**
> Email/Password authentication avoids Apple App Store Guideline 4.8. You do not need to implement Sign in with Apple or purchase an Apple Developer account ($99/yr) just to pass sign-in review!

### Step 3: Enable Cloud Firestore
1. In the Firebase Console sidebar, click **Build** > **Firestore Database** > **Create database**.
2. Select your closest location (e.g., `us-central1` or `asia-east1`).
3. Security rules: Choose **Start in production mode** or **Start in test mode** (we will deploy the project's tested rules in Step 5).
4. Click **Create**.

---

## 2. Connect the Flutter App to Your Firebase Project

The easiest and official way to link Flutter to Firebase is using the **FlutterFire CLI**:

### Option A: Official FlutterFire CLI (Recommended)
1. Open PowerShell / Terminal in the project root:
   ```powershell
   dart pub global activate flutterfire_cli
   ```
2. Make sure you are logged into Firebase:
   ```powershell
   firebase login
   ```
3. Run the configuration wizard:
   ```powershell
   flutterfire configure
   ```
   - Select your Firebase project from the list.
   - Select platforms (Android, iOS, Web).
   - This automatically creates `lib/firebase_options.dart` and configures `google-services.json`!

### Option B: Quick Environment Defines (No CLI needed)
If you prefer not running the CLI, obtain your Web/Android configuration from Firebase Console:
- Project Settings > General > Your apps.
- Run or build your Flutter app with dart-defines:
  ```powershell
  flutter run --dart-define=FIREBASE_API_KEY=AIzaSy... --dart-define=FIREBASE_APP_ID=1:123...:android:... --dart-define=FIREBASE_PROJECT_ID=your-project-id
  ```

---

## 3. Deploy Firestore Rules & Cloud Functions

Stewardie includes pre-tested Firestore rules and backend Cloud Functions in `backend/firebase/`:

### Deploy Firestore Security Rules
```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

### Deploy Cloud Functions (Requires Blaze Plan Free Tier)
If your project is on the Blaze plan (pay-as-you-go with 2M free function calls per month):
```powershell
firebase deploy --only functions
```
The callable functions (`createSpace`, `createTask`, `actOnTask`, `redeemInvite`, etc.) will be deployed to your live project.

> [!NOTE]
> If you are on the Spark (completely free) plan without Blaze enabled, you can also use local emulators during development:
> ```powershell
> firebase emulators:start
> flutter run --dart-define=USE_FIREBASE_EMULATOR=true
> ```

---

## 4. RevenueCat Live Key Configuration

1. Log into [app.revenuecat.com](https://app.revenuecat.com).
2. Go to **Project Settings** > **API Keys**.
3. Copy your **Public API Key**:
   - For Android: `goog_...`
   - For iOS: `appl_...`
4. When building or running the app:
   ```powershell
   flutter run --dart-define=REVENUECAT_GOOGLE_API_KEY=goog_your_key_here
   ```
   Or set it in `lib/features/subscription/revenuecat_service.dart`.

---

## 5. Testing the Real Live Flow

1. **Launch the App:**
   ```powershell
   flutter run
   ```
2. **Create Account:**
   - Tap **Create account**.
   - Enter your real Name, Email, and Password.
   - Tap **Create account**.
3. **Verify Email:**
   - Firebase sends a real verification email to your inbox.
   - Open your email and click the verification link.
   - Return to Stewardie and tap **I have verified my email**.
4. **Create / Join Space:**
   - The app instantly switches to the live space setup screen.
   - Create your first shared space (e.g. "Our Apartment" or "Family Hub").
5. **Explore & Collaborate:**
   - Create tasks, post moments, set moods, and test the Soft Pop paywall!
