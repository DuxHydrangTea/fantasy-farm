# Six raised grass terraces in the main world

Implemented 2026-11-16 from the approved six-zone proposal.

`world/main_world.tscn` instances `scenes/objects/outdoor_decor/raised_grass_terraces.tscn` as `RaisedGrassTerraces`. The decorative scene contains six static TileMapLayer children. Its inherited z-index is -2, above the normal grass and behind trees, actors and roads. Four patches use `tilesets/raised_pale_grass_turf_edge.tres`; two use `tilesets/raised_pale_grass.tres`. No new PixelLab generation was needed.

## Validation

- The real main-world scene loads all six patches with the expected atlas textures.
- No new scripts, physics layers or collision shapes; current navigation remains walkable.
- Every final painted cell, including terrain transition cells, stays at least 32 px from all road/trail tiles and water tiles.
- Fountain garden, shop forecourts and worn-path tiles have an additional 16 px clearance.
- Gò 4 was reduced after visual inspection to preserve the entire fountain garden floor. Gò 5 is a very small ridge because it lies in a narrow strip between the road and river.
- The original world file is unchanged apart from one PackedScene resource reference and one child instance; productive grids and existing object placements are preserved.
- Project lint reports zero errors and zero warnings. Native OpenGL rendering of the real world completed without errors in an isolated user-data project. The open Godot editor reloaded main_world.tscn from disk.

## Patches

- NortheastTurf: turf, 108 rendered tiles; clearances {'paths': 32.0, 'plaza': 16.0, 'water': 496.0}
- StorageSouthEarth: earth, 103 rendered tiles; clearances {'paths': 32.0, 'plaza': 789.855712890625, 'water': 96.0}
- PondWestTurf: turf, 62 rendered tiles; clearances {'paths': 32.0, 'plaza': 97.3242034912109, 'water': 32.0}
- FountainNorthwestEarth: earth, 30 rendered tiles; clearances {'paths': 32.0, 'plaza': 16.0, 'water': 304.0}
- SouthwestRiverTurf: turf, 21 rendered tiles; clearances {'paths': 32.0, 'plaza': 1282.49755859375, 'water': 32.0}
- CampsiteEastTurf: turf, 69 rendered tiles; clearances {'paths': 32.0, 'plaza': 16.0, 'water': 272.0}

Images: `overview_after.png` (whole world), `before_after_regions.png` (six before/after close-ups), and individual region captures. `validation.json` records the actual-world clearance checks. The original proposal remains in `docs/grass_second_tier_proposal`.
