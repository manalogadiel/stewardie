# Soft Pop clay assets

Generated September 22, 2026 with the built-in image generation tool after approval of the UI redesign. Reference: `docs/soft-pop-character-reference.png`, the user-selected character family. These are new illustrations, not crops of the reference board. No paid API service was configured in the application.

| File | Role | Intended logical size |
|---|---|---|
| `greeting.png` | Blue/yellow/pink greeting trio in Today and Space | 154 × 112 in Today; 140 high in Space |
| `mood.png` | Calm blue companion before a personal check-in | 78 high |
| `calendar.png` | Yellow companion with a small calendar | 70 × 68 |
| `celebrate.png` | Trio celebrating gently in empty states and Moments | 130–180 high |

All are transparent PNGs. Display with contain fitting; do not stretch or crop. Artwork is decorative and excluded from semantics; all actions and meaning have separate Flutter text/icons. No labels or status information are baked into the assets. Original images are preserved at generation resolution; delivery optimization can follow native profiling.

## Prompt record

Shared direction: preserve the approved sky-blue, butter-yellow and soft-pink rounded clay characters, matte material, tiny charcoal faces, diffuse upper-left lighting, restrained contact shadows, transparent background, no text, UI, watermark, baked-in panel or scenery. Avoid the reference's red decorations and unrelated props. Keep silhouettes legible at small sizes.

- Greeting: compact waving trio, sky blue left, yellow middle, pink right; friendly faces, small blue sparkle, no floor/background/pot/camera.
- Mood: one calm blue character, quiet expression and hand at chest, compact seated pose, no emotion-ranking or reward cues.
- Calendar: one yellow character holding/accompanying a tiny cream desk calendar, small blue marks without readable letters or numerals.
- Celebration: the trio with gently raised arms, a small butter star and blue sparkle, soft friendly celebration with plenty of clear space around the figures.

Reviewed each generated output and then actual Flutter compositions on off-white surfaces at small/large phone sizes. Corner alpha was checked. No external brand/character source was introduced beyond the approved local reference. Further user art-direction review and production asset approval remain available before launch.

## Six mood poses — September 23, 2026

Built-in image generation, reference-based generation mode using the existing approved `mood.png`. No application API key or paid service was enabled. Calm reuses that original; the five new transparent assets are `mood-happy.png`, `mood-tired.png`, `mood-overwhelmed.png`, `mood-sad.png`, and `mood-excited.png`. Today displays the selected pose at 92 logical pixels high, and the mood chooser uses 84px artwork with separate labels.

Shared prompt direction: preserve the exact sky-blue clay character identity and proportions from the reference; centered, full seated character with consistent framing and visual scale, matte clay texture, diffuse upper-left lighting, restrained contact shadow, generous transparent margins and true alpha. No typography, UI, floor, background or extra characters.

Pose prompts: happy has a gentle open smile and relaxed raised hands; tired has sleepy eyelids, a small yawn and relaxed shoulders; overwhelmed has a slightly worried expression and hands near cheeks without alarming effects; sad has a quiet downturned expression and tucked posture; excited has bright eyes, raised arms and one restrained blue sparkle. Each generated result was visually inspected before integration. Emotion names remain visible text and are not inferred from color.

## Butter and Rose mood variants — September 23, 2026

The built-in image generation tool edited each corresponding approved blue pose as a reference image. The 12 transparent PNGs are `mood-butter-{calm,happy,tired,overwhelmed,sad,excited}.png` and `mood-rose-{calm,happy,tired,overwhelmed,sad,excited}.png`. This was local asset creation; no image-generation API or paid app service was configured. Flutter selects an existing pose asset by mood and color rather than applying a flat runtime tint.

Shared reference-edit prompt: “Use case: precise-object-edit. Asset type: transparent PNG clay mascot pose. Recolor only the sky-blue clay body to buttery yellow [or soft pink]. Preserve the exact pose, proportions, matte texture, shading, upper-left highlights, face, sparkle, transparent margins and contact shadow. No UI, text, background or other character.” The reference for each edit was its matching blue mood file. Selected outputs were visually inspected for consistent clay shading, pose and framing; final production artwork review remains open.

## Login wave (September 24)

`welcome-wave.gif` and its reduced-motion still `welcome-wave.png` are original code-rendered clay-style illustrations from `WelcomeWavePainter` in `lib/online/login_scene.dart`. `tool/render_welcome_asset.dart` renders 32 frames; no external image or paid service is used. This is shaded 2D artwork, not a rigged 3D model. Existing approved illustrations remain unchanged.

## Single-character 3D login (September 24 follow-up)

`login-3d-still.png` and five `login-3d-*.gif` actions come from the original articulated ellipsoid model and ray tracer in `tool/render_login_3d.py` (NumPy/Pillow). These are rendered 3D geometry, not the old 2D painter or rigged reference screenshots. Five 48-frame clips at 70 ms/frame return to the same neutral pose; Flutter pauses and blends between actions. Original approved Today/Moments illustrations are unchanged. No third-party model or paid rendering service was used.
