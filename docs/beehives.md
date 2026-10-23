# Beehives, flowers and pollination

Buy a **Beehive** for **1,500 coins** from LaiBuon's **Supplies / Farm supplies**
tab. Move it into a hotbar slot, select it, and left-click nearby ground to
place it. Space/right-click also places at the preview. Select another slot to
cancel the preview. Placement reaches 96 world pixels and snaps to the farm grid.
The ghost footprint/radius turns red for invalid positions. Only a successful
placement consumes one item; purchases use the existing atomic shop transaction.

A hive needs solid ground, unlocked land and an unoccupied footprint. World
collision, actors, pond water and existing crops block placement. Logical cell
occupation immediately blocks farming, including before physics updates. Hives
are permanent in this version; moving/packing them is not exposed.

## Agreed production rules

| Rule | Value |
| --- | --- |
| Radius | 80 world pixels / 5 standard 16-pixel tiles. |
| Wild batch | 86,400 real seconds, one Wild Honey. |
| With an assigned bloom | Work rate ×1.3; a fully pollinated batch takes about 18h 28m. |
| Specialty requirement | One species must supply at least 50% of the complete batch's work. |
| Crop benefit | +10% growth rate inside an actively supplied hive's radius; overlaps never stack. |
| Capacity | One completed batch. It waits indefinitely and never spoils. |
| Restart | Successful collection starts a fresh batch; a full bag leaves the old batch untouched. |
| Sell prices | Wild 150, Sunflower 225, Floral 300 coins. |

Royal Honey is intentionally deferred until rare flowers have their own unlock
rules. All existing Flower 01…10 produce ordinary Floral Honey when qualifying;
their IDs remain distinct for the monofloral threshold. Honey is accepted by the
existing ProduceBuyer quantity/all-produce sale commands.

Sources include watered garden pots that have reached `matures_at`, and mature
farmland sunflowers. Every bloom is assigned to exactly one in-range hive: nearest
first, then persistent hive ID for an equal-distance tie. Within each hive, the
species with the most assigned blooms wins; ties use nearest bloom then species
ID. Flowers are not consumed by foraging. An empty/unwatered pot supplies nothing.
A full hive can still pollinate crops while it retains an assigned bloom.

Progress is earned work, capped at one cycle. Pollinated elapsed time earns ×1.3
work and credits that work to the currently dominant species. Different species
are never pooled to satisfy the 50% threshold. On completion, the most credited
qualifying species fixes the output; otherwise it is Wild Honey. Sunflower maps
to Sunflower Honey, garden species to Floral Honey. Collection-time flowers cannot
change a finished jar. Harvesting a flower keeps earned credit and changes future
work to the new source or wild rate, without resetting the batch.

## Clock and growth integration

`ApiarySystem.advance(timestamp)` splits intervals at flower bloom and crop
maturity boundaries. This applies during normal play and offline restoration:
a flower that blooms after 50 seconds contributes only after that boundary,
not retroactively to the first 50 seconds. Flower planting/watering/clearing and
harvesting synchronize the apiary before changing its source state. Farming
plant/harvest/fertilizer commands synchronize before committing their change.

Only supported crops receive `elapsed * 0.1` of deadline reduction. The boundary
calculation accounts for their earlier completion, so a sunflower can become a
new pollen source halfway through an offline interval. `pollination_reduction`
tracks the reduction already earned; removing coverage stops future acceleration
without undoing it. Fertilizer still removes 20% of the original per-crop duration,
including when pollination has already shortened the deadline.

Boosted crops are refreshed by the apiary and leave the ordinary stage heap
while boosted. Leaving coverage reschedules them once. The system does not append
a new heap ticket for every crop on every clock tick. With no hives it returns
immediately; bee animations never drive gameplay time.

## Components and assets

| Type | Ownership |
| --- | --- |
| `BeehiveDefinition` | Tunable duration/radius/rates, canonical outputs and textures. |
| `Beehive` | Collision, sprite, persistent identity, collection command and context text. |
| `BeehiveProductionComponent` | One batch, work, per-species credit, fixed output and collection guard. |
| `PollinationComponent` | Assigned sources and deterministic dominant species. |
| `ApiarySystem` | Farm clock, exclusive source assignment, interval simulation and placement command. |
| `BeehivePlacementComponent` | Player input and ghost preview. |
| `BeehiveRangeDisplay` | Radius/footprint drawing. |
| `BeeVisualComponent` | Six cosmetic bees; pauses offscreen or in rain. |

`FarmWorld` and `FarmPlayer` compose these types automatically. No actor names
are used to discover hives. `ItemType.PLACEABLE` is appended to preserve existing
enum values. The definition lives at `resources/bees/beehive.tres`; the hive shop
offer and honey prices use the existing shop/produce catalogs.

The hive uses the 16×16 idle/full regions at `(0,0)` / `(16,0)` in
`Bee_Nest.png`. The reusable bee SpriteFrames contain `fly` and `fly_alt`, each
four 16×16 frames at 12 FPS. Six bees use separate flight phases and alternate
wing animations, with 64px free-flight routes in different directions when no
flower source is assigned. Supplied bees follow wider sinusoidal paths toward
the selected source. This visual spread does not change pollination radius or
honey production. They stop animation/process work outside the screen. Only the bee
sprites are hidden: the parent CanvasItem and its screen notifier stay visible,
so moving the camera back wakes all six bees again. Honey uses the
existing jar icon. No animal hunger, thirst, aging or death components are added.

## Interaction, UI and persistence

Hives use the shared outline/badge and the same priority tier as troughs, below
NPC/signs and above animals/crops. E targets the facing hive; a direct sprite
click approaches the chosen hive before collecting. A working badge shows work,
time remaining, source and both bonuses. Ready honey changes the sprite and
badge to `Collect …`. The selected hive displays its radius. UI source text is
English; English/Vietnamese translations use the existing catalogs and UI scale.

Save schema **9** adds `beehives` and per-crop `pollination_reduction`. A hive row
stores persistent ID, local position, work, per-species contributions and fixed
ready item. v1…v8 migration initializes an empty hive list and zero crop reduction
without giving free hives or resetting any existing state.

Validation checks finite bounded work, known pollen species, credit totals,
ready-item consistency, duplicate IDs/cells, placement and crop overlap. All
checks run before clearing/replacing the world. Restore installs raw plant
state at `saved_at`, reconstructs hives, then advances through offline boundaries
once. Repeated same-time loads cannot duplicate work or jars. Fixtures and native
previews remain detached from the player's real profile.

Tests: `tests/unit/test_beehive_production.gd` and
`tests/integration/test_beehives.gd` cover capped production, exact thresholds,
late flowers, mixed pollen, atomic collection, assignment, bloom boundaries,
crop/fertilizer interactions, bought-item placement, click approach, sales,
invalid saves, migration, disk roundtrip and offline replay.
