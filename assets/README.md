# Demo asset inventory

| Asset | Source/license | Use and status |
|---|---|---|
| `fonts/nunito-sans.ttf` | [Google Fonts Nunito Sans](https://github.com/google/fonts/tree/main/ofl/nunitosans); SIL OFL 1.1 in `fonts/OFL.txt` | Bundled variable font; native text with system fallback; no runtime download |
| Material rounded/outlined icons | Flutter Material Icons; [Apache 2.0](https://github.com/google/material-design-icons/blob/master/LICENSE) | Standard functional navigation and actions; semantic labels come from controls |
| `MoodFace` in `lib/core/widgets.dart` | Original project vector drawing | Six 44px faces, 64-unit coordinate system; supporting placeholders, excluded from semantics because every control has a visible label |
| `MemberAvatar` in `lib/core/widgets.dart` | Original project native UI | 26–40px initials on the approved pastel colors; supporting member labels remain visible |
| Camera and space tiles | Native Material icons on flat pastel shapes | Temporary placeholders, not production clay artwork |
| Android/iOS/web launcher images | Generated Flutter scaffold defaults | Development only; replace before distribution |

The reference in `docs/soft-pop-character-reference.png` remains a reference. It is not included as a production image, cropped into controls, or claimed as a completed asset pack. Approved clay artwork and final application branding are still needed.
