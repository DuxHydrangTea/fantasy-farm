# Farm landscape

`world/farm_landscape.tscn` is an editable, authored decoration scene instanced by
`world/main_world.tscn`. It uses the existing art and preserves the farm, animal
pens, flower pots, and both perennial-tree planting regions.

- `MeadowShade` / `MeadowSun`: subtle grass color patches below gameplay objects.
- `MeadowGrass` / `Wildflowers`: non-colliding animated ground decoration.
- `PondPlants`: animated lily pads grouped along the banks.
- `EdgeStones`: small non-colliding accents in the outer meadow.
- `Landmarks`: woodland clusters, well, hay, nests, benches, pots, signs and supplies.
  Its Y sorting continues through the landscape root into MainWorld. Tree scenes
  keep their existing trunk collisions and wind materials. Solid props have small
  foot collisions; cosmetic creatures have no collision or save state.

Both lower gardens remain available for planting. New props sit in the entrance
strips or outside the garden boundaries. Low grass can appear between tree rows.

## Butterfly flight

`world/butterfly_swarm.tscn` creates 48 cosmetic butterflies in eight colors.
Jittered spawn cells spread them across the entire map at startup. They mix nearby
random wandering with longer journeys; cubic Bezier curves, gentle hovering and
variable wing speeds come from `ambient_flutter.gd` and `butterfly_roamer.gd`.

Each butterfly independently follows ROAM → GARDEN → LEAVING → ROAM. Crossing the
flower garden starts a fixed 30-second visit. Moving between flowers never resets
that deadline. At the deadline it immediately chooses an exit outside the garden,
then resumes its journey. A 300-second cooldown starts at the end of the visit;
crossing the garden during cooldown does not restart the action. All timers use
active gameplay seconds, pause with the world and start fresh on a new session.

The swarm exposes `population`, `roam_bounds`, `garden_bounds`,
`garden_visit_seconds` and `garden_cooldown_seconds` in the Inspector. Butterflies
fly above scenery without collision, gameplay AI, navigation or save state.
The separate zero-speed frog keeps its original static ambient behavior.

The initial layout is reproducible with:

```powershell
& $godot --headless --path . --script res://scripts/setup/build_farm_landscape.gd
```

This overwrites only `world/farm_landscape.tscn`. If editing the generated scene by
hand, keep those edits or update the layout script before rebuilding. The script
does not attach another instance to MainWorld or change player save files.

Run `res://tests/support/landscape_preview.tscn` to inspect the full map and detail
view. It instantiates MainWorld as a child of a preview scene, so WorldPersistence
does not bind the player's save. It checks all 306 tree planting positions, 1,632
farm plots, road tile centers and trough access positions against the new decor,
then runs two seconds of animation/gameplay. Images are written to
`.godot/landscape-overview.png` and `.godot/landscape-detail.png`; diagnostics are
printed with `LANDSCAPE_VALIDATION` and `LANDSCAPE_MOTION`.
