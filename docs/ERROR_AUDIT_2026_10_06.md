# Godot error audit — 2026-10-06

Source baseline: `c28fd54c6bb393897f7c9b6356d8f10f842ffee7`; Godot 4.7.1.

## Repaired production failures

- Explicit Vector2 types in CollapsibleHudMenu fix its parse errors and the dependent MobileHUD compile failure. This was causing repeated Nil errors for expanded/visible and incomplete HUD initialization.
- The two committed splash JPG files are undecodable. Both native splash orientations now use the existing valid Prism Tamer SVG, matching the web loader fallback. Removed the corrupt images and their deployment copies.
- The Prismforge PNG has corrupt/truncated image data. Repaired it by extracting the same fusion character from the earlier Monster_Atlas_44_Godot sheet using built-in imagegen, with true transparent RGBA. The sprite is scaled to its former field height. Destination: assets/original_monsters/prismforge_fusion_repaired.png.
- Removed tracked .godot caches and added the actual .gitignore so clean checkouts rebuild resource imports and class metadata.
- Both CI workflows now check the output for SCRIPT ERROR/ERROR in addition to exit codes and enforce a timeout. Previously a resource smoke run exited 0 despite a failed HUD script compile, and the following test hung.
- Added exhaustive shipped-resource loading and runtime boot/menu/Fusion checks.

Image repair prompt: extract only the upper-right white/gold/red dragon-and-wolf fusion knight from the source sheet; preserve its full body, pose, cape, weapons and pixel-art colors; remove all other sprites and the gradient background; output transparent RGBA without cropping, text or a ground shadow. Built-in imagegen was used.

## Validation

- Clean import and exhaustive loading of shipped assets, resources, scenes and scripts.
- Resource smoke checks, including world scene dependencies.
- Adventure partner regression: 216 assertions, zero failures.
- Current runtime regression: automatic Splash to Login; touch More; outside touch dismiss; Status pause/resume; repaired Fusion frames and skills. 8 assertions, zero failures.

## Older suites are not all green

An exploratory run of every older test scene also found failures outside the active CI suites. They have not been silently disabled or made to pass by weakening gameplay rules. Examples include tests that evolve at level 1/2 instead of the current 11/25/41 thresholds, expect access to inactive-form skill pages, hatch eggs directly in inventory, reference the removed toggle_button or StoryPoints/NextPortal, expect 244 spawners, or use frame-count waits across asynchronous scene changes. Some navigation, timing and stat assertions also failed and need separate investigation; this patch does not certify the historical full suite. The active checks above are the verified scope of this repair. Actual mobile browser rendering/performance has not been tested locally.
