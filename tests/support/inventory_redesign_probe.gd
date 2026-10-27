extends "res://tests/support/hotbar_skin_probe.gd"
## Reuses the save-isolated UI/input probe helpers; never opens a personal save.

func _check_bag_layout(bag_ui: InventoryUI) -> void:
	var bounds: Rect2 = get_viewport().get_visible_rect()
	for control: Control in [bag_ui.panel, bag_ui.close_button, bag_ui.wallet_label, bag_ui.capacity, bag_ui.move_button, bag_ui.assign_button]:
		_check(bounds.grow(1).encloses(_screen_rect(control)), "Inventory control stays on screen: " + control.name)
	_check(not _screen_rect(bag_ui._scroll).intersects(_screen_rect(bag_ui._sidebar)), "Grid and details do not overlap")
	_check(bag_ui.grid.columns > 1, "Bag remains a usable grid")
	_check(bag_ui.move_button.size.y >= 48 and bag_ui.assign_button.size.y >= 48, "Actions keep 48px touch targets")

func _run() -> void:
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	await _frames(8)
	world.tool_upgrades.profile_ready = true
	var bag: InventoryComponent = world.player.selection.inventory
	for index: int in range(bag.slot_count):
		bag.remove_from_slot(index, bag.get_slot_count(index))
	for path: String in ["items/tools/hoe.tres", "items/tools/watering_can.tres"]:
		bag.add(load("res://" + path) as ItemDefinition, 1)
	bag.add(SEED, 24)
	bag.add(FERTILIZER, 5)
	var carrot: ItemDefinition = load("res://items/harvest_produces/carrot_produces.tres") as ItemDefinition
	bag.add(carrot, 80, 0)
	bag.add(carrot, 40, 1)
	var apple: ItemDefinition = load("res://items/trees/apple.tres") as ItemDefinition
	bag.add(apple, 30)
	for entry: Array in [["items/animal_produces/chicken_egg.tres", 12], ["items/harvest_produces/wheat_produces.tres", 18], ["items/animal_produces/cow_milk.tres", 6], ["items/trees/wood.tres", 40], ["items/honey/wild_honey.tres", 8]]:
		bag.add(load("res://" + str(entry[0])) as ItemDefinition, int(entry[1]))
	world.player.wallet.set_balance(10000)
	var bag_ui: InventoryUI = world.player.get_node("InventoryUI") as InventoryUI
	bag_ui.open()
	bag_ui._inspect_slot(4)
	await _frames(8)
	_check_bag_layout(bag_ui)
	_check(bag_ui.quality_panel.is_visible_in_tree(), "Quality is inline")
	_check(bag_ui._quality_rows[0].text == "80" and bag_ui._quality_rows[1].text == "40", "Quality quantities match the stack")
	_check(bag_ui.grid.columns == 8, "Desktop uses eight columns")
	await _capture("inventory-desktop-vi")
	Language.set_language("en")
	await _frames(4)
	_check(bag_ui.item_name.text == "Carrot", "Item title translates live")
	await _capture("inventory-desktop-en")
	Language.set_language("vi")
	get_viewport().set_meta("touch_ui_override", true)
	get_viewport().set_meta("safe_insets", Vector4(44, 0, 44, 21))
	get_tree().root.size = Vector2i(844, 390)
	await _frames(10)
	_check_bag_layout(bag_ui)
	await _capture("inventory-phone-vi")
	# Touch selects a stack from below the hotbar and assigns it to an occupied cell.
	bag_ui._scroll.ensure_control_visible(bag_ui.buttons[9])
	await _frames(5)
	await _touch_click(bag_ui.buttons[9])
	var wood: ItemDefinition = bag.get_slot_item(9)
	_check(wood != null and wood.item_id == &"wood", "Touch selects the actual Wood stack")
	await _touch_click(bag_ui.assign_button)
	_check(bag_ui._assigning_hotbar, "Assign action asks for a hotbar destination")
	await _touch_click(bag_ui.buttons[5])
	_check(bag.get_slot_item(5) == wood and bag.get_slot_item(9) == apple, "Assignment swaps occupied cells")
	_check(bag.count_item(&"wood", -1) == 40 and bag.count_item(&"apple", -1) == 30, "Assignment preserves both totals")
	_check(world.player.selection.selected_index == 5, "Assigned cell becomes active")
	bag_ui._inspect_slot(4)
	await _touch_click(bag_ui.move_button)
	await _touch_click(bag_ui.close_button)
	bag_ui.open()
	_check(bag_ui._moving_from == -1, "Closing cancels destination mode")
	_check(bag.count_item(carrot.item_id, -1) == 120, "Cancel never consumes produce")
	get_viewport().set_meta("safe_insets", Vector4.ZERO)
	get_tree().root.size = Vector2i(667, 375)
	await _frames(10)
	_check_bag_layout(bag_ui)
	bag_ui._scroll.scroll_vertical = 100000
	await _frames(5)
	_check(bag_ui._scroll.scroll_vertical > 0, "All 64 cells can be reached by scrolling")
	_check(get_viewport().get_visible_rect().encloses(_screen_rect(bag_ui.buttons[63])), "Last slot is reachable in compact layout")
	await _capture("inventory-small-phone")
	var report: Dictionary = {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "personal_save_used": false}
	var file: FileAccess = FileAccess.open(_output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)
