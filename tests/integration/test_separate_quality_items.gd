extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const CARROT: ItemDefinition = preload("res://items/harvest_produces/carrot_produces.tres")
var world: FarmWorld
var adapter: WorldStateAdapter
var now: float

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(12, 4)
	world.player.wallet.set_balance(1000000)
	now = world.farming.time_manager.now()
	adapter = WorldStateAdapter.new(world, SaveCatalog.new())
	await wait_process_frames(2)

func _mixed() -> Dictionary:
	return {"item": String(CARROT.item_id), "count": 6, "tiers": [1, 2, 3]}

func _pure(slots: Array) -> bool:
	for slot: Dictionary in slots:
		if not ItemQuality.homogeneous(slot.tiers):
			return false
	return true

func test_all_catalog_produce_have_three_independent_quality_stacks() -> void:
	for item: ItemDefinition in adapter.catalog.items.values():
		if item.item_type != ItemDefinition.ItemType.PRODUCE or item.star_fruit:
			continue
		var bag: InventoryComponent = InventoryComponent.new()
		bag.starting_tools = false
		bag.slot_count = 3
		add_child_autofree(bag)
		for tier: int in range(3):
			assert_eq(bag.add(item, 1, tier), 1, String(item.item_id))
			assert_eq(bag.slot(tier).tiers[tier], 1)
			assert_string_contains(ItemQuality.item_name(item, bag.slot(tier).tiers), ItemQuality.label(tier))
		assert_eq(bag.capacity_for(item, 0), item.get_stack_limit() - 1)
		assert_eq(bag.count_item(item.item_id, -1), 3)

func test_full_legacy_containers_split_without_loss_and_save_roundtrip() -> void:
	assert_eq(world.workers.hire("crop"), "")
	now = world.farming.time_manager.now()
	var saved: Dictionary = adapter.capture("separate_quality", 1, now)
	saved.version = 38
	for i: int in range(saved.inventory.size()):
		saved.inventory[i] = _mixed()
	var warehouse: Dictionary = saved.storages.produce_warehouse
	var warehouse_slots: int = warehouse.slots.size()
	for i: int in range(warehouse_slots):
		warehouse.slots[i] = _mixed()
	for i: int in range(16):
		saved.workers.rows[0].basket[i] = _mixed()
	var original: String = JSON.stringify(saved)
	var migrated: Dictionary = SaveSchema.validate(saved, adapter.catalog)
	assert_true(migrated.ok, str(migrated.get("error", "")))
	assert_eq(JSON.stringify(saved), original, "Migration never edits the input")
	if not migrated.ok:
		return
	var data: Dictionary = migrated.snapshot
	assert_eq(data.version, 39)
	assert_eq(data.inventory.size(), 192)
	assert_eq(data.storages.produce_warehouse.slot_count, warehouse_slots * 3)
	assert_eq(data.workers.rows[0].basket.size(), 48)
	assert_true(_pure(data.inventory))
	assert_true(_pure(data.storages.produce_warehouse.slots))
	assert_true(_pure(data.workers.rows[0].basket))
	assert_true(adapter.restore(data, now).ok)
	var bag: InventoryComponent = world.player.selection.inventory
	for tier: int in range(3):
		assert_eq(bag.count_item(CARROT.item_id, tier), 64 * (tier + 1))
	var ui: InventoryUI = world.player.get_node("InventoryUI") as InventoryUI
	assert_eq(ui.buttons.size(), 192)
	var current: Dictionary = adapter.capture("separate_quality", 1, now)
	assert_true(SaveSchema.validate(current, adapter.catalog).ok)
	var directory: String = "res://.godot/quality_split_" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repository: LocalSaveRepository = LocalSaveRepository.new(directory, adapter.catalog)
	assert_true(repository.write_profile("separate_quality", current, 0).ok)
	var loaded: Dictionary = repository.read_profile("separate_quality")
	assert_true(loaded.ok)
	assert_true(adapter.restore(loaded.snapshot, now).ok)
	assert_eq(bag.count_item(CARROT.item_id, -1), 384)
	DirAccess.remove_absolute(repository.path("separate_quality"))
	DirAccess.remove_absolute(directory)

func test_migration_reuses_empty_slots_and_rejects_corrupt_counts_atomically() -> void:
	var saved: Dictionary = adapter.capture("separate_quality", 1, now)
	saved.version = 38
	saved.inventory[2] = _mixed()
	var migrated: Dictionary = SaveSchema.validate(saved, adapter.catalog)
	assert_true(migrated.ok)
	assert_eq(migrated.snapshot.inventory.size(), 64)
	assert_eq(migrated.snapshot.inventory[2].tiers, [1, 0, 0])
	var current: Dictionary = saved.duplicate(true)
	current.version = SaveSchema.VERSION
	assert_false(SaveSchema.validate(current, adapter.catalog).ok, "Current saves cannot contain mixed stacks")
	saved.inventory[2].count = 7
	var before: Dictionary = adapter.capture("separate_quality", 1, now)
	assert_false(adapter.restore(saved, now).ok)
	assert_eq(adapter.capture("separate_quality", 1, now).inventory, before.inventory)

func test_storage_does_not_spend_another_quality_or_remove_units_that_do_not_fit() -> void:
	var service: FarmStorageService = FarmStorageService.new()
	add_child_autofree(service)
	var bag: InventoryComponent = InventoryComponent.new()
	bag.starting_tools = false
	bag.slot_count = 1
	bag.stack_cap = 5
	add_child_autofree(bag)
	bag.add(CARROT, 3, 0)
	var store: InventoryComponent = service.inventory("produce_warehouse")
	store.add(CARROT, 7, 1)
	assert_false(service.transfer("produce_warehouse", bag, CARROT.item_id, 7, false, 1).ok)
	assert_eq(store.count_item(CARROT.item_id, 1), 7)
	bag.remove(CARROT.item_id, 3)
	assert_eq(service.transfer("produce_warehouse", bag, CARROT.item_id, 7, false, 1).moved, 5)
	assert_eq(bag.slot(0).tiers, [0, 5, 0])
	assert_eq(store.count_item(CARROT.item_id, 1), 2)

func test_warehouse_card_click_selects_that_quality_and_only_matching_cards() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	for tier: int in range(3):
		bag.add(CARROT, 10 + tier, tier)
	var access: FarmStorageAccess = world.storage_accesses.produce_warehouse
	var view: FarmStorageMenu = access.menu as FarmStorageMenu
	assert_true(view.open(access, world.player))
	await wait_process_frames(3)
	var cards: Array[FarmStorageSlot] = []
	for card: FarmStorageSlot in view.grids[0].get_children():
		if card.item == CARROT:
			cards.append(card)
	assert_eq(cards.size(), 3)
	for card: FarmStorageSlot in cards:
		var tier: int = ItemQuality.stack_tier(card.tiers)
		card.pressed.emit()
		assert_eq(view.selected_tier, tier)
		assert_string_contains(view.item_name.text, ItemQuality.label(tier))
		assert_eq(view.quantity.max_value, float(10 + tier))
		for other: FarmStorageSlot in cards:
			assert_eq(other.button_pressed, other == card)
	view.close(false)
