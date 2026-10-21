# Crop fertilizer and animal tonic

Buy **Crop Fertilizer (5 coins)** and **Animal Tonic (3 coins)** from LaiBuon →
**Supplies** (the full-size tab is **Feed and boosters**). Prices live in the shop
catalog. Both stack to 99 and are saved in the normal inventory.

Drag a booster into a hotbar slot, select it, face the target, then right-click or
press Space. The item is consumed only on a successful animation impact. Invalid
targets, changed slots, cancelled actions, menus, locked plots, distant animals
and a wall between player and animal do not spend the item. The existing hotbar text line reports success or failures; long messages remain
available as tooltips without overlapping the animal inspector. E retains its normal merchant/harvest/refill behavior.

## Crop fertilizer

Field crops may receive fertilizer **once per planted lifecycle**, and only at
`progress < 0.5` after refreshing growth at the current real timestamp. Exactly
50%, mature plants and already-fertilized plants reject it.

For original planted time P and original deadline M, success sets
`matures_at = M - 0.2 × (M - P)`. This subtracts 20% of the original total duration,
not 20% of the remaining time. The stored per-crop duration is authoritative,
even if its species resource has since changed. Progress refreshes immediately
and the farming growth heap is rescheduled using the new stage deadlines.
Harvesting removes this crop's state; a newly planted crop may be fertilized again.
Potted flowers are separate and do not accept this field-crop item.

## Animal tonic

Before a dose, the actor synchronizes age, needs and production through the current
time, so a new dose never enhances an already elapsed interval retroactively.

- **Juvenile:** once per animal. Halve the maturity threshold from birth (default
  24h → 12h), keeping current age and the full 14-day lifespan unchanged. It may
  become adult immediately if it is already at least 12h old. Earlier juvenile
  time does not retroactively produce goods. Juvenile dosing does not also arm
  a production bonus.
- **Adult:** arm one pending bonus for the next completed production cycle,
  including the current partial cycle. Pending doses do not stack. That cycle
  always yields its normal product, with a uniform **50% chance of one extra
  identical product**. All shipped species normally yield one item, hence the
  boosted cycle's expected output is 1.5. The flag clears on cycle completion,
  even if its bonus roll fails; another adult dose can then be used. Clearing
  does not wait for collection. Existing stock is unaffected.

Hunger, thirst, maturity and death continue to gate production normally. An armed
bonus survives pauses and offline time. A catch-up spanning N completed cycles
returns N normal cycles plus at most one bonus item, without looping over every
cycle. Direct collection, world drops and pond shore delivery share the same
production state. At death an unfinished pending cycle expires with the actor;
completed products remain collectible.

The inspector shows the shortened maturity countdown for treated juveniles and
a **Tonic** marker while an adult bonus is pending; tooltips explain both states. Model IDs and enum values are language-neutral;
labels, hints, error messages and descriptions have English/Vietnamese entries.

## State and persistence

`BoosterService` coordinates inventory and target mutations with a reentry guard;
`BoosterInteractionComponent` owns player targeting, animation binding and feedback.
FarmPlayer wires it by type. Crop, animal growth and production components own
their individual flags, without modifying shared species definitions.

Save schema **v7** adds `fertilized` to crop rows and `juvenile_tonic_used` plus
`tonic_pending` to animal rows. Crop deadlines, ages, lifespan and production
progress remain in their existing fields. Restore applies flags before offline
catch-up. Completed output and consumed flags are captured together. A v1…v6
save migrates to false flags without changing its crops, land, wallet or inventory;
malformed flags and juvenile production bonuses fail preflight before mutation.
No existing profile is reset or manually changed to install this feature.

Tests in `unit/test_boosters.gd` and `integration/test_boosters.gd` verify strict
50% boundaries, original deadlines, one-dose rules, lifetime invariants, both
random outcomes, batched/offline production, inventory reentry, animation impact,
cancellation/slot changes, merchant availability, disk roundtrip and migration.

Bee pollination tracks its earned deadline reduction separately, so fertilizer
still subtracts 20% of the original per-crop total after a bee speed bonus.
This field is persisted by schema 9; see [beehives](beehives.md).
