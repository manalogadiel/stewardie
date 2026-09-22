# Asset inventory

| Asset | Source/license | Use and status |
|---|---|---|
| `fonts/nunito-sans.ttf` | [Google Fonts Nunito Sans](https://github.com/google/fonts/tree/main/ofl/nunitosans); SIL OFL 1.1 in `fonts/OFL.txt` | Bundled variable font; native text with system fallback; no runtime download |
| Material rounded/outlined icons | Flutter Material Icons; [Apache 2.0](https://github.com/google/material-design-icons/blob/master/LICENSE) | Standard functional navigation and actions; semantic labels come from controls |
| `MoodFace` in `lib/core/widgets.dart` | Original project vector drawing | Six 44px faces, 64-unit coordinate system; supporting placeholders, excluded from semantics because every control has a visible label |
| `MemberAvatar` in `lib/core/widgets.dart` | Original project native UI | 26–40px initials on the approved pastel colors; supporting member labels remain visible |
| `illustrations/*.png` | Newly generated from the approved local reference; [provenance and prompts](illustrations/README.md) | Transparent greeting, mood, calendar and celebration companions used in the local redesign |
| Android/iOS/web launcher images | Generated Flutter scaffold defaults | Development only; replace before distribution |

The reference in `docs/soft-pop-character-reference.png` remains a reference; it is not cropped into controls. The first clay asset pass is implemented and reviewed in Flutter captures. Final application branding, launcher artwork and launch asset approval remain outstanding.
