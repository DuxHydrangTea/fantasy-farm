# Tests

Visual motion reuse is covered by `tests/unit/test_visual_motion_component.gd`:
custom pivots, transformed parents, animated animal visuals, collision/flip preservation,
optional wind materials and component removal/reset. Crop integration remains in
`tests/unit/test_plant_motion.gd`.

Run GUT from its Godot editor panel, or from the project root:

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

`.gutconfig.json` discovers `test_*.gd` under `tests/unit` and `tests/integration`.
Unit tests cover movement, facing and state transitions. Integration tests inject
physical keyboard events and verify movement, action animation completion and
camera behavior at Full HD. Input and scene instances are cleaned up per test.

Improvement coverage includes bounded navigation sampling and persistent grid reuse,
input remapping and unrelated shortcuts while inventory is open, growth deadlines
and smooth focused progress, one-frame animation impacts, and background save IO
(responsive frames, immutable DTOs, backup recovery and external-write conflicts).
The resource audit is `python scripts/maintenance/audit_resources.py`.

Farming tests reuse the actual map's `FarmLand`, `DrySoil` and `WetSoil` TileSets.
They cover custom permissions, blockers, terrain joins, soil transitions and
animation impact timing. See [farming](../docs/farming.md) for painting rules.

Hotbar tests cover click/number-key selection, wheel input preserving selection, empty slots, Space/right-click use,
input consumed by UI, action locking, matching soil focus and layout at Full HD,
720p and 640×360. Tool selection has separate unit tests.
Camera tests cover smooth wheel zoom, rapid steps, zoom limits and viewport resizing,
inventory/UI input blocking, unchanged HUD size and click-focus coordinates after zoom.
Click-focus tests cover detours around collision, dynamic obstacles, unreachable targets,
nearby/collidable focus points, cancellation and idle animation when blocked.
Animal focus tests cover hover/facing handover, holding idle, automatic resumption,
waking from rest/sleep, releasing trough reservations, and deferred shore delivery.
Lifecycle tests cover the real 24-hour maturity/14-day lifetime defaults, final
productive intervals, starvation, death during a trough callback or while swimming,
and saves captured at death/offline death without respawning actors or duplicating output.
Animal trading tests cover all seven species in the real farm, pen capacity and collision,
batch atomicity, new purchase ages, individual resale, wallet overflow, reentry, death at
checkout and purchase/sale persistence without respawning sold animals.
Farming tests verify that approaching an off-center click still focuses the correct cell
and waits for manual tool use.

`farmer_bob_test.gd` is the earlier standalone smoke test; it is excluded from
GUT discovery and can still run with `godot --headless --path . -s tests/farmer_bob_test.gd`.

## Cửa hàng và ví tiền

`unit/test_shop_service.gd` kiểm tra mua nguyên giao dịch, thiếu xu, đầy túi, số lượng/giá sai, reentry và đủ 34 mặt hàng. `integration/test_shop.gd` kiểm tra E, modal, nhóm hàng, lời cảm ơn sau đóng, giải phóng lock khi xóa NPC và layout Full HD. Save repository/persistence kiểm tra migration v3→v4 và file roundtrip số xu sau mua.

Regression sức chứa: `test_crops.gd` bao phủ cả 22 loài qua animation impact; `test_pickup_feedback.gd` bao phủ 7 sản phẩm động vật và tình huống trứng còn gộp được nhưng sữa/lông không có slot. `test_save_repository.gd` kiểm tra v4→v5 mở rộng 24→64 ô không đổi slot cũ/coins/hotbar và không migrate lặp.

Localization tests cover the English default, live English/Vietnamese switching
in inventory, hotbar, wallet, generated shop cards and individual animal sales,
checkout selection retention, translated backend errors, catalog placeholders
and Vietnamese glyph coverage through the Upheaval fallback chain. See
[localization](../docs/localization.md) for adding messages.

Animal inspector regressions in `test_context_bars.gd` cover hover/facing
priority, all simultaneous production blockers, non-mutating inspection,
cycle percentage, live translation and cleanup after menu/death/free.
`test_small_window_ui.gd` reproduces a 1920×1080 world stretched into a 500×281
content area: it checks physical card/font sizes, transformed buy/close clicks,
unchanged camera zoom, resizing/retranslation retaining checkout, and scrolling
to all inventory slots inside the reduced panel.

Produce sales: `unit/test_produce_sale_service.gd` checks fixed catalog prices,
multi-stack quantity sales, all-type bulk sales, exclusions, invalid/stale
quantities, forged offers, duplicate prices, wallet overflow and atomic/reentrant
observers. `integration/test_produce_sales.gd` exercises typed quantities, both
buttons, cleanup, locale/resize retention, 500-pixel clicks and choosing between
NPCs spaced 16 pixels apart. World persistence tests verify sale proceeds and
remaining items survive a disk roundtrip and loading closes the sales menu.

Land expansion: `unit/test_land_expansion.gd` and
`integration/test_land_expansion.gd` cover the real 48 × 34 map, paid column
unlocking, modal interaction, farming guards, v6 disk roundtrip and v5 migration.

Boosters: `unit/test_boosters.gd` and `integration/test_boosters.gd` exercise
fertilizer's strict 50% boundary, shortened deadlines, one-time juvenile tonic,
one-cycle adult bonus (both random outcomes), offline batches, inventory/action
cancellation, canonical shop items, schema v7 disk roundtrip and v6 migration.

Unified interactions: `integration/test_unified_interaction.gd` checks one-target
priority, E facing/line of sight, live contextual badges, full-trough blocking,
whole-bag auto feed/water, click approach around obstacles, explicit target
retention, keyboard/new-focus/deletion cancellation, unreachable targets,
click harvesting, focus-only empty ground and translated land confirmation.
`unit/test_trough_refilling.gd` adds feed-reserve conservation/reentry checks;
world persistence adds schema v8 disk roundtrip, v7 migration and atomic
invalid-reserve rejection.

Beehives: `unit/test_beehive_production.gd` checks capped batches, the ×1.3 rate,
monofloral thresholds, mixed/late pollen, full-bag retention and reentry.
`integration/test_beehives.gd` covers exclusive source assignment, offline bloom
boundaries, sunflower sources, non-stacking crop bonuses, fertilizer, atomic
placement, buying/left-click placement, E/click collection, honey sales, schema 9
migration/validation, disk roundtrip and exactly-once offline crop acceleration.
