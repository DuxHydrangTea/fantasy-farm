# Pond water animation trials

## Active version: shoreline waves

`assets/Tiles/Water/Pond_Grass_Shore_Waves.png` is the current texture in `tilesets/meadow_pond_water.tres`. It contains eight horizontal 48 x 80 atlas frames and plays all thirteen original tiles at 5.5 fps with a two-tile horizontal animation separation. Original tile coordinates, terrain data and collision polygons remain unchanged.

Preview: `pond_shore_waves.gif` uses the actual 103-cell pond water TileMap at 2x nearest-neighbor scale, without scene decorations.

Source: `assets/Tiles/Water/Pond_Grass_Standard.png`. PixelLab `animate_image`, job `df0a35b0-a232-468a-ac3b-7ccac94ef6fc`, seed 84296, 2026-11-16. Motion prompt requests narrow cyan waves advancing 1-3 pixels from the shore into the water, then receding and fading, with static grass and camera. Charged: 1 generation. Paid-key remaining balance after completion: 1305.40. This revision used one paid key; two keys have been used over the entire trial, and the original free key was retained after its failed request.

Compositing keeps all original grass and transparent pixels exactly. All original water pixels, including the cyan shoreline, may animate. Generated water is quantized to the original water palette. At tile edges, a shared per-frame colour mapping keeps equivalent source colours consistent across tile joins, instead of freezing the shoreline. The input plus seven generated frames form the eight-frame loop; the final pinned endpoint is omitted. Between 390 and 450 pixels within three pixels of the shoreline change in each generated playback frame.

Validation: Godot 4.7.2 loads all 13 tiles with 8 frames and the correct atlas stride. Project lint: 0 errors, 0 warnings. Grass and alpha match the source in every frame. The standalone meadow TileSet change from the first trial is the texture path. The main-world embedded water atlases were also updated after discovering that the duck/goose pond still used a separate static source. Pond integration tests: 7/8 pass (223/224 assertions). The BayBirch dry-ground assertion also fails against the original HEAD TileSet: both report water source 0 where the test expects -1.

## Previous version: surface ripples

`assets/Tiles/Water/Pond_Grass_Animated.png` and `pond_animation.gif` retain the first trial for comparison. That version froze the shoreline and only animated interior water.

PixelLab job `cb110568-337f-4e3e-b87c-12ced88343f8`, seed 84291, 2026-11-16. Charged: 1 generation. Recorded paid-key balance after that generation: 1307.40.

Integration correction: `world/main_world.tscn` contains two embedded pond atlases. Both now use the shoreline sheet and 8-frame animation. A Godot 4.8 beta3 runtime load confirms the active sources on `Water` (2598 used cells), `FarmLand` (248 used cells), and `MeadowPond/Water` (103 used cells). All terrain, collision, tile coordinates and map cell data compare identically before and after this correction. Project lint reports 0 errors and 0 warnings. The open Godot editor reloaded the corrected scene from disk.
