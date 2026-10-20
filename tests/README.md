# Tests

Run GUT from its Godot editor panel, or from the project root:

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

`.gutconfig.json` discovers `test_*.gd` under `tests/unit` and `tests/integration`.
Unit tests cover movement, facing and state transitions. Integration tests inject
physical keyboard events and verify movement, action animation completion and
camera behavior at Full HD. Input and scene instances are cleaned up per test.

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
