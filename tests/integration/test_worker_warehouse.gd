extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const APPLE: ItemDefinition = preload("res://items/trees/apple.tres")
var world: FarmWorld
var service: WorkerService
var now: float

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	service = world.workers
	now = world.farming.time_manager.now()
	var fixed_now: float = now
	world.farming.time_manager.clock_source = func() -> float: return fixed_now
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(1000000)
	world.trees.reset()
	for index: int in range(10):
		var tree: FruitTree = world.trees.create_tree(Vector2i(12 + index * 3, 61), world.trees.definitions[&"apple"], now) as FruitTree
		tree.planted_at = now - tree.definition.growth_seconds - 1.0
		tree.growth_started_at = tree.planted_at
		tree.matures_at = now - 1
		tree.last_at = now
		tree.fruit_work = tree.definition.fruit_cycle_seconds if index == 0 else 0.0
		tree.refresh(now)
	await wait_process_frames(2)

func _limit(cap: int, stock: int = 0) -> void:
	var data: Dictionary = world.storages.capture()
	data.produce_warehouse = {"slot_count": 1, "stack_cap": cap, "slots": [{"item": "apple" if stock > 0 else "", "count": stock, "tiers": [stock, 0, 0]}]}
	world.storages.restore(data, SaveCatalog.new())

func _fruit_task() -> Dictionary:
	return {"kind": "fruit", "id": "12_61", "cell": [12, 61], "point": [0, 0], "priority": 0}

func _mature_crop() -> CropDefinition:
	world.land.state.restore_columns(12, 4)
	var seed: ItemDefinition = load("res://items/seeds/carrot_seed.tres") as ItemDefinition
	world.farming.restore_soil([{"cell": [54, 25], "state": 1}])
	world.farming.restore_crop(Vector2i(54, 25), seed.crop as CropDefinition, now - 100, now - 1, 1.0, now)
	return seed.crop as CropDefinition

func _pile(item: ItemDefinition, amount: int, at: Vector2) -> ItemPickup:
	var pile: ItemPickup = preload("res://scenes/objects/item_pickup.tscn").instantiate() as ItemPickup
	pile.item = item
	pile.amount = amount
	pile.persistent_id = StringName("warehouse_test_%d" % pile.get_instance_id())
	world.add_child(pile)
	pile.global_position = at
	return pile

func test_filled_basket_does_not_limit_new_harvest() -> void:
	service.hire("orchard")
	service.bag_for("orchard").add(APPLE, 1600)
	service.advance(now + 20)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 300)
	assert_eq(service.bag_for("orchard").count_item(APPLE.item_id), 1600)

func test_capacity_is_rechecked_when_arriving_after_warehouse_fills() -> void:
	_limit(300)
	service.hire("orchard")
	service.advance(now)
	assert_eq(service.record("orchard").task.kind, "fruit")
	service.output_inventory().add(APPLE, 1)
	service.advance(now + 20)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 1)
	assert_true((world.trees.trees[Vector2i(12, 61)] as FruitTree).has_fruit())
	service.output_inventory().remove(APPLE.item_id, 1)
	assert_true(service.record("orchard").task.is_empty(), "Freeing storage interrupts only idle patrol")
	service.advance(now + 40)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 300)
	assert_false((world.trees.trees[Vector2i(12, 61)] as FruitTree).has_fruit())

func test_crop_and_orchard_share_last_slot_and_preserve_unaccepted_crop() -> void:
	_limit(300)
	var crop: CropDefinition = _mature_crop()
	service.hire("orchard")
	service.hire("crop")
	var orchard_task: Dictionary = service.bridge.candidates(service.record("orchard"), service.feed_inventory("orchard"))[0]
	var crop_task: Dictionary = service.bridge.candidates(service.record("crop"), service.feed_inventory("crop"))[0]
	assert_true(service.bridge.commit(service.record("orchard"), service.feed_inventory("orchard"), orchard_task))
	assert_false(service.bridge.commit(service.record("crop"), service.feed_inventory("crop"), crop_task))
	assert_not_null(world.farming.get_crop(Vector2i(54, 25)))
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 300)
	assert_eq(service.output_inventory().count_item(crop.harvest_item.item_id), 0)
	service.output_inventory().remove(APPLE.item_id, 300)
	assert_true(service.bridge.commit(service.record("crop"), service.feed_inventory("crop"), crop_task))
	assert_null(world.farming.get_crop(Vector2i(54, 25)))
	assert_eq(service.output_inventory().count_item(crop.harvest_item.item_id, -1), crop.harvest_amount)

func test_ranch_pickup_uses_warehouse_and_preserves_partial_pile_and_feed() -> void:
	_limit(100, 95)
	var pen: AnimalPen = service.bridge.pens()[0]
	service.hire("ranch", String(pen.persistent_id))
	var feed: ItemDefinition = load("res://items/feeds/poultry_feed.tres") as ItemDefinition
	service.feed_inventory("ranch").add(feed, 8)
	var pile: ItemPickup = _pile(APPLE, 20, service.bridge.home("ranch", String(pen.persistent_id)))
	var task: Dictionary = {"kind": "pickup", "id": String(pile.persistent_id)}
	assert_true(service.bridge.commit(service.record("ranch"), service.feed_inventory("ranch"), task))
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 100)
	assert_eq(pile.amount, 15)
	assert_eq(service.feed_inventory("ranch").count_item(feed.item_id), 8)
	assert_eq(service.bag_for("ranch").count_item(APPLE.item_id), 0)
	assert_false(service.bridge.commit(service.record("ranch"), service.feed_inventory("ranch"), task))
	assert_eq(pile.amount, 15)

func test_each_role_pickup_candidate_uses_output_not_basket_capacity() -> void:
	service.hire("orchard")
	service.hire("ranch", String(service.bridge.pens()[0].persistent_id))
	world.land.state.restore_columns(12, 4)
	service.hire("crop")
	for row: Dictionary in service.records:
		service.bag_for(row.role).add(APPLE, 1600)
		var pile: ItemPickup = _pile(APPLE, 7, service.bridge.home(row.role, row.zone))
		var found: Dictionary = {}
		for task: Dictionary in service.bridge.candidates(row, service.feed_inventory(row.role)):
			if task.kind == "pickup" and task.id == String(pile.persistent_id):
				found = task
		assert_false(found.is_empty(), row.role)
		assert_true(service.bridge.commit(row, service.feed_inventory(row.role), found))
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 21)
	assert_eq(world.player.selection.inventory.count_item(APPLE.item_id), 0)

func test_legacy_save_import_is_partial_idempotent_and_keeps_feed_after_dismissal() -> void:
	_limit(100, 95)
	service.hire("ranch", String(service.bridge.pens()[0].persistent_id))
	var feed: ItemDefinition = load("res://items/feeds/poultry_feed.tres") as ItemDefinition
	service.bag_for("ranch").add(APPLE, 200)
	service.bag_for("ranch").add(feed, 8)
	service.dismiss("ranch")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("warehouse_test", 1, now)
	assert_true(adapter.restore(saved, now).ok)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 100)
	assert_eq(service.bag_for("ranch").count_item(APPLE.item_id), 195)
	assert_eq(service.feed_inventory("ranch").count_item(feed.item_id), 8)
	var migrated: Dictionary = adapter.capture("warehouse_test", 2, now)
	assert_true(adapter.restore(migrated, now).ok)
	assert_true(adapter.restore(migrated, now).ok)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 100)
	assert_eq(service.bag_for("ranch").count_item(APPLE.item_id), 195)
	assert_eq(service.transfer("ranch", world.player.selection.inventory, false, false), 195)
	assert_eq(service.feed_inventory("ranch").count_item(feed.item_id), 8)
	assert_eq(world.player.selection.inventory.count_item(APPLE.item_id), 195)

func test_legacy_remainder_drains_after_capacity_is_freed() -> void:
	_limit(100, 100)
	service.hire("orchard")
	service.bag_for("orchard").add(APPLE, 20)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("warehouse_test", 1, now)
	assert_true(adapter.restore(saved, now).ok)
	assert_eq(service.bag_for("orchard").count_item(APPLE.item_id), 20)
	service.output_inventory().remove(APPLE.item_id, 10)
	service.advance(now)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 100)
	assert_eq(service.bag_for("orchard").count_item(APPLE.item_id), 10)

func test_v23_profile_imports_old_products_into_new_empty_warehouse_once() -> void:
	service.hire("ranch", String(service.bridge.pens()[0].persistent_id))
	service.dismiss("ranch")
	var feed: ItemDefinition = load("res://items/feeds/poultry_feed.tres") as ItemDefinition
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var legacy: Dictionary = adapter.capture("warehouse_test", 1, now)
	legacy.version = 23
	legacy.erase("storages")
	legacy.workers.rows[0].basket[0] = {"item": "apple", "count": 100}
	legacy.workers.rows[0].basket[1] = {"item": "apple", "count": 50}
	legacy.workers.rows[0].basket[2] = {"item": "poultry_feed", "count": 8}
	assert_true(adapter.restore(legacy, now).ok)
	assert_false(legacy.has("storages"))
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 150)
	assert_eq(service.bag_for("ranch").count_item(APPLE.item_id), 0)
	assert_eq(service.feed_inventory("ranch").count_item(feed.item_id), 8)
	var current: Dictionary = adapter.capture("warehouse_test", 2, now)
	assert_true(adapter.restore(current, now).ok)
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 150)

func test_full_warehouse_still_allows_crop_watering_and_ranch_feeding() -> void:
	_limit(1, 1)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	world.land.state.restore_columns(12, 4)
	var seed: ItemDefinition = load("res://items/seeds/carrot_seed.tres") as ItemDefinition
	world.farming.restore_soil([{"cell": [54, 25], "state": 1}])
	world.farming.restore_crop(Vector2i(54, 25), seed.crop as CropDefinition, now - 10, now + 50, 0.2, now)
	service.hire("crop")
	assert_true(service.bridge.commit(service.record("crop"), service.feed_inventory("crop"), {"kind": "water_crop", "cell": [54, 25]}))
	var pen: AnimalPen = service.bridge.pens()[0]
	service.hire("ranch", String(pen.persistent_id))
	for node: Node in pen.get_children():
		if node is AnimalTrough and node.kind == AnimalTrough.Kind.FOOD:
			node.stock = 0
			service.feed_inventory("ranch").add(node.feed_item, 1)
			service.busy = true
			assert_true(service.bridge.commit(service.record("ranch"), service.feed_inventory("ranch"), {"kind": "feed", "id": String(node.persistent_id)}))
			service.busy = false
			assert_gt(node.stock, 0)
			break
	assert_eq(service.output_inventory().count_item(APPLE.item_id), 1)

func test_warehouse_notifications_hold_transaction_lock_and_refresh_open_panel() -> void:
	service.hire("orchard")
	var access: FarmStorageAccess = world.storage_accesses.produce_warehouse
	world.player.global_position = access.global_position + Vector2(0, 24)
	assert_true(access.open_shop(world.player))
	var observed: Array[bool] = []
	world.storages.changed.connect(func(id: String) -> void:
		if id == "produce_warehouse":
			observed.append(world.storages.busy)
			assert_false(service.available())
			assert_ne(service.dismiss("orchard"), "")
	)
	service.advance(now + 20)
	await wait_process_frames(4)
	assert_eq(observed, [true])
	var menu: FarmStorageMenu = access.menu as FarmStorageMenu
	assert_false(menu.grids[1].get_children().is_empty())
	assert_true((menu.grids[1].get_child(0) as Button).text.contains("300"))
	menu.close(false)

