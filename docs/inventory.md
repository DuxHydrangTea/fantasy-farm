# Inventory

Open or close with Tab or I; Escape and the X button also close it.
The 24 slots use the existing UI sprite sheet and square button sprites.
The first six slots are shared with the hotbar. Select them using 1–6,
the mouse wheel, or a click. Space or right click uses the selected tool.

Drag items between slots to move, swap, or merge matching stacks. Counts and
hotbar icons refresh immediately. Opening the inventory stops movement and
cancels pending tool use; gameplay input stays blocked while it is open.

`InventoryComponent` owns the contents. `ToolSelectionComponent` creates and
shares it with the hotbar and inventory UI. It starts with a hoe and watering
can. The player scene also supplies 12 carrot seeds in slot 3. Gameplay can call `add`, `remove`, `count_item`,
and `move_slot`. `add` returns the amount accepted, so callers can retain any
overflow. Tools stack to one; other items follow `ItemDefinition.max_stack`.
Inventory contents currently last for the running session; saving is not wired.

The global game theme uses Pixelify Sans with Mouse Meadow for missing
Vietnamese glyphs. Font files and licenses remain under assets/Fonts.

Run tests with Godot:
`godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`
