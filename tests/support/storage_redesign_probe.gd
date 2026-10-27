extends "res://tests/support/hotbar_skin_probe.gd"
const CARROT: ItemDefinition = preload("res://items/harvest_produces/carrot_produces.tres")
var menu: FarmStorageMenu
var bag: InventoryComponent
var store: InventoryComponent

func _layout() -> void:
	var bounds: Rect2 = get_viewport().get_visible_rect().grow(1)
	for control: Control in [menu.panel, menu.close_button, menu.quantity, menu.deposit_button, menu.withdraw_button, menu.maximum_button]:
		_check(bounds.encloses(_screen_rect(control)), "Storage control stays on screen: " + control.name)
	_check(not _screen_rect(menu.scrolls[0]).intersects(_screen_rect(menu.scrolls[1])), "Bag and storage stay separate")
	_check(menu.scrolls[0].size.y > 40 and menu.scrolls[1].size.y > 40, "Both grids keep visible rows")
	for grid: GridContainer in menu.grids:
		var slot: Control = grid.get_child(0) as Control
		_check(absf(slot.size.x - slot.size.y) < 1, "Storage slots remain square")

func _card(id: StringName, side: int) -> FarmStorageSlot:
	for child: FarmStorageSlot in menu.grids[side].get_children():
		if child.get_meta("storage_item") == id:
			return child
	return null

func _run() -> void:
	Language.set_language("vi")
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	world.tool_upgrades.profile_ready = true
	bag = world.player.selection.inventory
	store = world.storages.inventory("produce_warehouse")
	for index: int in range(bag.slot_count):
		bag.remove_from_slot(index, bag.get_slot_count(index))
	bag.add(CARROT, 80, 0)
	bag.add(CARROT, 40, 1)
	bag.add(CARROT, 10, 2)
	store.add(CARROT, 240, 0)
	for row: Array in [["items/harvest_produces/wheat_produces.tres", 18], ["items/animal_produces/chicken_egg.tres", 12], ["items/animal_produces/cow_milk.tres", 6], ["items/trees/apple.tres", 30], ["items/honey/wild_honey.tres", 8]]:
		var item: ItemDefinition = load("res://" + str(row[0])) as ItemDefinition
		bag.add(item, int(row[1]))
		store.add(item, int(row[1]) * 3)
	bag.add(SEED, 24)
	var access: FarmStorageAccess = world.storage_accesses["produce_warehouse"]
	world.player.global_position = access.global_position + Vector2(0, 24)
	world.player.animation.face(Vector2.UP)
	await _frames(8)
	_check(access.open_shop(world.player), "Actual warehouse opens the new scene")
	menu = access.menu as FarmStorageMenu
	await _frames(5)
	await _click(_card(CARROT.item_id, 0))
	_check(menu.selected_tier == 0, "Selection defaults to the first available quality")
	menu.quantity.value = 20
	await _frames(4)
	_layout()
	_check(menu.usage.text.ends_with("128"), "Warehouse shows actual 128-slot capacity")
	await _capture("storage-desktop-vi")
	await _click(menu.quality_buttons[1])
	menu.quantity.value = 20
	await _click(menu.deposit_button)
	_check(bag.count_item(CARROT.item_id, 1) == 20 and store.count_item(CARROT.item_id, 1) == 20, "Mouse transfers selected silver quantity")
	_check(bag.count_item(CARROT.item_id, 0) == 80 and bag.count_item(CARROT.item_id, 2) == 10, "Other qualities are untouched")
	Language.set_language("en")
	await _frames(5)
	_check(menu.item_name.text == "Carrot" and menu.selected_tier == 1, "Language change keeps item and quality selection")
	await _capture("storage-desktop-en")
	Language.set_language("vi")
	get_viewport().set_meta("touch_ui_override", true)
	get_viewport().set_meta("safe_insets", Vector4(44, 0, 44, 21))
	get_tree().root.size = Vector2i(844, 390)
	await _frames(10)
	_layout()
	await _touch_click(_card(CARROT.item_id, 1))
	await _touch_click(menu.quality_buttons[1])
	menu.quantity.value = 5
	await _touch_click(menu.withdraw_button)
	_check(store.count_item(CARROT.item_id, 1) == 15 and bag.count_item(CARROT.item_id, 1) == 25, "Touch withdraws only selected silver")
	await _capture("storage-phone-vi")
	get_viewport().set_meta("safe_insets", Vector4.ZERO)
	get_tree().root.size = Vector2i(667, 375)
	await _frames(10)
	_layout()
	menu.scrolls[1].ensure_control_visible(menu.grids[1].get_child(store.slot_count - 1) as Control)
	await _frames(4)
	_check(_screen_rect(menu.scrolls[1]).grow(1).encloses(_screen_rect(menu.grids[1].get_child(store.slot_count - 1) as Control)), "Last warehouse slot is reachable")
	await _capture("storage-small-phone")
	await _touch_click(menu.close_button)
	_check(not world.player.selection.shop_open, "Closing releases the modal lock")
	var report: Dictionary = {"checks": _checks, "failures": _failures, "ok": _failures.is_empty(), "personal_save_used": false}
	var file: FileAccess = FileAccess.open(_output + "/redesign-runtime-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)
