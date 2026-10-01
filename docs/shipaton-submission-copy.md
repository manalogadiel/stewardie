# Stewardie — submission copy and award strategy

Prepared October 1, 2026. Paste only the relevant field content below into Devpost. The final section contains private preparation notes, not submission copy.

## Elevator pitch

Share the load. Keep the good moments. Stewardie helps families and housemates coordinate tasks, plans, moods, and memories in one shared space.

## About the project — paste the following story

## Inspiration

A chore takes more than the few minutes spent doing it. Someone has to notice it, remember it, ask for help, and follow up. When that work lives in scattered messages, even small responsibilities can become another thing to carry.

I built **Stewardie** around a simple idea: people sharing a home should have a shared place for the work that keeps it running—and the moments that make it worth sharing.

My starting audience is families and housemates, including students sharing accommodation. The goal is to make everyday coordination easier while keeping the experience friendly and personal.

## What it does

Stewardie organizes shared life into three places:

- **Today:** See tasks, accept a request, offer help, and mark work complete. Shared calendar plans and daily mood check-ins add context to the day.
- **Moments:** Share photos, react to them, and revisit a saved capture location when one is attached.
- **Space:** Manage the group, invite members, and organize routines and account preferences.

Members can create separate spaces for different groups. Optional live location sharing lasts 15, 30, or 60 minutes, applies to the selected space, and can be stopped. Opening a map does not start sharing.

The task flow is central: a request becomes a clear commitment when someone accepts it, and completion closes the loop. A mood check-in offers another way to communicate how the day feels. Moments keeps the good bits alongside the responsibilities.

## How we built it

I built the app in **Flutter and Dart**, with Riverpod for state and GoRouter for navigation. **Firebase Authentication** provides account identity; **Supabase Postgres, Edge Functions, and private Storage** provide the current shared-data backend and photo access.

Important operations run through authenticated server workflows. Membership determines access, task versions protect against conflicting edits, and stable operation IDs prevent successful retries from creating duplicate work.

**RevenueCat's Flutter SDK** powers the subscription integration and development Test Store flow. The optional Personal Plus paywall is available during onboarding and can be skipped. Basic remains free. Plus is designed for an individual account across its authorized spaces, so one member's subscription never becomes a payment requirement for everyone else.

The visual system uses pastel clay mascots, rounded typography, raised controls, and motion and sound feedback to give everyday actions a warmer feel. Maps use MapTiler through flutter_map, and a custom camera supports photo capture.

## Challenges we ran into

The hardest challenge was making a shared app dependable under real cloud constraints. Firestore quota exhaustion blocked ordinary actions, including creating a space. I moved new shared data to Supabase while retaining Firebase sign-in and preserving the old records for a later migration.

That required more than changing a database connection: invitations, task transitions, photo permissions, location expiry, and subscription state all had to use the new authority consistently.

Design brought its own challenges. Camera controls, small-screen layouts, keyboard insets, and permission flows needed repeated refinement. I also learned to distinguish a passing automated test from behavior verified on a physical device.

## Accomplishments that we're proud of

- **A working Android cloud pilot:** Space creation and automatic selection were confirmed on a physical phone. Deployed cloud checks exercised joining, task acceptance and completion, photo upload and download, reactions, and location-session operations.
- **Access controls that follow the group:** Those checks also verified rejection of nonmembers and removed members, including attempts to fabricate Plus access.
- **A recognizable visual identity:** The Soft Pop mascots connect practical task management with moods and shared photos across the app.
- **A deliberate subscription boundary:** Basic members retain unfinished tasks and shared task completion. Plus adds personal capacity and access to retained authorized history.
- **Documented verification:** The latest recorded Flutter regression run passed 231 tests, alongside 36 backend tests. These support the tested behavior; they do not replace remaining device checks.

## What we learned

I learned that the hardest part of shared software is making a promise hold across people, devices, and retries. An accepted task, a completed upload, and an expired location session each need an authoritative answer.

I also learned that small design decisions carry product values. Keeping task completion free, making permissions optional, and allowing people to skip the paywall all support the same aim: make it easier to participate.

## What's next for Stewardie

Next, I want to test complete shared-household journeys on two devices, verify native notification delivery and the RevenueCat purchase-to-entitlement flow, and carefully reconcile the preserved Firebase history.

I then want to learn from a small pilot with families and housemates: can people understand what needs doing, ask for help comfortably, and spend less effort coordinating their day?

**Stewardie makes room for both the things we need to do and the people we do them with.**

## Built with

Suggested Devpost tags, within its 25-tag limit:

Flutter, Dart, Riverpod, GoRouter, RevenueCat, Firebase Authentication, Firebase Cloud Messaging, Supabase, PostgreSQL, SQL, TypeScript, Deno, MapTiler, flutter_map, Geolocator, Camera, Image Picker, Sembast, Node.js, PGlite, Git, GitHub, OpenAI Codex.

Supporting libraries and assets: purchases_flutter, http, image, permission_handler, path_provider, gal, timezone, latlong2, mobile_scanner, qr_flutter, bundled Fredoka and Nunito Sans fonts, and custom mascot illustrations.

Only add Gemini or Claude as tool tags if you personally used them in the submitted build and want to disclose that contribution. No claim of Kotlin Multiplatform, OneSignal, Replit, Layers, Noise, or Stripe integration is made.

## Additional notes for judges — paste if accurate at submission time

Stewardie is entered for the Next Gen Award as a working Android pilot. The repository includes Flutter source, assets, cloud migrations, server functions, and setup and verification documentation. The current cloud path uses Firebase Authentication with Supabase for new spaces; older Firebase records are preserved for a later migration.

RevenueCat is integrated in development Test Store mode. Transactions in that mode are simulated and incur no real charge. No commercial revenue or verified conversion results are claimed. End-to-end purchase activation, native push delivery, and iOS remain verification limits documented in the repository.

## Conditional award answers

**Current recommendation:** Enter Next Gen. Leave the other award fields blank unless the project also meets their release and integration requirements. The following answers are prepared for use only if eligible; completing an answer does not establish eligibility.

### HAMM — monetization model

Stewardie's planned revenue comes from an optional individual subscription: **Personal Plus at US$4.99 per month or US$39.99 per year**, approximately 33% below twelve monthly payments. Basic is free, includes up to three spaces, and keeps unfinished tasks and shared task completion available. Its completion history covers today and the previous three days. Plus adds unlimited retained authorized completion history and higher personal limits.

The onboarding paywall can be skipped, and subscription access is also available from the account experience. RevenueCat manages the purchase integration and entitlement reconciliation. The annual option offers a lower yearly cost; the monthly option requires less upfront commitment.

I chose a personal subscription because mixed free and paid members must be able to coordinate together. A Plus purchase follows its owner across authorized spaces without changing anyone's membership or role. This keeps the paid value aligned with a person's capacity and history needs. The pricing is a target, commercial billing is not active, and there are no verified revenue or conversion figures to report yet.

### RevenueCat Peace Prize — intended benefit

Stewardie is designed for a small, everyday form of social good: making shared responsibilities easier to see, accept, and support. Families and housemates can use it to clarify commitments, coordinate schedules, ask for help, and keep shared memories together.

Daily mood check-ins provide optional context rather than a score or ranking. Location sharing is an explicit, time-limited choice. Basic members retain shared task completion, so a group's coordination does not depend on every person buying a subscription.

The intended benefit is less effort spent chasing updates and more room for considerate participation. This is an early pilot: reduced stress, fairer workload distribution, and stronger relationships are outcomes to investigate with users, not measured results we claim today.

### RevenueCat Design Award — details to evaluate

Stewardie's Soft Pop design gives shared-life tools a consistent visual character: pastel clay mascots, rounded Fredoka and Nunito Sans typography, raised surfaces, and soft shadows. The illustrations are tied to the activity, from mood expressions to camera-themed Moments artwork.

Please look at how the three main destinations connect: Today makes task responsibility visible, Moments gives shared photos and reactions their own space, and Space keeps group management together. Also evaluate the onboarding transitions, button feedback, sheet gestures, and the use of motion and sound around everyday actions.

The design goal is to make a useful coordination tool feel welcoming enough to become part of daily life. Physical-device accessibility and remaining motion conditions still need further validation.

### Influencer Award

Leave blank. The Productivity brief specifically targets reusable-content capture and retrieval for Apple power users; a shared household organizer is not a close fit. The other four briefs target nutrition, fitness, manager conversation practice, and gaming backlogs.

### Other fields to leave blank for the current build

| Field | Missing requirement or mismatch |
|---|---|
| Ship Kotlin Everywhere | Flutter implementation; no Kotlin/Compose Multiplatform app published on both required stores. |
| Most Viral App / Noise | No verified Noise promotion, account, live app campaign, or results. |
| Best App for Galaxy | No qualifying published Galaxy Store listing or verified Galaxy-specific optimization. Testing on a Samsung phone alone is insufficient. |
| Idea to Income / Replit | No verified Replit Agent build, qualifying preview, public build posts, or paying-user growth. |
| Keep Them Coming Back / OneSignal | Firebase Cloud Messaging does not establish OneSignal integration or a deployed OneSignal campaign. |
| Growth Loop / Layers | No verified Layers SDK installation or experiment signal. |
| Funnel Vision / Stripe | No live RevenueCat web-to-app funnel with Stripe checkout, project ID, or payment results. |

## Private preparation notes — do not paste as project copy

### Corrections to the earlier advice

1. The Productivity influencer category is a specific reusable-content brief, not general productivity. Do not select it simply because Stewardie has tasks.
2. RevenueCat's organizer guide says Next Gen can use a public open-source repository and demo instead of a store release. Other categories, including Design, Peace, and HAMM, require the store-release conditions too.
3. RevenueCat Test Store is a real SDK testing integration, but its transactions are simulated. The current record does not verify a successful purchase-to-Plus unlock. An installed SDK or paywall alone is weak evidence of a working monetization flow. No paid purchase is required by this recommendation.
4. Do not describe revenue, retention, user growth, reduced stress, or fairer workloads as measured results without evidence.

### Highest-priority evidence

- Academic eligibility: active enrollment and the qualifying academic email required by Next Gen. Do not invent an enrollment or personal background statement.
- Public repository and a visible open-source license: no LICENSE file was found in the local repository during this review. Choose an appropriate license before publishing one; verify rights to included artwork and dependencies. Public visibility was not confirmed by the web lookup.
- Latest source and instructions: make sure the submitted remote commit contains the current cloud migration, not just an earlier visual fixture.
- Demo: less than two minutes, accessible on YouTube or Vimeo, with actual target-device footage. Show a coherent task request → acceptance → completion, then a Moment and the skippable paywall. If showing a purchase, record a genuine Test Store transaction and backend-confirmed Plus state, and label it simulated. Do not stage a fake success.
- Icon and screenshot: candidates already exist at submission/stewardie-icon-1024.png and submission/stewardie-today-1179x2556.png. Confirm exact dimensions and that the screenshot has no device frame.
- RevenueCat project ID and package identifier: copy these from the configured project and build; do not substitute an API key or expose a server secret.

### One useful demo scenario

Show a housemate asking someone to handle a shared task. Show the second member accepting it, marking it complete, and sharing a photo of the result. Add a brief mood check-in and close on the optional Personal Plus offer. This demonstrates responsibility, connection, visual craft, and monetization without turning the video into a feature checklist. Use only actions that actually work in the recorded build.

### Timing

The official deadline was September 30, 2026 at 11:45 PM PDT, equivalent to **October 1, 2026 at 2:45 PM Asia/Manila**. At this review, that time had passed. The organizer says later portfolio edits do not change the competition's submitted version. If already submitted, confirm any permitted competition correction with the organizer; do not assume updating the public page replaces the judged snapshot.

### Sources

- Official rules and Next Gen criteria: https://revenuecat-shipaton-2026.devpost.com/rules
- Organizer submission guidance, award eligibility, and deadline: https://www.revenuecat.com/blog/engineering/how-to-submit-your-app-for-shipaton
- Judging and the importance of clear demonstration: https://www.shipaton.com/blog/how-we-judge-shipaton

These materials support preparation; they cannot guarantee award eligibility, acceptance of a late change, or winning.
