extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const APPLE: ItemDefinition = preload("res://items/trees/apple.tres")
var world: FarmWorld
var now: float
const FIXED_TIME: float = 1793155000.0
var _old_clock_source: Callable
var _old_clock_floor: float

func before_each() -> void:
	_old_clock_source = TimeManager.clock_source
	_old_clock_floor = TimeManager._last_timestamp
	TimeManager._last_timestamp = FIXED_TIME
	TimeManager.clock_source = func() -> float: return FIXED_TIME
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(48, 4)
	world.player.wallet.set_balance(10000)
	now = world.farming.time_manager.now()
	var fixed: float = now
	world.farming.time_manager.clock_source = func() -> float: return fixed
	world.weather.schedule.seed = 12345
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	world.trees.reset()
	# The fixture spans ten columns; the current save schema requires ownership.
	assert_true(world.tree_plot_upgrades.state.restore({"fruit": 10, "timber": 1}))
	for i: int in range(10):
		var cell: Vector2i = Vector2i(12 + i * 3, 61)
		assert_true(TreePlotUpgradeState.allows(world.tree_plot_upgrades.state.capture(), cell, TreeDefinition.Kind.FRUIT))
		var tree: FruitTree = world.trees.create_tree(cell, world.trees.definitions[&"apple"], now) as FruitTree
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
	assert_eq(world.workers.hire("crop"), "")
	assert_eq(world.workers.hire("crop"), "")
	assert_eq(world.workers.hire("crop"), "")


func after_each() -> void:
	TimeManager.clock_source = _old_clock_source
	TimeManager._last_timestamp = _old_clock_floor


func _checkpoint_ok(adapter: WorldStateAdapter, snapshot: Dictionary) -> bool:
	var checked: Dictionary = SaveSchema.validate(snapshot, adapter.catalog)
	assert_true(checked.ok, "Checkpoint validation: " + str(checked))
	if not checked.ok:
		return false
	var preflight: Dictionary = adapter.preflight(snapshot)
	assert_true(preflight.ok, "Checkpoint preflight: " + str(preflight))
	return bool(preflight.ok)

func _restore_ok(adapter: WorldStateAdapter, snapshot: Dictionary, timestamp: float) -> bool:
	var restored: Dictionary = adapter.restore(snapshot, timestamp)
	assert_true(restored.ok, "Checkpoint restore: " + str(restored))
	return bool(restored.ok)

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
	if not _checkpoint_ok(adapter, checkpoint):
		return
	if not _restore_ok(adapter, checkpoint.duplicate(true), now):
		return
	var initial_single: Dictionary = adapter.capture("parity_test", 1, now)
	if not _compare_world(checkpoint, initial_single, "roundtrip"):
		return
	var started: int = Time.get_ticks_usec()
	world.workers.advance(now + 172800)
	var single: Dictionary = _signature(now + 172800)
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000.0
	if not _restore_ok(adapter, checkpoint.duplicate(true), now):
		return
	var initial_stepped: Dictionary = adapter.capture("parity_test", 1, now)
	if not _compare_world(initial_single, initial_stepped, "initial"):
		return
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

# Deadlines/timestamps use 1µs (< scheduler's 10µs boundary); accumulated
# needs, age, production seconds and moisture use 0.01 in their own units.
# Normalized crop progress and trough fractions use 1e-6 (one millionth).
func _float_tolerance(path: String) -> float:
	for field: String in ["satiety", "hydration", "production_progress", "age", "fruit_work", "moisture", "work", "contributions"]:
		if path.ends_with("." + field) or path.contains("." + field + ".") or path.contains("." + field + "["):
			return 0.01
	return 0.000001

func _compare_snapshot(expected: Variant, actual: Variant, path: String, report: bool = true) -> bool:
	var matches: bool = true
	if expected is Dictionary and actual is Dictionary:
		if report:
			assert_eq(actual.size(), expected.size(), path + " key count")
		matches = actual.size() == expected.size()
		for key: Variant in expected:
			if not actual.has(key):
				if report:
					assert_true(false, path + " missing key " + str(key))
				matches = false
				continue
			if not _compare_snapshot(expected[key], actual[key], path + "." + str(key), report):
				matches = false
	elif expected is Array and actual is Array:
		if report:
			assert_eq(actual.size(), expected.size(), path + " length")
		matches = actual.size() == expected.size()
		for i: int in range(mini(actual.size(), expected.size())):
			if not _compare_snapshot(expected[i], actual[i], path + "[" + str(i) + "]", report):
				matches = false
	elif expected is float and actual is float:
		var tolerance: float = _float_tolerance(path)
		if report:
			assert_almost_eq(actual, expected, tolerance, path)
		matches = absf(actual - expected) <= tolerance
	else:
		if report:
			assert_eq(actual, expected, path)
		matches = actual == expected
	return matches

func _compare_world(expected: Dictionary, actual: Dictionary, context: String) -> bool:
	var matches: bool = true
	for field: String in ["workers", "coins", "storages", "trees", "crops", "soil", "troughs", "animals", "weather", "beehives", "honey_garden"]:
		if not _compare_snapshot(expected[field], actual[field], context + "." + field):
			matches = false
	# Scene traversal order can change on restore; persistent IDs identify piles.
	var expected_piles: Dictionary = {}
	var actual_piles: Dictionary = {}
	for pile: Dictionary in expected.pickups:
		assert_false(expected_piles.has(pile.id), "Duplicate pickup ID in " + context)
		if expected_piles.has(pile.id):
			matches = false
		expected_piles[pile.id] = pile
	for pile: Dictionary in actual.pickups:
		assert_false(actual_piles.has(pile.id), "Duplicate pickup ID in " + context)
		if actual_piles.has(pile.id):
			matches = false
		actual_piles[pile.id] = pile
	if not _compare_snapshot(expected_piles, actual_piles, context + ".pickups"):
		matches = false
	return matches

func _prepare_matrix(large: bool) -> void:
	world.player.wallet.set_balance(1000000)
	world.storages.restore(FarmStorageSaveSchema.fresh(), SaveCatalog.new())
	if not large:
		assert_eq(world.trees.trees.size(), 10)
		assert_eq(world.farming.crop_cells().size(), 1)
		return
	assert_true(world.tree_plot_upgrades.state.restore({"fruit": TreePlotUpgradeState.MAX_LEVEL, "timber": 1}))
	for column: int in range(TreePlotUpgradeState.MAX_LEVEL):
		for row: int in range(TreePlotUpgradeState.SLOTS_PER_LEVEL):
			var cell: Vector2i = Vector2i(12 + column * 3, 61 + row * 3)
			assert_true(TreePlantation.valid_cell(cell, TreeDefinition.Kind.FRUIT))
			if world.trees.trees.has(cell):
				continue
			var tree: FruitTree = world.trees.create_tree(cell, world.trees.definitions[&"apple"], now) as FruitTree
			tree.planted_at = now - tree.definition.growth_seconds - 1
			tree.growth_started_at = tree.planted_at
			tree.matures_at = now - 1
			tree.last_at = now
			tree.fruit_work = tree.definition.fruit_cycle_seconds
			tree.refresh(now)
	var soil: Array = []
	for y: int in range(19, 23):
		for x: int in range(9, 57):
			soil.append({"cell": [x, y], "state": 1})
	world.farming.restore_soil(soil)
	for row: Dictionary in soil:
		var cell: Vector2i = Vector2i(int(row.cell[0]), int(row.cell[1]))
		world.farming.restore_crop(cell, SEED.crop as CropDefinition, now - 10, now + 50, 0.2, now)
	assert_eq(world.trees.trees.size(), TreePlotUpgradeState.MAX_LEVEL * TreePlotUpgradeState.SLOTS_PER_LEVEL)
	assert_eq(world.farming.crop_cells().size(), 192)

func _phase(phase: String, large: bool, hours: int) -> void:
	print("T02_MATRIX_PHASE ", JSON.stringify({"phase": phase, "large": large, "hours": hours, "ticks_ms": Time.get_ticks_msec()}))

func _matrix_parity(large: bool, hours: int) -> void:
	_phase("setup_start", large, hours)
	_prepare_matrix(large)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checkpoint: Dictionary = adapter.capture("parity_test", 1, now)
	if not _checkpoint_ok(adapter, checkpoint):
		return
	assert_eq(checkpoint.workers.rows.size(), 3)
	assert_eq(checkpoint.animals.size(), 3)
	_phase("setup_complete", large, hours)
	print("T02_MATRIX_INPUT ", JSON.stringify({"start": now, "weather_seed": world.weather.schedule.seed, "hours": hours, "large": large, "trees": checkpoint.trees.size(), "crops": checkpoint.crops.size(), "animals": checkpoint.animals.size(), "workers": checkpoint.workers.rows.size(), "supply": checkpoint.storages.farm_supply_storage, "engine": Engine.get_version_info().string}))
	_phase("restore_start", large, hours)
	if not _restore_ok(adapter, checkpoint.duplicate(true), now):
		return
	_phase("restore_complete", large, hours)
	var initial_single: Dictionary = adapter.capture("parity_test", 1, now)
	# Keep a separate roundtrip assertion: both replays must not share a bad restore.
	if not _compare_world(checkpoint, initial_single, "roundtrip"):
		return
	var end: float = now + hours * 3600.0
	_phase("single_advance_start", large, hours)
	world.workers.advance(end)
	_phase("single_advance_complete", large, hours)
	assert_false(world.workers.busy)
	assert_eq(world.farming.time_manager.simulation_timestamp, -1.0)
	_phase("single_capture_start", large, hours)
	var single: Dictionary = adapter.capture("parity_test", 2, end)
	_phase("single_capture_complete", large, hours)
	if not _checkpoint_ok(adapter, single):
		return
	_phase("restore_start", large, hours)
	if not _restore_ok(adapter, checkpoint.duplicate(true), now):
		return
	_phase("restore_complete", large, hours)
	var initial_stepped: Dictionary = adapter.capture("parity_test", 1, now)
	if not _compare_world(initial_single, initial_stepped, "initial"):
		return
	_phase("stepped_advance_start", large, hours)
	for hour: int in range(1, hours + 1):
		world.workers.advance(now + hour * 3600.0)
		if hour % 24 == 0:
			_phase("stepped_hour_" + str(hour), large, hours)
	_phase("stepped_capture_start", large, hours)
	var stepped: Dictionary = adapter.capture("parity_test", 2, end)
	_phase("stepped_capture_complete", large, hours)
	if not _checkpoint_ok(adapter, stepped):
		return
	if _compare_world(single, stepped, "end@" + str(end)):
		_phase("parity_passed", large, hours)
	assert_false(world.workers.busy)
	assert_eq(world.farming.time_manager.simulation_timestamp, -1.0)

func test_matrix_small_48_hours() -> void:
	_matrix_parity(false, 48)

func test_matrix_small_7_days() -> void:
	_matrix_parity(false, 168)

func _stress_enabled(mode: String) -> bool:
	if OS.get_environment("FARM_OFFLINE_STRESS") in [mode, "all"]:
		return true
	pending("Large offline " + mode + " stress not run; opt in with tests/run_tree_tests.py --offline-stress " + mode)
	return false

func test_matrix_large_48_hours() -> void:
	if _stress_enabled("48h"):
		_matrix_parity(true, 48)

func test_matrix_large_7_days() -> void:
	if _stress_enabled("7d"):
		_matrix_parity(true, 168)

func test_timestamp_tolerance_and_snapshot_schema() -> void:
	assert_lt(_float_tolerance("workers.simulated_at"), 0.001)
	assert_lt(_float_tolerance("workers.rows[0].task.work_at"), 0.00001)
	assert_eq(_float_tolerance("animals[0].satiety"), 0.01)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var checkpoint: Dictionary = adapter.capture("parity_test", 1, now)
	if not _checkpoint_ok(adapter, checkpoint):
		return
	var invalid: Dictionary = checkpoint.duplicate(true)
	invalid.workers.simulated_at = now - 0.005
	assert_false(SaveSchema.validate(invalid, adapter.catalog).ok, "Worker timestamp must match saved_at within 0.001 seconds")

func test_comparator_rejects_normalized_and_discrete_drift() -> void:
	assert_false(_compare_snapshot(0.5, 0.508, "crops[0].progress", false))
	assert_false(_compare_snapshot(0.25, 0.258, "troughs[0].consumed_fraction", false))
	assert_true(_compare_snapshot(0.5, 0.5000001, "crops[0].progress", false))
	assert_true(_compare_snapshot(75.0, 75.001, "animals[0].satiety", false))
	assert_false(_compare_snapshot(1793155000.0, 1793155000.005, "workers.simulated_at", false))
	assert_false(_compare_snapshot({"id": "one"}, {"id": "two"}, "pickups", false))
	assert_false(_compare_snapshot({"one": {}}, {}, "pickups", false))
	assert_false(_compare_snapshot({}, {"extra": {}}, "pickups", false))
	assert_false(_compare_snapshot({"count": 1, "tiers": [1, 0, 0]}, {"count": 2, "tiers": [1, 0, 0]}, "slots[0]", false))
	assert_false(_compare_snapshot([1, 0, 0], [0, 1, 0], "slots[0].tiers", false))
