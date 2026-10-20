# Tests

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
Farming tests verify that approaching an off-center click still focuses the correct cell
and waits for manual tool use.

`farmer_bob_test.gd` is the earlier standalone smoke test; it is excluded from
GUT discovery and can still run with `godot --headless --path . -s tests/farmer_bob_test.gd`.

## Cửa hàng và ví tiền

`unit/test_shop_service.gd` kiểm tra mua nguyên giao dịch, thiếu xu, đầy túi, số lượng/giá sai, reentry và đủ 34 mặt hàng. `integration/test_shop.gd` kiểm tra E, modal, nhóm hàng, lời cảm ơn sau đóng, giải phóng lock khi xóa NPC và layout Full HD. Save repository/persistence kiểm tra migration v3→v4 và file roundtrip số xu sau mua.

Regression sức chứa: `test_crops.gd` bao phủ cả 22 loài qua animation impact; `test_pickup_feedback.gd` bao phủ 7 sản phẩm động vật và tình huống trứng còn gộp được nhưng sữa/lông không có slot. `test_save_repository.gd` kiểm tra v4→v5 mở rộng 24→64 ô không đổi slot cũ/coins/hotbar và không migrate lặp.
