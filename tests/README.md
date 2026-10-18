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

Hotbar tests cover click/scroll selection, empty slots, Space/right-click use,
input consumed by UI, action locking, matching soil focus and layout at Full HD,
720p and 640×360. Tool selection has separate unit tests.

`farmer_bob_test.gd` is the earlier standalone smoke test; it is excluded from
GUT discovery and can still run with `godot --headless --path . -s tests/farmer_bob_test.gd`.
