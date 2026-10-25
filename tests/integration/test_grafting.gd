extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const OTHER: ItemDefinition = preload("res://items/seeds/radish_seed.tres")
const FERTILIZER: ItemDefinition = preload("res://items/boosters/crop_fertilizer.tres")
var world: FarmWorld
var service: WorkerService
var source: InventoryComponent
var clock: Array[float]
var now: float
var original_clock: Callable
var original_clock_floor: float
var cell: Vector2i = Vector2i(48, 30)

func before_each() -> void:
	original_clock = TimeManager.clock_source
	original_clock_floor = TimeManager._last_timestamp
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(12, 4)
	world.player.wallet.set_balance(1000000)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	now = world.farming.time_manager.now()
	clock = [now]
	var manual_clock: Array[float] = clock
	world.farming.time_manager.clock_source = func() -> float: return manual_clock[0]
	world.farming.restore_soil([])
	service = world.workers
	source = world.storages.inventory("farm_supply_storage")
	world.trees.reset()
	_limit([cell, cell + Vector2i.RIGHT])

func after_each() -> void:
	world.farming.time_manager.clock_source = original_clock
	world.farming.time_manager._last_timestamp = original_clock_floor

func _limit(cells: Array[Vector2i]) -> void:
	service.crop_policy.cells = cells.duplicate()
	service.crop_policy.cached_columns = world.land.state.unlocked_columns
	service.crop_policy.soils.clear()
	for point: Vector2i in cells:
		service.crop_policy.soils[point] = int(world.farming.get_soil_state(point))

func _commit(job: Dictionary) -> bool:
	service.busy = true
	var result: bool = service.bridge.commit(service.record("crop"), service.feed_inventory("crop"), job)
	service.busy = false
	return result

func _plant(point: Vector2i = Vector2i(48, 30), item: ItemDefinition = SEED) -> void:
	source.add(item, 1)
	assert_true(_commit(service.crop_policy.task("till", point, 5, item)))
	assert_true(_commit(service.crop_policy.task("plant", point, 4, item)))

func _fruit(species: StringName = &"apple", ripe: bool = true, point: Vector2i = Vector2i(12, 61)) -> FruitTree:
	var definition: TreeDefinition = world.trees.definitions[species]
	var start: float = now - definition.growth_seconds - definition.fruit_cycle_seconds * (1.0 if ripe else 0.25)
	var tree: FruitTree = world.trees.create_tree(point, definition, start) as FruitTree
	tree.growth_started_at = start
	tree.matures_at = start + definition.growth_seconds
	tree.refresh(now)
	world.player.global_position = tree.global_position + Vector2(0, 24)
	world.player.animation.facing_direction = &"up"
	return tree

func _wax(amount: int = 1) -> void:
	world.player.selection.inventory.add(load("res://items/boosters/grafting_wax.tres") as ItemDefinition, amount)

func _orchard() -> void:
	for i: int in range(1, 10):
		_fruit(&"apple", false, Vector2i(12 + i * 3, 61))
	assert_eq(service.hire("orchard"), "")

func test_first_choice_free_preserves_ready_crop_and_applies_only_after_harvest() -> void:
	var tree: FruitTree = _fruit()
	var bag: InventoryComponent = world.player.selection.inventory
	assert_eq(world.grafting.choose(tree, FruitTree.Graft.QUALITY, 0), "")
	assert_eq(tree.active_graft, FruitTree.Graft.NONE)
	assert_eq(tree.pending_graft, FruitTree.Graft.QUALITY)
	assert_eq(tree.harvest_item(), tree.definition.harvest_item)
	assert_eq(tree.harvest_amount(), 300)
	assert_true(tree.harvest(bag))
	assert_eq(bag.count_item(&"apple"), 300)
	assert_eq(bag.count_item(&"apple_star"), 0)
	assert_eq(tree.active_graft, FruitTree.Graft.QUALITY)
	assert_eq(tree.pending_graft, FruitTree.Graft.NONE)
	assert_false(tree.harvest(bag))
	clock[0] += tree.definition.fruit_cycle_seconds
	tree.refresh(clock[0])
	assert_true(tree.harvest(bag))
	assert_eq(bag.count_item(&"apple_star"), 300)

func test_yield_doubles_only_after_first_crop_and_switch_does_not_rewrite_progress() -> void:
	var tree: FruitTree = _fruit()
	var bag: InventoryComponent = world.player.selection.inventory
	assert_eq(world.grafting.choose(tree, FruitTree.Graft.YIELD, 0), "")
	assert_true(tree.harvest(bag))
	clock[0] += tree.definition.fruit_cycle_seconds * 0.25
	tree.refresh(clock[0])
	var progress: float = tree.fruit_work
	_wax(2)
	assert_eq(world.grafting.choose(tree, FruitTree.Graft.QUALITY, tree.graft_revision), "")
	assert_eq(tree.fruit_work, progress)
	assert_eq(tree.harvest_amount(), 600)
	assert_eq(tree.harvest_item(), tree.definition.harvest_item)
	clock[0] += tree.definition.fruit_cycle_seconds
	tree.refresh(clock[0])
	assert_true(tree.harvest(bag))
	assert_eq(bag.count_item(&"apple"), 900)
	assert_eq(bag.count_item(&"apple_star"), 0)
	assert_eq(tree.harvest_item(), tree.definition.star_harvest_item)
	assert_eq(tree.harvest_amount(), 300)
	assert_eq(bag.count_item(GraftService.WAX), 1)

func test_duplicate_and_stale_clicks_never_spend_extra_wax() -> void:
	var tree: FruitTree = _fruit()
	assert_eq(world.grafting.choose(tree, FruitTree.Graft.YIELD, 0), "")
	_wax(2)
	assert_false(world.grafting.choose(tree, FruitTree.Graft.YIELD, tree.graft_revision).is_empty())
	var revision: int = tree.graft_revision
	assert_eq(world.grafting.choose(tree, FruitTree.Graft.QUALITY, revision), "")
	assert_false(world.grafting.choose(tree, FruitTree.Graft.QUALITY, revision).is_empty())
	assert_false(world.grafting.choose(tree, FruitTree.Graft.YIELD, revision).is_empty())
	assert_eq(world.player.selection.inventory.count_item(GraftService.WAX), 1)
	assert_eq(tree.pending_graft, FruitTree.Graft.QUALITY)

func test_missing_wax_immature_loading_and_distance_do_not_change_tree() -> void:
	var tree: FruitTree = _fruit()
	world.tool_upgrades.profile_ready = false
	assert_false(world.grafting.choose(tree, 1, 0).is_empty())
	world.tool_upgrades.profile_ready = true
	world.player.global_position += Vector2(200, 0)
	assert_false(world.grafting.choose(tree, 1, 0).is_empty())
	world.player.global_position = tree.global_position + Vector2(0, 24)
	assert_eq(world.grafting.choose(tree, 1, 0), "")
	assert_false(world.grafting.choose(tree, 2, tree.graft_revision).is_empty())
	assert_eq(tree.pending_graft, 1)
	var young: FruitTree = world.trees.create_tree(Vector2i(15, 61), tree.definition, now) as FruitTree
	world.player.global_position = young.global_position + Vector2(0, 24)
	assert_false(world.grafting.choose(young, 1, 0).is_empty())
	assert_eq(young.graft_revision, 0)

func test_worker_uses_dynamic_amount_and_keeps_pending_graft_when_warehouse_too_small() -> void:
	var tree: FruitTree = _fruit()
	tree.active_graft = FruitTree.Graft.YIELD
	tree.pending_graft = FruitTree.Graft.QUALITY
	tree.graft_revision = 2
	_orchard()
	var data: Dictionary = world.storages.capture()
	data.produce_warehouse = {"slot_count": 1, "stack_cap": 400, "slots": [{"item": "", "count": 0, "tiers": [0, 0, 0]}]}
	world.storages.restore(data, SaveCatalog.new())
	var row: Dictionary = service.record("orchard")
	var candidates: Array[Dictionary] = service.bridge.candidates(row, service.feed_inventory("orchard"))
	assert_true(candidates.is_empty())
	assert_true(service.bridge.storage_waiting.orchard)
	var job: Dictionary = {"kind": "fruit", "id": "12_61", "cell": [12, 61]}
	assert_false(service.bridge.commit(row, service.feed_inventory("orchard"), job))
	assert_true(tree.has_fruit())
	assert_eq(tree.pending_graft, FruitTree.Graft.QUALITY)
	data.produce_warehouse.slots.append({"item": "", "count": 0, "tiers": [0, 0, 0]})
	data.produce_warehouse.slot_count = 2
	world.storages.restore(data, SaveCatalog.new())
	assert_true(service.bridge.commit(row, service.feed_inventory("orchard"), job))
	assert_eq(service.output_inventory().count_item(&"apple"), 600)
	assert_eq(tree.active_graft, FruitTree.Graft.QUALITY)

func test_worker_delivers_star_to_warehouse_and_transport_never_turns_it_into_ordinary_fruit() -> void:
	var tree: FruitTree = _fruit()
	tree.active_graft = FruitTree.Graft.QUALITY
	tree.graft_revision = 2
	_orchard()
	var row: Dictionary = service.record("orchard")
	assert_true(service.bridge.commit(row, service.feed_inventory("orchard"), {"kind": "fruit", "id": "12_61", "cell": [12, 61]}))
	assert_eq(service.output_inventory().count_item(&"apple_star"), 300)
	assert_eq(service.output_inventory().count_item(&"apple"), 0)
	var access: FarmStorageAccess = world.storage_accesses.produce_warehouse
	world.player.global_position = access.global_position
	assert_true(world.storages.transfer_all("produce_warehouse", world.player.selection.inventory, false).ok)
	assert_eq(world.player.selection.inventory.count_item(&"apple_star"), 300)
	assert_eq(world.player.selection.inventory.count_item(&"apple"), 0)

func test_snapshot_v29_migration_and_pending_roundtrip_preserve_crop_and_do_not_spend_again() -> void:
	var tree: FruitTree = _fruit(&"apple", false)
	assert_eq(world.grafting.choose(tree, FruitTree.Graft.QUALITY, 0), "")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var current: Dictionary = adapter.capture("graft_test", 1, now)
	assert_true(SaveSchema.validate(current, adapter.catalog).ok)
	assert_true(adapter.restore(current, now).ok)
	var restored: FruitTree = world.trees.trees[Vector2i(12, 61)] as FruitTree
	assert_eq(restored.pending_graft, FruitTree.Graft.QUALITY)
	assert_eq(restored.fruit_work, current.trees[0].fruit_work)
	assert_true(adapter.restore(current, now).ok)
	assert_eq(world.player.selection.inventory.count_item(GraftService.WAX), 0)
	var old: Dictionary = current.duplicate(true)
	old.version = 29
	for key: String in ["active_graft", "pending_graft", "graft_revision"]:
		old.trees[0].erase(key)
	var text: String = JSON.stringify(old)
	var migrated: Dictionary = SaveSchema.validate(old, adapter.catalog)
	assert_true(migrated.ok)
	assert_eq(migrated.snapshot.version, SaveSchema.VERSION)
	assert_eq(migrated.snapshot.trees[0].fruit_work, old.trees[0].fruit_work)
	assert_eq(migrated.snapshot.trees[0].active_graft, 0)
	assert_eq(migrated.snapshot.trees[0].pending_graft, 0)
	assert_eq(JSON.stringify(old), text)
	current.trees[0].pending_graft = 3
	assert_false(SaveSchema.validate(current, adapter.catalog).ok)
	current.trees[0].pending_graft = 1.5
	assert_false(SaveSchema.validate(current, adapter.catalog).ok)

func test_e_and_click_open_shared_menu_without_harvesting_or_uprooting() -> void:
	var tree: FruitTree = _fruit()
	var target: InteractionTarget = InteractionTarget.new(tree, InteractionTarget.Kind.TREE, world.player)
	assert_true(world.player.interactions.execute(target))
	assert_true(world.graft_menu.is_open)
	assert_true(world.player.selection.shop_open)
	assert_false(tree.removed)
	assert_true(tree.has_fruit())
	assert_true(world.graft_menu.summary.text.contains("300"))
	world.graft_menu._choose(FruitTree.Graft.YIELD)
	assert_eq(tree.pending_graft, FruitTree.Graft.YIELD)
	world.graft_menu._collect()
	assert_eq(tree.active_graft, FruitTree.Graft.YIELD)
	assert_eq(world.player.selection.inventory.count_item(&"apple"), 300)
	world.graft_menu.close(false)
	assert_false(world.player.selection.shop_open)

func test_graft_transaction_locks_reentry_and_observers_see_paid_wax_and_pending_direction() -> void:
	var tree: FruitTree = _fruit()
	assert_eq(world.grafting.choose(tree, FruitTree.Graft.YIELD, 0), "")
	_wax(2)
	var events: Array[int] = []
	world.player.selection.inventory.changed.connect(func() -> void:
		events.append(world.player.selection.inventory.count_item(GraftService.WAX))
		assert_eq(tree.pending_graft, FruitTree.Graft.QUALITY)
		assert_true(world.workers.busy and world.storages.busy and tree._busy)
		assert_false(world.grafting.choose(tree, FruitTree.Graft.YIELD, tree.graft_revision).is_empty())
	)
	assert_eq(world.grafting.choose(tree, FruitTree.Graft.QUALITY, tree.graft_revision), "")
	assert_eq(events, [1])
	assert_false(world.grafting.busy or world.workers.busy or world.storages.busy or tree._busy)

func test_all_star_fruits_have_normal_raw_price_and_are_separate_exact_chef_inputs() -> void:
	var prices: ProducePriceCatalog = load("res://resources/shops/produce_prices.tres") as ProducePriceCatalog
	var bag: InventoryComponent = world.player.selection.inventory
	for pair: Array in [["apple", "tart"], ["peach", "parfait"], ["pear", "compote"], ["cherry", "preserve"]]:
		var definition: TreeDefinition = world.trees.definitions[StringName(pair[0])]
		var star: ItemDefinition = definition.star_harvest_item
		assert_true(star.star_fruit)
		assert_eq(prices.find(star.item_id).price, prices.find(definition.harvest_item.item_id).price)
		assert_eq(bag.add(star, 1, 2), 0)
		var recipe: CookingRecipe = ChefCooking.find("star_%s_%s" % pair)
		assert_true(recipe.valid())
		bag.add(definition.harvest_item, 2)
		bag.add(recipe.ingredients[1], 1)
		assert_eq(world.cooking.quote(String(recipe.recipe_id), 1, bag), "Not enough ingredients.")
		bag.add(star, 2)
		assert_eq(world.cooking.start(String(recipe.recipe_id), 1, bag, now), "")
		assert_eq(bag.count_item(definition.harvest_item.item_id), 2)
		world.cooking.advance(world.cooking.queue.back().finish_at)
		assert_eq(world.cooking.collect(bag, world.cooking.updated_at), 1)
		assert_eq(bag.count_item(recipe.output.item_id), 1)

func test_wax_crafting_spends_coins_and_inputs_atomically_and_keeps_serial_progress() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	var recipe: CookingRecipe = ChefCooking.find("grafting_wax")
	for i: int in range(recipe.ingredients.size()):
		bag.add(recipe.ingredients[i], recipe.amounts[i] * 2)
	world.player.wallet.set_balance(1999)
	assert_eq(world.cooking.start("grafting_wax", 2, bag, now, world.player.wallet), "Not enough coins.")
	assert_eq(bag.count_item(&"wood"), 10)
	assert_eq(world.cooking.queue.size(), 0)
	world.player.wallet.set_balance(2500)
	var events: Array[int] = []
	bag.changed.connect(func() -> void:
		if world.cooking.busy and world.cooking.queue.size() == 2:
			events.append(world.player.wallet.balance)
			assert_eq(bag.count_item(&"wood"), 0)
			assert_eq(world.cooking.start("grafting_wax", 1, bag, now, world.player.wallet), "Cooking is unavailable.")
	)
	assert_eq(world.cooking.start("grafting_wax", 2, bag, now, world.player.wallet), "")
	assert_eq(events, [500])
	assert_eq(world.cooking.collect(bag, now + 60), 1)
	assert_eq(world.cooking.collect(bag, now + 120), 1)
	assert_eq(world.cooking.collect(bag, now + 120), 0)
	assert_eq(bag.count_item(GraftService.WAX), 2)

func test_orchard_48h_pending_graft_single_and_hourly_steps_match() -> void:
	var tree: FruitTree = _fruit()
	tree.pending_graft = FruitTree.Graft.QUALITY
	tree.graft_revision = 1
	_orchard()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("graft_offline", 1, now)
	service.advance(now + 172800)
	var single: Dictionary = adapter.capture("graft_offline", 2, now + 172800)
	assert_gt(service.output_inventory().count_item(&"apple_star"), 0)
	assert_true(adapter.restore(saved, now).ok)
	for hour: int in range(1, 49):
		service.advance(now + hour * 3600)
	var stepped: Dictionary = adapter.capture("graft_offline", 2, now + 172800)
	assert_eq(stepped.storages, single.storages)
	assert_eq(stepped.trees, single.trees)
	assert_eq(stepped.coins, single.coins)
	assert_eq(stepped.workers, single.workers)
