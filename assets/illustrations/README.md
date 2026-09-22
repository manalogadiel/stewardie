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
