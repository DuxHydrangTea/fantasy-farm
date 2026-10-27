extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const APPLE: ItemDefinition = preload("res://items/trees/apple.tres")
var world: FarmWorld

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	await wait_physics_frames(2)

func test_doorways_range_readiness_and_filters() -> void:
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.player.set_physics_process(false)
	assert_eq(world.storage_accesses.size(), 2)
	var access: FarmStorageAccess = world.storage_accesses["produce_warehouse"]
	world.player.selection.inventory.add(APPLE, 20)
	assert_false(world.storages.transfer("produce_warehouse", world.player.selection.inventory, APPLE.item_id, 3, true).ok)
	world.player.global_position = access.global_position + Vector2(0, 24)
	await wait_physics_frames(2)
	assert_true(access.can_reach(world.player))
	world.tool_upgrades.profile_ready = false
	assert_false(access.open_shop(world.player))
	world.tool_upgrades.profile_ready = true
	assert_true(access.open_shop(world.player))
	assert_true(world.player.selection.shop_open)
	assert_true(world.storages.transfer("produce_warehouse", world.player.selection.inventory, APPLE.item_id, 3, true).ok)
	access.menu.close(false)
	assert_false(world.player.selection.shop_open)
	world.player.global_position = access.global_position + Vector2(0, -40)
	await wait_physics_frames(2)
	assert_false(access.can_reach(world.player), "Building collision prevents using the door through its back wall")

func test_v23_migrates_empty_storages_preserving_existing_progress_then_v24_roundtrips() -> void:
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var now: float = world.farming.time_manager.now()
	var original: Dictionary = adapter.capture("storage_test", 1, now)
	var legacy: Dictionary = original.duplicate(true)
	legacy.version = 23
	legacy.erase("storages")
	var checked: Dictionary = SaveSchema.validate(legacy, adapter.catalog)
	assert_true(checked.ok)
	if not checked.ok:
		return
	assert_eq(int(checked.snapshot.version), SaveSchema.VERSION)
	assert_false(legacy.has("storages"), "Migration never mutates its input")
	for key: String in ["inventory", "workers", "coins", "cooking", "tool_upgrades"]:
		assert_eq(checked.snapshot[key], original[key])
	assert_eq(checked.snapshot.storages, FarmStorageSaveSchema.fresh())
	world.storages.inventory("produce_warehouse").add(APPLE, 321)
	var snapshot: Dictionary = adapter.capture("storage_test", 2, now)
	assert_true(SaveSchema.validate(snapshot, adapter.catalog).ok)
	world.storages.inventory("produce_warehouse").remove(APPLE.item_id, 321)
	var restored: Dictionary = adapter.restore(snapshot, now)
	assert_true(restored.ok)
	assert_eq(world.storages.inventory("produce_warehouse").count_item(APPLE.item_id), 321)
	var invalid: Dictionary = snapshot.duplicate(true)
	invalid.storages.produce_warehouse.slots[0].item = "unknown_item"
	assert_false(adapter.restore(invalid, now).ok)
	assert_eq(world.storages.inventory("produce_warehouse").count_item(APPLE.item_id), 321)

func test_menu_quality_selection_exhaustion_and_withdrawal_preserve_tiers() -> void:
	var carrot: ItemDefinition = preload("res://items/harvest_produces/carrot_produces.tres")
	var bag: InventoryComponent = world.player.selection.inventory
	bag.add(carrot, 80, 0)
	bag.add(carrot, 40, 1)
	var access: FarmStorageAccess = world.storage_accesses["produce_warehouse"]
	world.player.global_position = access.global_position + Vector2(0, 24)
	assert_true(access.open_shop(world.player))
	var view: FarmStorageMenu = access.menu as FarmStorageMenu
	view._select(carrot.item_id, true)
	view._select_tier(1)
	assert_eq(view.quantity.max_value, 40.0)
	view.maximum_button.pressed.emit()
	view._move()
	await wait_process_frames(3)
	assert_eq(bag.count_item(carrot.item_id, 0), 80)
	assert_eq(bag.count_item(carrot.item_id, 1), 0)
	assert_true(view.deposit_button.disabled, "Exhausted Silver cannot silently fall back to Normal")
	view._move()
	assert_eq(bag.count_item(carrot.item_id, 0), 80)
	view._select(carrot.item_id, false)
	assert_eq(view.selected_tier, 1)
	view.quantity.get_line_edit().text = "2"
	view._move()
	await wait_process_frames(3)
	assert_eq(bag.count_item(carrot.item_id, 1), 2)
	assert_eq(world.storages.inventory("produce_warehouse").count_item(carrot.item_id, 1), 38)
	view.close(false)
	assert_false(world.player.selection.shop_open)

func test_full_storage_disables_the_selected_transfer() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	var store: InventoryComponent = world.storages.inventory("produce_warehouse")
	var carrot: ItemDefinition = preload("res://items/harvest_produces/carrot_produces.tres")
	store.add(APPLE, store.stack_limit_for(APPLE) * store.slot_count)
	bag.add(carrot, 4)
	var access: FarmStorageAccess = world.storage_accesses["produce_warehouse"]
	world.player.global_position = access.global_position + Vector2(0, 24)
	assert_true(access.open_shop(world.player))
	var view: FarmStorageMenu = access.menu as FarmStorageMenu
	view._select(carrot.item_id, true)
	assert_true(view.deposit_button.disabled)
	assert_true(view.maximum_button.disabled)
	assert_false(view.quantity.editable)
	view._move()
	assert_eq(bag.count_item(carrot.item_id), 4)
	view.close(false)
