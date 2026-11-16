# Raised pale grass with grass-covered banks

New independent version created 2026-11-16. The earlier earth-bank version in `docs/raised_pale_grass` and its atlas, TileSet and preview scene are preserved unchanged.

- Atlas: `assets/Tiles/Grass/Raised_Pale_Grass_Turf_Edge.png` (64 x 64, sixteen 16 x 16 Wang tiles).
- TileSet: `tilesets/raised_pale_grass_turf_edge.tres`.
- Preview scene: `tests/support/raised_pale_grass_turf_edge_preview.tscn` (F6).
- Preview: `preview.png`; side-by-side comparison with the old version: `comparison.png`.

The new low raised bank is covered entirely in green turf. A pale upper lip, darker green face and narrow foot shadow convey height. Every atlas pixel is an opaque shade with green as its strongest channel. The normal ground matches the current game's dominant #43894f, using the same single-colour remap as the previous version. The pure lower and upper base tiles match the previous atlas byte for byte; only transition-bank artwork changes. All sixteen corner combinations are available, and the TileSet includes the original five ground variations as source 0 and new transition atlas as source 1. Terrain set 0 / terrain 0 is `Raised Pale Grass Turf Edge`.

PixelLab Pro tileset ID: `159decab-0585-4db9-a73f-a2c2989da774`. Connected lower base: `6b3b2f18-9201-4993-9502-54825a3e5a67`; connected upper base: `1600bc7d-344d-44e9-b6b9-39e832aab52c`. `request.json` and `metadata.json` preserve prompt/settings and the corner-to-bounding-box mapping. Cost: 15 generations, checked against the paid-key balance decreasing from 1290.40 to 1275.40. One paid API key used for this request. No credentials included.

Validation: Godot 4.8 beta3 created the resource and painted the preview via terrain connection; the preview runs headlessly without errors; project lint reports zero errors and zero warnings. The original earth-bank atlas, TileSet, preview scene/image and notes remain byte-identical to their pre-request hashes.
