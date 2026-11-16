# Organic grass terrace redesign

Updated and integrated 2026-11-16. User requested upper grass only about ten percent lighter than existing ground, and winding pond-like banks instead of straight/square outlines. The previous pale grass variants and their TileSets remain unchanged.

## Current assets

- `assets/Tiles/Grass/Raised_Grass_Organic_Earth.png` and `tilesets/raised_grass_organic_earth.tres`.
- `assets/Tiles/Grass/Raised_Grass_Organic_Turf.png` and `tilesets/raised_grass_organic_turf.tres`.
- The existing main-world instance `RaisedGrassTerraces` still points to `scenes/objects/outdoor_decor/raised_grass_terraces.tscn`, which now uses these new TileSets and revised organic footprints. Four turf-edge patches and two earth-edge patches remain.

## Generation and self-review

Three PixelLab Pro calls were reviewed. Earth A had the best winding banks, but its raw top fill matched the actual game ground. Earth B used a revised prompt and reduced palette to force the exact ten-percent colour difference; it produced almost identical dark upper and lower fills, so it was rejected. Earth A was retained after deterministic role-palette calibration: raw lower #397d48 becomes current field #43894f, raw upper #43894f becomes #4a9757. Highlights and bank detail remain as generated. This achieves the requested controlled contrast without relying on the model's numerical colour interpretation. The connected turf version reuses Earth A's upper/lower base tiles and receives the same calibration.

Upper main RGB is (74,151,87), versus field (67,137,79), approximately 1.10 times each channel. Mean upper-tile HSL lightness, including its sparse strokes/shadows, is 1.0971 times the plain ground's HSL lightness. This is the metric used for “about ten percent lighter”; it is not a ten-percent linear-luminance claim. The old upper fill was #8cbd75 and much lighter.

Generation settings: roundness 0.98, raggedness 0.85, boundary amplitude 0.3, transition height 0.25, 16px tiles. The upper-surface edge profiles on four pure edge tiles vary 4–7 pixels; the previous tiles varied by about one pixel. The longest flat runs decreased from 7–8 pixels to 2–4 pixels. Rounded concave/convex corners, short lobes and inward nicks were reviewed in native world renders. Coarse world footprints were also reshaped to stagger their contours, reducing the rectangular appearance. The two tight minor patches remain small to preserve clearances.

Raw candidates, the rejected prompt and rejected metadata are in `candidates/`; selected prompts and metadata are alongside this note. Exact job IDs and evaluation results are in `review.json`.

## Validation and images

`before_after.png` compares the same captured world coordinates before and after for both bank styles. `overview_after.png` shows the complete current world. Individual regional crops and `world_after.png` are native Godot/OpenGL captures from the isolated review project, without personal save changes.

Actual-world integration check: six nonempty layers, correct atlas textures, four turf and two earth, no new runtime scripts or collision layers. Every final painted tile stays at least 32 px clear of roads/water and 16 px clear of plaza/garden/forecourt tiles. `validation.json` records the measurements. Project lint: zero errors and zero warnings. The world rendered successfully, and Reload Saved Scene was performed in the user's open Godot editor.

Cost: 45 generations across three calls, one paid API key used this request, paid balance after completion 1230.40. No credentials are stored here.
