# Full-screen surfaces and iPhone safe areas

October 1, 2026.

- Explicitly enabled edge-to-edge system UI at app startup. Background surfaces still cover the viewport; the status bar remains visible rather than entering immersive mode.
- Kept top navigation inside SafeArea with its existing 12-pixel spacing. Device-reported insets, not a hardcoded island/notch size, determine placement.
- Matched transparent system-bar styling in the regular and no-space shells. Kept the bottom dock above the home indicator using its existing SafeArea.
- Three focused shell tests passed with simulated iPhone sizes 390×844, 393×852 and 430×932, top insets 47/59/62 and a 34-pixel bottom inset. Tests verify full-viewport painting, the selector below the top inset and the dock above the bottom inset. `git diff --check` passed.

These are Flutter layout checks, not a native iOS build or physical Dynamic Island test. Final iOS device verification remains required. No status-bar hiding, platform billing or publication changes were made.
