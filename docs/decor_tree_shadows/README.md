# Four decorative tree shadows beside the meadow pond

Implemented 2026-11-16 for the exact four trees in the user's screenshot. They are decorative world trees, separate from the fourteen perennial TimberTree definitions updated earlier.

`world/main_world.tscn` now instances `scenes/objects/outdoor_decor/decorative_tree_shadows.tscn` as `DecorativeTreeShadows`. It adds four static Sprite2D ground shadows, reusing the Big Oak-style pure black alpha-40 texture. The layer uses z-index -1 and nearest texture filtering, above ground and below tree artwork. No runtime scripts, collisions, tree textures or existing object placements changed.

Anchors were computed from visible opaque feet, including the 4px TileMap grid and each Crown sprite's frame/offset:

| Tree | Existing anchor | Visible root world point | Shadow size |
| --- | --- | --- | --- |
| Red maple | Tree cell (473,208), OakStyle/maple_3.png | (1894,857) | 40x24 |
| Golden birch | Tree cell (488,221), OakStyle/birch_3.png | (1954,909) | 35x21 |
| Green oak | EastMeadowDecor/MeadowOak | (2032,816) | 47x29 |
| Willow | EastMeadowDecor/SouthShade | (2032,884) | 42x26 |

The root shadow centre is shifted upward by the Big Oak reference proportion, retaining a full thick oval beneath the roots. Every sprite records its corresponding world anchor in metadata. When moving these static trees later, move the corresponding shadow too.

Validation: structured Godot scene instantiation generated the main-world insertion; only its PackedScene reference and child instance were merged, preserving all existing scene data. Project lint reports zero errors and zero warnings. The real world rendered successfully through Godot/OpenGL in an isolated user-data project. `before.png`, `after.png` and `before_after.png` show the same daytime camera view as the supplied nighttime location. The open Godot editor reloaded the main-world scene.
