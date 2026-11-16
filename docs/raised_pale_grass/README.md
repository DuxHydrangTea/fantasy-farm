# Raised pale grass tileset

Created 2026-11-16 with PixelLab Pro, tileset `704a6baa-4a50-4832-a99c-834f816e4880`.

- Atlas: `assets/Tiles/Grass/Raised_Pale_Grass.png`, 64 x 64 pixels, sixteen 16 x 16 Wang tiles.
- Godot resource: `tilesets/raised_pale_grass.tres`.
- Preview scene: `tests/support/raised_pale_grass_preview.tscn` (open and run with F6).
- Preview image: `docs/raised_pale_grass/preview.png`, rendered from the scene's actual terrain placement.

The theme is a low raised grass platform / turf mound, with a lighter pale-green top and a shallow warm-earth bank. The lower field matches the current ground, `assets/Tiles/Grass/Trial/grass_ground_5_variants.png`. The generator's dominant lower-grass colour #397d48 was remapped to the current ground colour #43894f; other generated pixels are retained. Generation used the existing grass palette and style description because PixelLab's Wang generator does not accept local PNG terrain references.

The TileSet includes the five current-ground variants as source 0 and the generated transition atlas as source 1. Terrain set 0 uses corner matching and terrain 0 is `Raised Pale Grass`. Lower corners are empty terrain (-1), allowing the raised terrain to connect over the normal grass base. Paint normal grass on one TileMapLayer and raised terrain on a second layer, as in the preview. `metadata.json` preserves PixelLab's exact corner and bounding-box data; `request.json` records the complete generation prompt and settings. Slice positions came from bounding boxes, not Wang names or original generation-grid positions.

Cost: 15 generations, checked by balance decreasing from 1305.40 to 1290.40. This request used one paid API key; the earlier pond trial used two keys in total, with its free-key failure fallback persisting for this request. No credentials are stored here.

Validation: all sixteen unique corner combinations are present; Godot 4.8 beta3 built the resource and painted the preview via `set_cells_terrain_connect`; the preview scene loads and runs headlessly; project lint has zero errors and zero warnings. The preview paints 111 raised cells with 163 transition/buffer cells over 600 normal-grass cells.
