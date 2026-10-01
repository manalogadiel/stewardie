<p align="center">
  <img src="assets/branding/stewardie-icon2.png" alt="Stewardie Logo" width="140" style="border-radius: 28px; box-shadow: 0 8px 24px rgba(0,0,0,0.12);" />
</p>

<h1 align="center">Stewardie</h1>

<p align="center">
  <strong>Your people. Your plans. Your little moments.</strong><br>
  <em>A cozy, tactile shared-life companion app for families, housemates, dormmates, and crews.</em>
</p>

<p align="center">
  <a href="https://youtu.be/y56WUBOP-VQ">
    <img src="https://img.shields.io/badge/▶_Watch_Demo_Video-YouTube-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="Watch Demo Video on YouTube" />
  </a>
</p>

<p align="center">
  <a href="#overview">Overview</a> •
  <a href="#demo-video">Demo Video</a> •
  <a href="#pitch--why-stewardie">Pitch</a> •
  <a href="#features">Features</a> •
  <a href="#revenuecat-integration--test-store">RevenueCat Test Store</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#how-to-run">How to Run</a> •
  <a href="#collaborators">Collaborators</a> •
  <a href="#project-documentation">Documentation</a>
</p>

---

## Overview

Living together shouldn't feel like managing a corporate project. Everyday shared life is filled with chores that need doing, schedules that clash, and little moments that get lost in noisy group chat threads. 

**Stewardie** is a cross-platform mobile application built in Flutter that bridges practical coordination with authentic emotional connection. Whether you are managing chores with housemates, coordinating family appointments, or sharing a campus dorm with friends, Stewardie provides a dedicated, warm, and private digital home.

With a signature **Soft Pop pastel clay aesthetic**, satisfying tactile soundscapes, and intuitive flows, Stewardie transforms daily responsibilities into seamless teamwork and everyday routines into shared celebration.

---

## Demo Video

<p align="center">
  <a href="https://youtu.be/y56WUBOP-VQ">
    <img src="https://img.youtube.com/vi/y56WUBOP-VQ/maxresdefault.jpg" alt="Stewardie Walkthrough & Demo Video" width="720" style="border-radius: 16px; box-shadow: 0 8px 24px rgba(0,0,0,0.12);" />
  </a>
  <br>
  <em><a href="https://youtu.be/y56WUBOP-VQ">▶ Watch the Stewardie Walkthrough & Feature Demo on YouTube</a></em>
</p>

The walkthrough showcases:
* The **Today** responsibility flow: Unclaimed, Requested, Covered (*"I've got it!"*), and Done.
* In-app **Moments camera** and completion photo sharing.
* Daily **Mood check-ins** (*Sky*, *Butter*, *Rose*) and teammate signals.
* **Shared Calendar** schedule view and person-aware filtering.
* **RevenueCat Test Store** simulated in-app purchases and paywall onboarding.

---

## Pitch — Why Stewardie?

> ### *"Who's taking out the recycling? Did anyone feed the cat? Are we free on Thursday?"*

Most shared organizers feel either like cold enterprise ticketing systems or chaotic messaging group chats where tasks get buried. **Stewardie changes that dynamic completely:**

* 🤝 **Zero-Friction Responsibility, No Micromanagement**: Tasks aren't just assigned; they flow naturally through clear states—*Unclaimed*, *Requested*, *Covered* ("I've got it!"), and *Done*. Need a hand? One tap offers help or hands off the task without awkward reminders.
* 🎨 **Soft Pop Tactile Design**: Say goodbye to sterile grey grids. Stewardie is crafted with warm pastel clay tones, playful clay companions, fluid physics-based micro-interactions, and comforting acoustic sound feedback that makes opening the app a joy.
* 💛 **Connection Embedded in Coordination**: Check in with a daily mood (Sky, Butter, or Rose) that rests quietly by your avatar. Celebrate chore completion by snapping photo proofs, sharing quick memories, and leaving grateful heart reactions.
* 🔒 **Privacy-First By Default**: Your shared life belongs exclusively to your circle. Private cloud storage, granular member controls, server-verified time-limited live location sharing, and encrypted data gateways ensure personal data stays safe.

---

## Features

### 🏠 Shared Spaces & Dynamic Memberships
* Create dedicated spaces for your **Family**, **Housemates**, **Friends**, or **Crew**.
* Join via **6-character invite codes**, **universal links**, or **QR code scanning** with a built-in mobile scanner.
* Space owners can regenerate codes, require member approval, or manage access permissions effortlessly.

### 📋 The "Today" Responsibility Flow
* Clear, organized categorization:
  * **Unclaimed**: Tasks open for anyone to grab.
  * **Requested**: Politely directed requests waiting for an "I've got it!" acceptance.
  * **Covered**: Tasks actively owned and being tackled.
  * **Done**: Completed tasks with completion receipts.
* Single-action completion with optional photo attachments and notes.
* Integrated subtasks, take-over offers, and collaborative handoff workflows.

### 📅 Shared Calendar & Agenda
* Unified chronological timeline of events, recurring routines, and commitments.
* **Person-Aware Filtering**: Toggle between *Shared (Everyone)*, *Your*, or specific co-members to view relevant schedules without switching identities.
* Day agenda view with month picker and all-day multi-day event spans.

### 📸 Moments & In-App Camera
* Dedicated in-app camera with preview, flip, flash, and gallery import options.
* Attach completion photos to tasks or post standalone candid moments (cooking dinner, home improvements, hangout memories).
* Stored securely in private cloud storage with member-only access and heart/gratitude reactions.

### 🌈 Daily Mood Check-Ins
* Low-pressure daily check-ins pairing a mood status with customized pastel clay colors (*Sky*, *Butter*, *Rose*).
* Automatically expires at midnight in the space's local timezone so old feelings are never stale.
* Quick "Could use a hand" action to signal teammates without altering task assignments.

### 📍 Maps & Location Context
* **Task Destinations**: Pin addresses and map locations to tasks and errands with external direction launching.
* **Moment Geotagging**: Optional location tags on captured photos showing where memories happened.
* **Temporary Live Location Sharing**: Explicit, time-limited live location sharing (15, 30, or 60 minutes) scoped strictly to authorized space members, with server-enforced expiration.

---

## RevenueCat Integration & Test Store

Stewardie implements an ethical freemium subscription architecture governed by the **Stewardie Subscription Plan v1**:
* **Basic (Free)**: Up to 3 active spaces, full access to all active & unfinished tasks, shared task completion, and today plus the previous 3 days of completed task history.
* **Personal Plus (Paid)**: Unlocks complete authorized task history paging, higher personal quotas, and personalized features. Subscriptions belong to an *individual account* across all authorized spaces and never lock out or force co-members to pay.

### 💳 Simulated Test Store (Debug Mode)
Stewardie integrates **RevenueCat (`purchases_flutter`)** to orchestrate in-app purchases and subscription entitlements.

To make local development, QA, and feature testing seamless without real credit cards or sandbox app store credentials, **Stewardie includes RevenueCat's Simulated Test Store out of the box in debug builds**:
* **Pre-Configured Offerings**: Debug runs immediately fetch mock offerings with monthly (`stewardie_plus_monthly_499`) and annual (`stewardie_plus_annual_3999`) tiers.
* **Simulated Purchases**: You can trigger and test the full-page onboarding paywall, subscription sheets, and entitlement upgrades without actual transactions.
* **Easy Toggles**:
  * Run normally with Test Store: `flutter run` (enabled by default in debug).
  * Explicitly disable test purchasing:
    ```sh
    flutter run --dart-define=ENABLE_TEST_PURCHASES=false
    ```
  * Switch off RevenueCat environment:
    ```sh
    flutter run --dart-define=REVENUECAT_ENVIRONMENT=off
    ```

---

## Tech Stack

| Domain | Technology / Package | Description |
|---|---|---|
| **Client Framework** | [Flutter](https://flutter.dev/) (Dart 3.13+) | Cross-platform mobile architecture for Android and iOS |
| **State Management** | [Flutter Riverpod](https://riverpod.dev/) (`^3.4.3`) | Robust, reactive, and declarative state orchestration |
| **Navigation & Routing** | [GoRouter](https://pub.dev/packages/go_router) (`^18.0.1`) | Declarative URL-based deep linking and route guards |
| **Authentication & Identity** | [Firebase Auth](https://firebase.google.com/docs/auth) (`^6.7.0`) | Verified email/password identity, JWT session verification |
| **Cloud Database & Storage** | [Supabase](https://supabase.com/) | Cloud PostgreSQL with Row Level Security (RLS), atomic SQL RPC gateways, and private S3-compatible media buckets |
| **Push Notifications** | [Firebase Cloud Messaging (FCM)](https://firebase.google.com/docs/cloud-messaging) | Account-bound device tokens and background activity alerts |
| **Monetization & In-App Purchases** | [RevenueCat](https://www.revenuecat.com/) (`purchases_flutter ^10.13.1`) | Subscription entitlement lifecycle with simulated Test Store |
| **Mapping & Location** | `flutter_map` (`^7.0.2`), `latlong2`, `geolocator` | OpenStreetMap & MapTiler raster tiles, device location services |
| **Camera & Media** | `camera` (`^0.12.1`), `image_picker`, `gal` | Custom in-app camera capture, preview, compression, and gallery export |
| **QR Code & Scanner** | `mobile_scanner` (`^7.4.2`), `qr_flutter` (`^4.1.0`) | Invite code QR generation and real-time camera scanning |
| **Offline Cache & Persistence** | [Sembast](https://pub.dev/packages/sembast) (`^3.8.11`), `path_provider` | High-performance local NoSQL document database for offline resilience |
| **Design & Typography** | Google Fonts (Fredoka & Nunito Sans) | Custom bundled typography and Soft Pop pastel clay tokens |

---

## How to Run

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.13.0` or higher)
* [Dart SDK](https://dart.dev/get-dart)
* Android Studio (with Android SDK & emulator / physical device) or Xcode (macOS for iOS builds)
* Git

### Step-by-Step Setup

1. **Clone the Repository**:
   ```sh
   git clone https://github.com/manalogadiel/stewardie.git
   cd stewardie
   ```

2. **Install Dependencies**:
   ```sh
   flutter pub get
   ```

3. **Run the App in Debug Mode**:
   Running the default target launches the cloud-connected app with the **RevenueCat Simulated Test Store** active:
   ```sh
   flutter run
   ```

4. **Alternative Run Modes**:
   * **Run with Test Purchases Disabled**:
     ```sh
     flutter run --dart-define=ENABLE_TEST_PURCHASES=false
     ```
   * **Run the Offline Visual Fixture** (Standalone UI fixture with seeded mock data, no cloud credentials required):
     ```sh
     flutter run -t lib/main_fixture.dart
     ```

5. **Run Tests & Code Analysis**:
   ```sh
   # Run Flutter unit and widget tests
   flutter test

   # Run Dart static analysis
   flutter analyze
   ```

---

## Collaborators

Stewardie is lovingly designed and engineered by:

<p align="center">
  <a href="https://github.com/manalogadiel">
    <img src="https://github.com/manalogadiel.png?size=100" width="100" height="100" style="border-radius: 50%;" alt="Gadiel Manalo" />
  </a>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://github.com/kuroi17">
    <img src="https://github.com/kuroi17.png?size=100" width="100" height="100" style="border-radius: 50%;" alt="georgie" />
  </a>
</p>

<p align="center">
  <strong><a href="https://github.com/manalogadiel">Gadiel Manalo</a></strong> &nbsp;|&nbsp; <strong><a href="https://github.com/kuroi17">georgie</a></strong>
</p>

* **[Gadiel Manalo (@manalogadiel)](https://github.com/manalogadiel)** — Project Architect, Core Flutter & Backend Engineering, Supabase/Firebase Integration, Database Migration, and Subscription Infrastructure.
* **[georgie (@kuroi17)](https://github.com/kuroi17)** — Core Contributor, Feature Implementation, UI/UX Polish, and Design Engineering.

---

## Project Documentation

For in-depth architectural specifications and verification audits, consult the [docs/](docs/) directory:
* [Product Plan](docs/shared-spaces-product-plan.md) — Feature behaviors, audience scope, and roadmap.
* [UI and Asset Plan](docs/ui-plan.md) — Visual tokens, Soft Pop clay style guidelines, and screen hierarchies.
* [Subscription Plan v1](docs/stewardie-subscription-plan.md) — Tier boundaries, quotas, and pricing models.
* [Supabase Migration & Gateways](docs/supabase-core-migration.md) — PostgreSQL schema, RPC functions, and live cloud deployment.
* [Onboarding & Paywall Verification](docs/onboarding-plus-and-logo-verification.md) — RevenueCat paywall flows and launcher asset verification.
* [Soft Pop Sound Design](docs/soft-pop-sound-expansion-verification.md) — Tactile soundscapes and volume controls.
