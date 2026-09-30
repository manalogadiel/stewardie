# Soft Pop sound expansion — implementation and verification

Implemented locally on October 1, 2026 after approval of the [sound expansion plan](soft-pop-sound-expansion-plan.md). Audio measurements and local checks do not verify physical-device perceived loudness, silent/DND behavior or iOS compilation.

## Changes

- Replaced the three quiet synthesized cues and added eight original deterministic warm bell/clay cues. The generator produces mono 44.1 kHz, 16-bit PCM assets mirrored into Flutter, Android raw resources and the iOS bundle. Short attacks and squared fades begin/end at zero; mastering targets −14 dBFS RMS subject to a −3 dBFS peak ceiling.
- Android preloads ten action cues into a single-stream SoundPool. Gain defaults to 0.8, follows the saved app volume, checks ringer/DND state, stops previous playback and stops on pause/sign-out. Notification playback remains OS-owned; the existing `stewardie_updates_clay` channel ID is retained. New resource URIs use the stable resource name `/raw/notification`; existing channel settings are not rewritten.
- iOS uses prepared AVAudioPlayer instances with adjustable gain and an ambient audio session. Only foreground actions play; playback stops on resigning active/sign-out. Xcode bundle resource entries cover all eleven WAVs. This integration is not compiled or device-tested on Windows.
- A typed dispatcher captures the initiating account and foreground generation before an operation. Late responses after account switches or background/resume cannot play. Account-scoped durable operation receipts deduplicate concurrent/repeated acknowledgements and survive restart. Reaction pops have a 200 ms cooldown and yield to confirmation/attention cues. A presented foreground notification stops/suppresses app cues for 800 ms.
- Account settings contain App sounds, a compact volume slider with an explicit preview, optional reaction pops and optional failed-save feedback. Reactions and attention default off; app sounds default on at 0.8. Sembast persists preferences per Firebase UID on this installation; account changes reload independently and unreadable settings fail quiet. Preferences do not synchronize across devices. No previous app-sound opt-out existed in the inspected runtime; stored explicit false values are preserved.
- Connected confirmed completion, first foreground task/calendar outbox acknowledgements, profile name/photo changes, accepted create/join, mood check-in, published photos and live-sharing start. Approval-pending joins have no success cue. Outbox/photo retries and restored queues do not retain a sound intent; selecting/queueing a photo does not chime. Task-photo publication is limited to the initiating uploader's newly published photos. Optional reaction feedback is immediate and does not claim server confirmation. Failure cues supplement existing errors and never change operation success.
- User stop feedback follows local collection cancellation without waiting for the server. Automatic expiry and account teardown stop quietly; visible pending server cleanup remains intact. Ordinary navigation, map movement, refresh, synchronized member changes and background operations stay quiet.

No new dependency, paid service, billing activation, backend deployment or publication was needed. Flutter web/desktop have no native audio implementation; unavailable playback remains harmless.

## Measurements

Before changing the files: capture peak −16.56 / RMS −28.98 dBFS; notification −14.71 / −26.12; success −14.60 / −26.12. Android gain was 0.4.

| Cue | Duration (s) | Peak dBFS | RMS dBFS |
|---|---:|---:|---:|
| notification | 0.70 | −3.00 | −14.34 |
| success | 0.50 | −3.00 | −14.32 |
| capture | 0.20 | −3.00 | −14.21 |
| saved | 0.28 | −3.63 | −14.00 |
| moment_shared | 0.42 | −4.24 | −14.00 |
| space_ready | 0.50 | −3.05 | −14.00 |
| mood_checked_in | 0.22 | −3.00 | −14.55 |
| location_start | 0.32 | −3.03 | −14.00 |
| location_stop | 0.28 | −3.17 | −14.00 |
| reaction_pop | 0.12 | −4.83 | −14.00 |
| attention | 0.26 | −4.32 | −14.00 |

Run `dart tool/generate_soft_pop_sounds.dart` to reproduce the assets and measurements. RMS alignment is not evidence of perceptual loudness parity; device listening remains required.

## Local verification

- Focused Flutter suite: **32 tests passed** across sound_feedback_test, location_cache_test, cloud_media_framing_test, 
otification_identity_test, calendar_test, 
eview_repairs_test and 	heme_contrast_test.
- New behavioral coverage includes concurrent/restart deduplication, persistent account opt-out/volume isolation, stale foreground/account responses, optional reaction/attention defaults, cooldown/confirmation priority, notification suppression, harmless native failures, first outbox acknowledgement and silent failed-save retries.
- Every generated WAV matches its deterministic source and both native copies byte-for-byte. Tests verify format, peak ceiling, RMS range and smooth zero endpoints.
- Android :app:compileDebugKotlin --offline: **passed** using installed Microsoft JDK 21. Existing dependency/deprecation warnings remain; no release signing or deployment was performed.
- Inspected the new panel renders at 360 × 780, 430 × 780 and 360 × 780 at 200% text, including preview and persisted App sounds toggle interaction. No clipping/overflow was observed. Existing theme contrast checks passed. These are isolated Flutter widget renders at uild/review/sound-settings-*.png.
- iOS project inspection confirmed all eleven WAV resource registrations and valid 24-character Xcode identifiers; this is not an iOS build.
- git diff --check: passed. Final whole-project Dart analysis: **0 errors, 0 warnings**, with 86 informational style diagnostics remaining.

## Remaining release gates

- Listen on physical Android/iOS devices at low/medium/high system volume and with headphones. Compare timbre/perceived loudness and tune sample mastering together with gain.
- Compile/run the iOS integration on macOS. Exercise silent switch, Focus/DND, other audio, camera permissions/capture and audio-session interactions; no iOS parity claim is made from source inspection.
- Verify foreground/background/terminated Android and APNs notification presentation separately. Check clean installs and existing OS channels, including old numeric resource URIs, muted/custom-sound channels, quiet hours and recipient settings. App volume never controls notification-channel volume or raises global volume.
- Exercise real two-device task/calendar saves, mood updates, accepted/pending joins, uploads/publication, account switching and location shutdown with offline/server delays. Tests use local fakes; they do not verify Firebase/Supabase delivery or native GPS collection.
- Review the complete account sheet with native safe areas/keyboard, screen readers and large text. The new sound panel has isolated widget renders, not a physical-device full-sheet capture.
