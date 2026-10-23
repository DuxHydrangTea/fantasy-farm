# Farming

Choose a hotbar slot with **1–6** or by clicking it.
Scroll up to zoom in on the farm, or down to zoom out; this does not change the selected slot.
Face the adjacent tile and **right-click** or press **Space** to use the selected tool.
Left-click empty ground to approach and face that point. Click a mature crop, flower,
NPC, trough or animal to approach and interact with that exact target. **E** uses
the single highlighted target in front of the player, with NPC/sign > trough >
animal > harvest priority. See [unified interaction](unified_interaction.md).
Movement keys, tool use and opening the inventory cancel the route.
Number keys select a slot without immediately using its tool.
The change happens once on animation frame 3. Changing state before impact cancels it.

The four-corner highlight follows the adjacent farming cell in the facing direction.
It stays hidden on ordinary grass, paths and unmarked/border tiles. White means
the selected field tool can affect the plot; red means a known plot is blocked,
locked or in an invalid soil state for that tool. Empty slots, axes, flower seeds
and tree saplings hide the soil highlight. Focused objects (including mature crops,
flower pots and beehives) use their own outline/marker without a duplicate soil square.
During Tool/Water the marker
stays on the same cell as the action, including after impact until the animation
finishes. It hides outside the Ground map or when Player runs without a farming world.

The marker uses `resources/ui/soil_focus.tres`: atlas region `(144, 144, 32, 32)`
from `assets/Ui/Sprite sheet for Basic Pack.png`, scaled to the actual tile size.

`FarmLand` is the permission layer and stays in place. `DrySoil` is the continuous
tilled bed. `WetSoil` overlays watered cells, keeping the bed connected where wet
and dry cells meet. Both soil layers use their existing terrain set 0 / terrain 0.

## Permissions in TileSet Custom Data

The `FarmLand` TileSet has four boolean custom data fields:

| Field | Meaning |
| --- | --- |
| `can_till` | Allows changing an untilled cell to dry soil. |
| `can_water` | Allows watering dry soil. |
| `can_plant` | Allows planting on dry or wet soil. |
| `blocks_farming` | Blocks tilling, watering and planting. |

The existing interior FarmLand tile `(1, 6)` enables the three permissions.
Unmarked grass, empty cells and terrain border tiles deny farming by default.
Paint the FarmLand terrain to expand the allowed region.

Custom data belongs to a **tile definition**, so changing a flag affects every
placement of that atlas/alternative tile. For only one protected region, paint
an alternative tile with permissions disabled, or use a separate TileMapLayer
whose placed tiles have `blocks_farming = true`. Any sibling tile layer can carry
that flag; the layers must belong to the same world as `FarmingController`.

Physics bodies on the controller's `obstacle_mask` (default layer 1) block actions
in their occupied tile area; this covers existing tree trunks/building colliders.
For a larger protected footprint, paint blocking tiles under the object.
Objects without colliders can also call `set_cell_occupied(cell, true)` and clear
it when removed. Placement code should check `can_plant(cell, actor)` before planting.

Crop placement and timestamp growth are implemented; see [crop growth](crop_growth.md).
Moisture decay and saving soil between game sessions are not yet implemented.

## Tests

Run all unit and integration tests from the GUT panel, or:

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

`tests/unit/test_farming_rules.gd` tests permissions and soil transitions.
`tests/integration/test_farming.gd` tests real terrains, four action directions,
animation impact/cancellation, colliders and transformed maps.

## Farmland ownership

MainWorld's 48 × 34 planting rectangle starts with the rightmost column unlocked.
Locked plots deny farming actions until purchased at the land sign with E.
See [farmland expansion](land_expansion.md) for layout, prices and save migration.

## Fertilizer

Crop Fertilizer can be used once before 50% growth to reduce the original total
crop duration by 20%. See [boosters](boosters.md) for targeting and persistence.

## Bee pollination

Crops within 5 tiles of a hive with an assigned bloom grow 10% faster. Multiple
hives do not stack. Earned acceleration persists when the source disappears;
fertilizer still uses the original duration. Mature sunflowers also supply pollen.
Placed hives occupy their cell and prevent farming under the hive. See
[beehives](beehives.md).
