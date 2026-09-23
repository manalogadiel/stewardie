# Floating header, person-aware cards and mood colors

Implemented locally September 23, 2026 after approval of the [follow-up plan](top-navigation-person-mood-plan.md). This builds on the [photo/Moments slice](ui-polish-media-verification.md). No paid service or online account was enabled.

## Delivered

- Removed the reserved AppBar. Today paints its light-butter `#F8E7B0` card behind the fixed, centered space-selector capsule and circular Inbox button; the surrounding overlay is transparent. Moments and Space inset their scroll content below those controls. A transparent gap passes scrolling to the page.
- Calendar headings and scope copy follow Everyone, Me and the selected member. Compact names prefer an explicit preferred name, otherwise the first word of the fixture display name. Measured ellipsis keeps the noun visible and full names remain available to accessibility services.
- Everyone/Me show the current user's mood. Another member shows that person's current shared check-in, color and detail sheet without edit controls; missing or expired check-ins show an explicit empty state. The local repository also rejects writes to another member's mood. Alex and Sam have seeded check-ins for review; they are fixture data, not remote updates.
- The current user can choose Sky, Butter or Rose independently of the six emotions. The color changes the shaded clay pose and pale mood-card tint. Edit restores the saved color, cancellation discards a draft, and removal returns the next composer to Sky. The 12 new pose variants and generation prompt are recorded in the [asset manifest](../assets/illustrations/README.md).

## Verification

Flutter 3.47.4 / Dart 3.13.3 on Windows. `dart analyze` reported no issues. The full Flutter widget suite with `CAPTURE_DEMO=true` passed **47 tests** after the layout correction. The web release build and Android debug APK build both passed. The web build emitted its existing Cupertino icon-font warning. Focused tests cover transparent-gap scrolling, Everyone/Alex/Jo/Me cards, read-only member mood, color save/cancel/remove, fixed local write permissions, long-name ellipsis and 200% text clearance. Existing calendar, task, photo and navigation regressions passed in the same suite. The rendered Today capture was reviewed at 360px and 430px; the new Alex and Butter views and 200% header were also reviewed.

| Rendered review | Image |
|---|---|
| Today, 360px | [today-small.png](floating-mood-review/today-small.png) |
| Today, 430px | [today-large.png](floating-mood-review/today-large.png) |
| Alex's mood/calendar | [alex-mood.png](floating-mood-review/alex-mood.png) |
| Butter color composer | [butter-composer.png](floating-mood-review/butter-composer.png) |
| 200% text/header clearance | [large-text.png](floating-mood-review/large-text.png) |

Calculated contrast for charcoal `#202633` on the Today card is **12.30:1**; electric blue `#244BFF` on that card is **4.84:1**. The card is differentiated from the warm canvas by hue and composition rather than a high-contrast boundary. These are token calculations, not a device display measurement.

The captures are Flutter widget renders with fixture members and simulated display sizes. They do not verify a physical notch/status bar, screen-reader traversal, live camera, cloud sync, cross-device mood delivery or native performance. Moods and calendar plans still reset when the local app session restarts; accepted tasks/photos have the separate local persistence described in the earlier verification. Android/iOS device checks and production art approval remain open.
