# Inventory

Open or close with Tab or I; Escape and the X button also close it.
The 64 slots use the existing UI sprite sheet and square button sprites.
The first six slots are shared with the hotbar. Select them using 1–6
or a click. Space or right click uses the selected tool.
The mouse wheel zooms the farm while the inventory is closed; it never changes the selected slot.

Drag items between slots to move, swap, or merge matching stacks. Counts and
hotbar icons refresh immediately. Opening the inventory stops movement and
cancels pending tool use; gameplay input stays blocked while it is open.

`InventoryComponent` owns the contents. `ToolSelectionComponent` creates and
shares it with the hotbar and inventory UI. It starts with a hoe and watering
can. The player scene also supplies 12 carrot seeds in slot 3. Gameplay can call `add`, `remove`, `count_item`,
and `move_slot`. `add` returns the amount accepted, so callers can retain any
overflow. Tools stack to one; other items follow `ItemDefinition.max_stack`.
Inventory contents are included in the world save; see [saving](saving.md).

The global game theme uses Upheaval with Pixelify Sans / Mouse Meadow for
missing Vietnamese glyphs. See [localization](localization.md) for text and locale rules. Font files and licenses remain under assets/Fonts.

Run tests with Godot:
`godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`

The inventory has an independent UI scale for small windows. Its panel fits the
virtual canvas and keeps all 64 slots reachable through vertical scrolling.
See [text rendering](ui_text.md) for scale and transform rules.
