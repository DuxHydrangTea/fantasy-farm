# Unified world interaction

`FarmPlayer` automatically composes `PlayerInteractionComponent`,
`InteractionResolver` and `InteractionPresenter` using `class_name` references.
No scene node-name strings or manually assigned interaction lists are required.
The system covers both merchants, the land sign, food/water troughs, live animals,
mature crops and mature flowers.

## Controls and target selection

Face a target and press **E** (the remappable `harvest` action, or `interact`).
The eligible target must be in range, inside the facing cone and visible through
World-layer collision. The resolver chooses one target by this order:

1. NPC or land sign.
2. Food/water trough.
3. Live animal.
4. Mature crop or flower.

Equal priorities use distance, then a stable instance-ID tie break. An unavailable
high-priority action still consumes E: a full trough cannot accidentally harvest
a crop behind it. Objects behind the player or behind a wall are ineligible.
Merchant reach is 48 world pixels, trough 30, sign/animal 32, crop 20, flower 28.
Crop actions additionally require the correct adjacent farmland cell.

Left-click the visible sprite to choose that exact object. The player finds a
collision-safe standing position, approaches, faces the target and performs its
action once. Explicit clicks retain the selected object even near another target
with higher E priority. Moving animals can trigger route updates. A new click,
keyboard movement, tool use, opening a menu or removing the target cancels a
queued action. An unreachable destination stops movement and reports failure;
it never invokes a different target. Clicking empty ground keeps focus-only
navigation and does not automatically use the selected tool.

NPC clicks open their existing trade menu. The land sign opens the existing
confirmation; arriving or pressing E does not purchase a column by itself.
Animal interaction inspects it and collects stored output only for species using
direct collection. Ground produce retains the existing pickup behavior. Crop
and flower harvests commit on the existing animation impact frame.

## Presentation

One reusable, softly colored outline sprite follows the chosen target. Its
material is separate from the target's original material. Animated frames,
texture regions, flips and offsets are mirrored; shader sampling is confined
to the current atlas frame. The same outline moves between targets, so nearby
objects cannot accumulate competing outlines.

The screen-space badge displays the configured keyboard key and contextual
English/translated action: trade, sell produce, next-column price, current
trough stock, inspect, collect or harvest. Stock and land price update live.
Full troughs and missing feed/can show a reason. While walking, the badge says
`Walking to: …`. Existing independent E labels are suppressed on FarmPlayer.

The badge uses the game's Upheaval theme and independent UI scale, wraps long
text, sizes short actions to their content and stays within the viewport. Its
placement avoids the wallet and animal inspector where space permits, and
reserves space above the hotbar. English and Vietnamese use the existing PO
catalogs; prices use locale-appropriate grouping. These labels do not change
camera zoom or world scale.

## Automatic trough filling

E or direct click searches the whole bag for that trough's configured feed;
no hotbar selection is necessary. It fills to capacity, or as far as available
feed allows. A partial package leaves a per-trough `feed_reserve`, which is used
before opening additional packages. For example, 450/600 plus one 300-unit pack
becomes 600/600 with 150 units retained for later. The reserve can refill the
same trough even after the last bag package has been consumed.

The inventory and retained feed are committed before stock/inventory observers
run, with a reentry guard. At impact, target reach, menu/action state and current
supplies are checked again. Opening a menu before impact spends nothing.
Water searches the whole bag for a watering can and fills the trough completely;
the can is not consumed. Right-click/Space retain selected-tool behavior: whole
feed packages and the configured `water_per_use` amount.

Save schema **8** records `feed_reserve` with each trough. v1…v7 migration adds
zero without modifying the caller's DTO. Validation rejects fractional/negative
values, water reserves and food reserves at or above one package, before any
world mutation. Existing crops, animals, wallet, inventory and land ownership
continue through the previous migrations.

## Ownership and verification

| Component | Responsibility |
| --- | --- |
| `InteractionTarget` | Typed target, priority, reach/line of sight, sprite and contextual text. |
| `InteractionResolver` | E candidates, direct sprite hits, deterministic selection and cached visual bounds. |
| `InteractionPresenter` | One outline and one responsive context badge. |
| `PlayerInteractionComponent` | E/click orchestration, pinned approach, cancellation and action dispatch. |
| `PlayerNavigationComponent` | Collision-aware routes and custom interaction goal validation. |
| `TroughInteractionComponent` | Exact trough command and animation-impact checks. |
| `AnimalTrough` | Supply stock, retained feed and refill transaction. |

`tests/integration/test_unified_interaction.gd` covers priority, facing, walls,
exact clicks, detours, cancellation, unreachable targets, crop harvest, empty
ground, live stock, auto feed/water and translated land confirmation.
`test_trough_refilling.gd` verifies partial-pack conservation and atomic observers;
`test_world_persistence.gd` verifies reserve disk roundtrip, v7 migration and
invalid-reserve rejection. Fixtures use isolated profiles.

## Beehives

Beehives share the trough priority tier. Their badge shows honey progress, ETA,
source and bonuses; ready honey uses Collect. E and direct sprite clicks collect
one jar, leaving ready output intact when the bag is full. Selection also reveals
the 5-tile radius. See [beehives](beehives.md).
