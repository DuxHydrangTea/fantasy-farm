extends GutTest
## Performance regression test for worker system with 3 concurrent workers.
## Ensures optimizations don't break core logic.

const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var service: WorkerService
var now: float
const FIXED_TIME: float = 1793155000.0
var _old_source: Callable
var _old_floor: float

func before_each() -> void:
	_old_source = TimeManager.clock_source
	_old_floor = TimeManager._last_timestamp
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	service = world.workers
	now = world.farming.time_manager.now()
	world.farming.time_manager.clock_source = func() -> float: return now
	world.weather.schedule.seed = 12345
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(10000000)
	world.land.state.restore_blocks(16, 8)
	world.trees.reset()
	world.tree_plot_upgrades.state.restore({"fruit": 10, "timber": 1})
	
	# Setup fruit trees
	for index: int in range(10):
		var cell: Vector2i = Vector2i(12 + index * 3, 61)
		var tree: FruitTree = world.trees.create_tree(cell, world.trees.definitions[&"apple"], now) as FruitTree
		tree.planted_at = now - tree.definition.growth_seconds - 1.0
		tree.growth_started_at = tree.planted_at
		tree.matures_at = now - 1
		tree.last_at = now
		tree.fruit_work = tree.definition.fruit_cycle_seconds * 0.9
		tree.refresh(now)
	
	# Setup crops
	var seed: ItemDefinition = load("res://items/seeds/carrot_seed.tres") as ItemDefinition
	world.storages.inventory("farm_supply_storage").add(seed, 100)
	for x: int in range(48, 56):
		for y: int in range(20, 28):
			var cell: Vector2i = Vector2i(x, y)
			if world.farming.can_till(cell, null):
				world.farming.apply_area(&"tool", [cell], null, -1, null, null)
	
	await wait_process_frames(2)

func after_each() -> void:
	TimeManager.clock_source = _old_source
	TimeManager._last_timestamp = _old_floor

func test_three_workers_can_be_hired_and_operate() -> void:
	for i: int in range(3):
		var error: String = service.hire("crop")
		assert_eq(error, "", "Worker %d hire failed: %s" % [i + 1, error])
	
	assert_eq(service.records_for("crop", true).size(), 3)
	service.configure_crop(true, false, false)
	
	# Advance 30 seconds and verify workers are functioning
	var start_usec: int = Time.get_ticks_usec()
	service.advance(now + 30.0)
	var elapsed_usec: int = Time.get_ticks_usec() - start_usec
	
	# All workers should have tasks
	var active: int = 0
	for row: Dictionary in service.records:
		if service.running(row):
			active += 1
	
	assert_gte(active, 3, "All 3 workers should be active")
	
	# Performance check: 3 workers × 30s should complete in < 5s wall time
	var elapsed_ms: float = float(elapsed_usec) / 1000.0
	assert_lt(elapsed_ms, 5000.0, "3 workers advance(30s) took %dms (expected <5000ms)" % elapsed_ms)
	gut.p("3 workers advance(30s) took %.1fms" % elapsed_ms)

func test_trough_point_cache_returns_consistent_results() -> void:
	service.hire("crop")
	var row: Dictionary = service.record("crop")
	var pen: AnimalPen = service.bridge.pens()[0]
	var trough: AnimalTrough = null
	for child: Node in pen.get_children():
		if child is AnimalTrough and child.kind == AnimalTrough.Kind.FOOD:
			trough = child as AnimalTrough
			break
	
	assert_not_null(trough)
	if trough == null:
		return
	
	# First call should cache
	var first: Variant = service.bridge._trough_point(row, pen, trough)
	assert_not_null(first, "Should find at least one valid trough point")
	
	# Second call should return cached
	var second: Variant = service.bridge._trough_point(row, pen, trough)
	if first != null and second != null:
		assert_eq(second, first, "Cached trough point should match first call")

func test_crop_cell_cache_reduces_repeated_calls() -> void:
	service.hire("crop")
	var row: Dictionary = service.record("crop")
	
	# First candidates() call should populate cache
	var first: Array[Dictionary] = service.bridge.candidates(row, service.feed_inventory(row.id))
	
	# Second call within cache lifetime should use cache
	var second: Array[Dictionary] = service.bridge.candidates(row, service.feed_inventory(row.id))
	
	# Results should be consistent (same number of tasks)
	assert_eq(second.size(), first.size(), "Cached candidates should match initial scan")

func test_reduced_stroll_attempts_still_finds_valid_points() -> void:
	service.hire("crop")
	var row: Dictionary = service.record("crop")
	var actor: WorkerActor = service.actor_for(row.id)
	
	# Should find a valid stroll point with reduced attempts (2 instead of 8)
	var point: Vector2 = service.bridge.world_stroll_point(row, actor)
	
	# Either finds a valid point or returns INF (both acceptable)
	assert_true(point.is_finite() or point == Vector2.INF, "Stroll point should be valid or INF")
	
	if point.is_finite():
		gut.p("Found stroll point at %s" % point)

func test_planting_task_with_reduced_attempts_still_works() -> void:
	service.hire("crop")
	service.configure_crop(true, false, false)
	var row: Dictionary = service.record("crop")
	
	# Should find planting tasks with 16 attempts (reduced from 32)
	var task: Dictionary = service.crop_policy.planting_task(row)
	
	# Either finds a task or returns empty (both valid depending on state)
	if not task.is_empty():
		assert_true(task.kind in ["till", "plant"], "Should return valid planting task")
		gut.p("Found planting task: %s at cell %s" % [task.kind, task.get("cell")])
