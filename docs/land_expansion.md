# Farmland expansion

The measured planting area in MainWorld is **48 columns × 34 rows = 1,632 plots**,
with 16 × 16 px cells, coordinates x=9…56 and y=19…52 (inclusive).
Only this rectangle participates. The one-cell soil border, fences, animal pens
and flower garden keep their existing rules.

A new game owns the rightmost column (x=56): **34 plots**, not the six plots
in the original proposal. The next locked column has a wooden sign at its top.
Walk within 32 world pixels and press **E** (or the remapped interaction action).
Clicking near the sign uses the normal focus navigation; E opens the purchase
confirmation. Cancel/E/Esc leaves coins and land unchanged.

Locked plots retain their normal dry FarmLand tile, with one transparent weed
sprite per cell, and deny tilling, watering, planting and harvest. The two weeds
from `Outdoor_Decor.png` (16 × 16 regions at (64, 336) and (64, 352)) alternate
in a checkerboard anchored to map coordinates. There is no green ground overlay.
They remain walkable. Confirming a purchase unlocks one complete column from
right to left, debits WalletComponent once and reveals its 34 plots from top to
bottom over 0.85 seconds. The sign moves to the next column after the reveal,
and disappears after the last purchase. Each purchase needs a fresh confirmation.

## Prices and economy

The first paid column costs 15,000 coins. The c-th purchase costs
`round(15,000 × c^1.8)`, with **c = 1…47** (the starting column is free).
All prices and wallet values are integers. Insufficient funds, stale offers,
out-of-range interaction and reentrant purchases cannot partially commit.

This exact formula totals **265,237,379 coins**, with a final column price of
**15,341,485 coins**. It does **not** produce the proposal's ~50 million total or
~4.5 million final price on the actual 48-column map. Neither the one-year
completion target nor a universal 250-coin crop price is introduced here;
produce trading retains its existing catalog. Rebalance the price rule explicitly
if that time/economy target is needed.

## State, wiring and saving

- `LandExpansionState` owns the fixed layout, contiguous ownership and atomic
  purchase command. It has no dependency on scene/UI nodes.
- `LandExpansionComponent` renders alternating weeds, the sign and clearing animation.
- `LandPurchaseUI` uses TradeMenu's input lock and UIScaleComponent, English source
  messages and EN/VI translations. It supports the 500 × 400 game window.
- `FarmWorld` composes and assigns the typed components automatically;
  FarmingController checks ownership along with its existing permission/collision
  rules. No farming TileSet definitions are modified.

Since save schema **v6**, the snapshot stores `land_columns` (integer 1…48) with inventory, soil and
wallet in the same snapshot. Loading restores ownership before soil/crops,
closes any open menu and cancels an unfinished reveal. A v6 snapshot containing
soil in locked plots is rejected before changing the world.

Version 1…5 migration preserves existing money, items, crops and tilled soil.
It opens enough contiguous columns from the right to include every previously
tilled plot, without charging money or modifying the caller's snapshot. An empty
old farm starts with one column; a fully planted old/debug farm retains all 48.
No existing profile is reset or edited as part of installing this feature.

Tests: `tests/unit/test_land_expansion.gd` and
`tests/integration/test_land_expansion.gd` cover the measured map, ownership,
prices, atomic/reentrant commands, sign interaction, cancellation, tool guards,
reveal, disk roundtrip, migration, corrupt saves and modal cleanup.

## Unified sign interaction

The sign participates in the highest priority tier alongside NPCs. Face it and
press E, or click its sprite to approach and open confirmation. One outline and
a floating badge show the next column price with locale-aware grouping before
opening a menu. This alone never spends coins. See
[unified interaction](unified_interaction.md).
