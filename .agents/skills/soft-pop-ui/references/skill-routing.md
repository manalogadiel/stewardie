# Optional design skill integrations

Repository review date: September 21, 2026. Upstream branches can change. This is an original project integration guide, not a redistribution of upstream skills or a claim that their tooling is installed. Read the installed version before actual use.

## Routing

| Source | Relevant role here | Boundary |
|---|---|---|
| Installed `ui-ux-pro-max` | Focused UX questions, design-system consistency, Flutter guidance | Treat search results as candidates; reject irrelevant landing-page defaults and preserve the approved tokens |
| [Emil Kowalski's skills](https://github.com/emilkowalski/skills) | Interaction and animation craft; select `emil-design-eng` or the relevant motion skill | Adapt intent to Flutter; browser/React/Expo recipes are not native Flutter code |
| [Impeccable](https://github.com/pbakaus/impeccable) | Shape, critique, polish, clarity, and state refinement | Prefer its native guidance where applicable; browser detector results alone do not validate native screens |
| [Taste Skill](https://github.com/Leonxlnx/taste-skill) | Future launch website, marketing composition, reference exploration | Current main skill explicitly excludes multi-step product UI; do not use it as the Flutter app's layout authority |
| [Text-to-Lottie](https://github.com/diffusionstudio/lottie) | Small vector success accents, welcome gestures, or other explicitly requested animation assets | Optional asset-authoring workflow, not a UI framework or automatic clay-image-to-3D animation converter |

Do not load all helpers on every task. For a straightforward screen, project context and one relevant design guide may suffice. Other skills in these repositories require their own scope check; repository membership does not make every skill relevant.

## Source-specific adaptation

### Emil

Reviewed [design engineering entrypoint](https://github.com/emilkowalski/skills/blob/main/skills/emil-design-eng/SKILL.md). Select motion according to the interaction's purpose and repetition. For this app, frequent filtering must remain quick; occasional completion can carry a brief expressive accent. Preserve native gestures and accessibility. Validate interruption and repeat taps in Flutter rather than transferring CSS timing or browser performance claims literally.

### Impeccable

Reviewed [source entrypoint](https://github.com/pbakaus/impeccable/blob/main/skill/SKILL.src.md) and repository overview. Use its distinction between task-operation screens and promotional surfaces. Respect its installed setup/fallback instructions if invoked; a launcher is not required merely to reference this integration guide. Existing project plans already contain context: do not replace them with generic generated PRODUCT/DESIGN files. If tool-specific adapters become necessary, point them to the authoritative plans and keep them synchronized within scope.

### Taste Skill

Reviewed [main skill scope and defaults](https://github.com/Leonxlnx/taste-skill/blob/main/skills/taste-skill/SKILL.md) plus repository overview. The current main workflow is aimed at landing pages, portfolios, and redesigns, with web-stack defaults. For a future marketing site, retain our brand while choosing a page-specific composition. Do not carry React/Tailwind/GSAP dependencies, dramatic layout variance, or marketing typography into the Flutter timeline automatically.

### Text-to-Lottie

Reviewed [text-to-lottie entrypoint](https://github.com/diffusionstudio/lottie/blob/main/skills/text-to-lottie/SKILL.md). When actually authoring an animation, load its player contract and task-specific references and verify in its required official player. Then separately check the exported asset in the app's chosen Flutter renderer; successful Skottie playback is not proof of cross-renderer compatibility. Use a static fallback for reduced motion. Start with simple vector accents. Keep our clay renders as raster assets unless a separately scoped animation treatment is requested.

## Conflict examples

- A helper suggests new fonts or palettes: keep `ui-plan.md` choices unless redesign was requested.
- A helper discourages generic cards: remove redundant containers, but keep the task/moment grouping that makes this timeline understandable.
- A web recipe uses hover: provide a discoverable tap interaction and visible state on mobile.
- A helper suggests dramatic entrance sequences: preserve immediate access to frequent actions and restrained motion.
- A default bans emojis or custom graphics: distinguish semantic mood content and approved custom artwork from functional navigation icons.
- A helper wants a new framework: preserve Flutter and the existing project architecture.

Upstream material is linked rather than copied. If upstream files are later installed or redistributed, retain their applicable licenses/notices. This routing guide does not install those repositories, their binaries, hooks, or runtime dependencies.
