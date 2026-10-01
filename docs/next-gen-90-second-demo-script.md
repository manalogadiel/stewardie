# Stewardie — Next Gen Award demo

Runtime: 1 minute 30 seconds. Use a narrated screencast of the Android app, with simple cuts between recorded actions. Open on the app immediately, not an animated introduction. Use one consistent example space, **Our Home**, with a task named **Pick up groceries**, a calendar plan named **Dinner together**, and a dinner photo. Pause briefly after each action so viewers can see the result.

## Script and shot list

| Time | Device footage | Voiceover |
| --- | --- | --- |
| 0:00–0:08 | Today screen with the example task and calendar visible; small Stewardie title overlay. | “Stewardie helps families and housemates share tasks, plans, and everyday moments in one private space.” |
| 0:08–0:17 | Brief onboarding shots: name, optional permissions, profile. Cut to an already signed-in account; do not spend time typing passwords. | “I built Stewardie to bring them together in one friendly place. Set up your profile, choose your permissions, and get started.” |
| 0:17–0:27 | Open the space selector, show Our Home and invitation controls. | “Create a private space for your family, friends, or housemates. Invite your people, and keep each group’s plans separate.” |
| 0:27–0:42 | Today: open Pick up groceries, accept it, then mark it done. Show each resulting state. | “Today makes responsibility clear. Someone can ask for help, another person can say, ‘I’ve got it,’ and everyone can see what’s covered and what’s done.” |
| 0:42–0:53 | Choose a mood; open the calendar and Dinner together. | “A quick mood check-in adds a human touch. The shared calendar helps everyone see what’s coming, without searching through messages.” |
| 0:53–1:06 | Moments: dinner photo, enlarged viewer, tap a reaction and show its count changing. | “Moments keeps the good bits alongside everyday life. Add a photo, open it, and leave a little appreciation.” |
| 1:06–1:15 | Space map: select sharing duration, show the active-space label and Stop. Use this shot only if these actions succeed. | “Location sharing is optional, time-limited, and specific to the space you choose. You can stop it whenever you want.” |
| 1:15–1:24 | RevenueCat Test Store purchase on the phone. Label **Test Store · no real charge**. Show the app's actual result; do not substitute a Plus success screen if secure synchronization is pending. | **If activation succeeds:** “RevenueCat powers personal Plus, including unlimited retained task history. Your subscription belongs to you across your spaces.” **If synchronization is pending:** “This is a successful RevenueCat Test Store purchase. Secure account activation is pending while the cloud quota resets.” |
| 1:24–1:30 | Return to Today. End card: Stewardie logo and your public repository address. | “Stewardie. Your people, your plans, your little moments. Built with Flutter, with source available for the Next Gen Award.” |

## Recording and editing

- Rehearse once with a timer. Record short takes for each row, then trim typing, loading pauses, mistakes, and repeated taps. Keep enough footage to show an action and its result.
- Use clear narration; avoid music or effects that obscure speech. Keep captions brief and away from controls.
- Keep the recording focused on the app. No long mascot intros, elaborate promotional sequences, or recreated UI animations standing in for actual interactions.
- Export at 90 seconds and check the opening, action results, narration, and final repository address.
- Reserve at least the final 15–20 minutes before your deadline for upload, processing, and checking the public YouTube/Vimeo link; processing can take longer, so upload as early as possible.

## Recording while cloud quota is exhausted

- Login/onboarding footage can use the normal build if those screens work. Do not imply a successful login if it fails.
- Main-screen footage can use `flutter run -t lib/main_fixture.dart`. Confirm the required sample photos and interactions exist before recording; their presence has not been verified for this script.
- Keep a legible **Local demo · sample data** overlay throughout fixture footage. Do not portray fixture actions as verified cross-device delivery, GPS, push notifications, or purchases.
- If the map sharing shot cannot be recorded honestly, use 1:06–1:15 for the Moments TV viewer instead: “For time together, Moments also has a larger viewing mode, turning everyday photos into something everyone can enjoy.” Confirm this works in the recording build first.
- Keep device footage as the main content. Use mascot art for short title transitions, not as a replacement for functioning app footage. Use owned or appropriately licensed audio and assets.

## Submission checks from the supplied requirements

- Next Gen: active student status and qualifying academic email on Devpost.
- Public, open-source repository with a detectable license, necessary assets, and working setup instructions. Confirm asset redistribution rights before publishing.
- Public YouTube or Vimeo video under two minutes; include actual device footage.
- 1024 × 1024 app icon and at least one 1179 × 2556 screenshot without a device frame.
- The supplied requirements still require RevenueCat to power at least one purchase or RevenueCat Ads. The explicitly enabled October 1 Test Store build completed a device transaction; see `submission/README.md`. Public production purchasing remains disabled, and server-confirmed Plus activation is not verified. Disclose the test environment; this script does not establish competition eligibility.
- Ensure the app functions as shown. Disclosure of sample data does not replace the requirement for a working application.

This file is a proposed recording script, not a claim that the footage, cloud functions, purchases, or submission gates have been verified.
