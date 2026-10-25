extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const APPLE: ItemDefinition = preload("res://items/trees/apple.tres")
var world: FarmWorld
var now: float

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(48, 4)
	world.player.wallet.set_balance(10000)
	now = world.farming.time_manager.now()
	var fixed: float = now
	world.farming.time_manager.clock_source = func() -> float: return fixed
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	world.trees.reset()
	for i: int in range(10):
		var tree: FruitTree = world.trees.create_tree(Vector2i(12 + i * 3, 61), world.trees.definitions[&"apple"], now) as FruitTree
		tree.planted_at = now - tree.definition.growth_seconds - 1
		tree.growth_started_at = tree.planted_at
		tree.matures_at = now - 1
		tree.last_at = now
		tree.fruit_work = tree.definition.fruit_cycle_seconds
		tree.refresh(now)
	world.farming.restore_soil([{"cell": [54, 25], "state": 1}])
	world.farming.restore_crop(Vector2i(54, 25), SEED.crop as CropDefinition, now - 10, now + 50, 0.2, now)
	for pair: Array in [["CoopPen", "chicken"], ["CoopPen", "chicken"], ["BarnPen", "cow"]]:
		var pen: AnimalPen = world.get_node(pair[0]) as AnimalPen
		var actor: AnimalActor = preload("res://scenes/animals/animal.tscn").instantiate() as AnimalActor
		actor.definition = load("res://animals/definitions/" + String(pair[1]) + ".tres") as AnimalDefinition
		actor.initial_age_seconds = actor.definition.maturity_seconds
		actor.pen = pen
		actor.position = pen.bounds.get_center()
		actor.needs.time_manager = world.farming.time_manager
		pen.add_child(actor)
		actor.needs.restore_state(100, 100, now)
	var source: InventoryComponent = world.storages.inventory("farm_supply_storage")
	for pen: AnimalPen in world.workers.bridge.pens():
		for node: Node in pen.get_children():
			if node is AnimalTrough:
				node.stock = 0
				if node.kind == AnimalTrough.Kind.FOOD:
					source.add(node.feed_item, 2)
	# A deliberately finite output inventory reaches the full boundary during catch-up.
	var data: Dictionary = world.storages.capture()
	data.produce_warehouse = {"slot_count": 3, "stack_cap": 1000, "slots": [{"item": "", "count": 0, "tiers": [0, 0, 0]}, {"item": "", "count": 0, "tiers": [0, 0, 0]}, {"item": "", "count": 0, "tiers": [0, 0, 0]}]}
	world.storages.restore(data, SaveCatalog.new())
	assert_eq(world.workers.hire("orchard"), "")
	assert_eq(world.workers.hire("ranch", String(world.workers.bridge.pens()[0].persistent_id)), "")
	assert_eq(world.workers.hire("crop"), "")

func _signature(timestamp: float) -> Dictionary:
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var data: Dictionary = adapter.capture("parity_test", 2, timestamp)
	var needs: Array = []
	for row: Dictionary in data.animals:
		needs.append([row.id, row.satiety, row.hydration, row.production_progress, row.production_stock, row.age])
	return {"storages": data.storages, "workers": data.workers, "troughs": data.troughs, "coins": data.coins, "crops": data.crops, "pickups": data.pickups, "needs": needs}

func test_all_roles_48h_single_jump_matches_hourly_checkpoints_at_empty_full_and_wage_boundaries() -> void:
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checkpoint: Dictionary = adapter.capture("parity_test", 1, now)
	var started: int = Time.get_ticks_usec()
	world.workers.advance(now + 172800)
	var single: Dictionary = _signature(now + 172800)
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000.0
	assert_true(adapter.restore(checkpoint, now).ok)
	for hour: int in range(1, 49):
		world.workers.advance(now + hour * 3600)
	var stepped: Dictionary = _signature(now + 172800)
	assert_eq(stepped.storages, single.storages)
	assert_eq(stepped.coins, single.coins)
	assert_eq(stepped.workers, single.workers)
	assert_eq(stepped.crops, single.crops)
	# Normalized pen units/needs permit only floating-point accumulation error.
	assert_eq(stepped.troughs.size(), single.troughs.size())
	for i: int in range(stepped.troughs.size()):
		assert_eq(stepped.troughs[i].id, single.troughs[i].id)
		assert_almost_eq(float(stepped.troughs[i].stock), float(single.troughs[i].stock), 0.001)
		assert_eq(stepped.troughs[i].feed_reserve, single.troughs[i].feed_reserve)
		assert_almost_eq(float(stepped.troughs[i].consumed_fraction), float(single.troughs[i].consumed_fraction), 0.001)
	assert_eq(stepped.needs.size(), single.needs.size())
	assert_eq(single.needs.size(), 3, "Live animals are included in parity, not empty pens")
	for i: int in range(stepped.needs.size()):
		assert_eq(stepped.needs[i][0], single.needs[i][0])
		for j: int in range(1, 6):
			assert_almost_eq(float(stepped.needs[i][j]), float(single.needs[i][j]), 0.01)
	var paused: int = 0
	for row: Dictionary in single.workers.rows:
		paused += 0 if row.active else 1
	assert_gt(paused, 0, "The fixture crosses an unpaid dawn")
	assert_eq(world.storages.inventory("farm_supply_storage").count_item(&"poultry_feed"), 0, "The fixture exhausts shared poultry feed")
	assert_true(SaveSchema.validate(adapter.capture("parity_test", 3, now + 172800), adapter.catalog).ok)
	print("STORAGE_PARITY_48H ", JSON.stringify({"elapsed_ms": elapsed, "coins": single.coins, "wages": 10000 - int(single.coins), "paused_workers": paused, "apples": world.workers.output_inventory().count_item(APPLE.item_id), "poultry_feed": world.storages.inventory("farm_supply_storage").count_item(&"poultry_feed")}))
