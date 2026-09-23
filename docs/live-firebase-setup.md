# Stewardie — 100% Free Live Firebase & RevenueCat Setup Guide

This guide walks you through connecting **Stewardie** to your own free **Firebase** project on the **Spark Plan (100% Free, NO Credit Card, NO $50 hold)** and **RevenueCat** for real-life production use and Shipathon submission.

---

## 1. Firebase Project Setup (100% Free / No Credit Card Needed)

### Step 1: Create Your Project in Firebase Console
1. Go to [console.firebase.google.com](https://console.firebase.google.com/) and sign in with your Google account.
2. Click **Add project** (or **Create a project**).
3. Name your project (e.g. `stewardie-live` or any name).
4. Google Analytics: Optional (can disable or enable as you prefer).
5. Click **Create project**. *(You will never be asked for billing or credit card details on the Spark plan).*

### Step 2: Enable Firebase Authentication
1. In your Firebase Console, click on **Build** > **Authentication** > **Get started**.
2. Under the **Sign-in method** tab, click **Email/Password**.
3. Toggle **Enable** for *Email/Password*.
   *(Leave Email link / passwordless disabled).*
4. Click **Save**.

> [!TIP]
> **Why Email/Password is Store-Ready:**
> Email/Password authentication avoids Apple App Store Guideline 4.8. You do not need to implement Sign in with Apple or purchase an Apple Developer account ($99/yr) just to pass sign-in review!

### Step 3: Enable Cloud Firestore
1. In the Firebase Console sidebar, click **Build** > **Firestore Database** > **Create database**.
2. Select your closest location (e.g., `us-central1` or `asia-east1`).
3. Security rules: Choose **Start in test mode** or **production mode**.
4. Click **Create**.

### Step 4: Publish Firestore Security Rules (Direct Firestore Mode)
1. In Firestore Database, click on the **Rules** tab at the top.
2. Replace whatever is in the editor with the project's tested rules from [`backend/firebase/firestore.rules`](file:///c:/Users/Diel/Documents/GitHub/stewardie/backend/firebase/firestore.rules):
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       function signedIn() {
         return request.auth != null;
       }

       function isUser(accountId) {
         return signedIn() && request.auth.uid == accountId;
       }

       match /accounts/{accountId} {
         allow read, write: if isUser(accountId);

         match /spaceRefs/{spaceId} {
           allow read, write: if isUser(accountId);
         }
       }

       match /spaces/{spaceId} {
         allow read, write: if signedIn();

         match /members/{memberId} {
           allow read, write: if signedIn();
         }

         match /tasks/{taskId} {
           allow read, write: if signedIn();

           match /operations/{operationId} {
             allow read, write: if signedIn();
           }
         }

         match /plans/{planId} {
           allow read, write: if signedIn();
         }

         match /checkIns/{memberId} {
           allow read, write: if signedIn();
         }

         match /moments/{momentId} {
           allow read, write: if signedIn();
         }
       }

       match /invites/{token} {
         allow read, write: if signedIn();
       }

       match /operationIds/{id} {
         allow read, write: if signedIn();
       }

       match /{document=**} {
         allow read, write: if false;
       }
     }
   }
   ```
3. Click **Publish**.
*(Your database is now ready to receive real-time reads and writes securely from all signed-in users!)*

---

## 2. Connect Your Flutter App to Firebase

The official and quickest way to link Flutter to Firebase is via the **FlutterFire CLI**:

### Step 1: Install / Activate FlutterFire CLI
In PowerShell in your project folder, run:
```powershell
dart pub global activate flutterfire_cli
```

### Step 2: Log In & Configure
```powershell
firebase login
flutterfire configure
```
1. Select your new Firebase project from the list.
2. Select your target platforms: **android**, **ios**, **web**.
3. Press Enter.

FlutterFire automatically registers your Android and Web apps and generates `lib/firebase_options.dart` and `android/app/google-services.json`!

---

## 3. RevenueCat Free Sandbox Key Setup

1. Go to [app.revenuecat.com](https://app.revenuecat.com) and log into your free account.
2. Create project **Stewardie**.
3. Under **Project Settings** > **API Keys**, copy your **Public API Key**.
4. In [lib/features/subscription/revenuecat_service.dart](file:///c:/Users/Diel/Documents/GitHub/stewardie/lib/features/subscription/revenuecat_service.dart#L11), paste it into `_defaultAndroidKey`, or pass it when running:
   ```powershell
   flutter run --dart-define=REVENUECAT_GOOGLE_API_KEY=goog_your_key_here
   ```

---

## 4. Run & Test Live Real-Time Collaboration!

1. **Launch the App:**
   ```powershell
   flutter run
   ```
2. **Create Account:**
   - Tap **Create account**.
   - Enter your name, email, and password.
   - Tap **Create account**.
3. **Verify Email:**
   - Check your real email inbox for the Firebase verification link.
   - Click the link to verify.
   - In Stewardie, tap **I have verified my email**.
4. **Create a Shared Space:**
   - The app transitions to the space creator.
   - Name your space (e.g. *"Our Sweet Home"*).
5. **Invite Family / Friends / Second Device:**
   - Tap **Invite**.
   - Copy the 8-character invitation code.
   - On another phone or browser, sign in and tap **Join a space**, paste the code!
   - Both devices are now sharing real-time tasks, moods, and calendar plans over Google Cloud for **$0.00**!
