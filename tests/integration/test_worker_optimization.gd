extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var service: WorkerService
var now: float
var old_source: Callable
var old_floor: float
var old_processing: bool

class CountingPolicy extends CropWorkerPolicy:
	var planting_calls: int = 0
	func planting_task(row: Dictionary) -> Dictionary:
		planting_calls += 1
		return super.planting_task(row)

func before_each() -> void:
	old_source = TimeManager.clock_source
	old_floor = TimeManager._last_timestamp
	old_processing = TimeManager.is_processing()
	TimeManager.set_process(false)
	TimeManager._last_timestamp = 1793500000.0
	TimeManager.clock_source = func() -> float: return 1793500000.0
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	service = world.workers
	now = world.farming.time_manager.now()
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_blocks(16, 8)
	world.player.wallet.set_balance(10000000)
	world.trees.reset()
	for pen: AnimalPen in service.bridge.pens():
		for node: Node in pen.get_children():
			if node is AnimalTrough:
				node.stock = node.capacity

func after_each() -> void:
	TimeManager.clock_source = old_source
	TimeManager._last_timestamp = old_floor
	TimeManager.set_process(old_processing)

func test_busy_crop_worker_checks_urgent_ranch_without_searching_for_another_plot() -> void:
	service.hire("crop")
	var policy: CountingPolicy = CountingPolicy.new(world)
	service.crop_policy = policy
	var row: Dictionary = service.record("crop")
	row.task = policy.task("plant", Vector2i(54, 25), 4)
	row.task.merge({"work_at": now + 90.0, "finish_at": now + 100.0})
	service.advance(now + 0.5, false)
	assert_eq(policy.planting_calls, 0, "Preemption must not execute full crop candidate scanning")
	assert_eq(row.task.kind, "plant")
	row.water_units = 30
	var water: AnimalTrough = world.get_node("BarnPen/WaterTrough") as AnimalTrough
	water.stock = 0
	service.advance(now + 0.75, false)
	assert_eq(row.task.kind, "water_trough", "Urgent animal demand must still interrupt crop work")

func test_reservation_snapshot_tracks_prepared_cells_items_pause_and_dismissal() -> void:
	for index: int in range(3):
		service.hire("crop")
	var first: Dictionary = service.records[0]
	var second: Dictionary = service.records[1]
	var cell: Vector2i = Vector2i(54, 25)
	first.task = {"kind": "plant", "cell": [54, 25], "item": "carrot_seed", "work_at": now + 90.0, "finish_at": now + 100.0}
	service.crop_automation.prepared[first.id] = Vector2i(55, 25)
	var held: Dictionary = service.reservations(String(second.id))
	assert_true(held.cells.has(cell))
	assert_true(held.cells.has(Vector2i(55, 25)))
	assert_eq(int(held.items.get("carrot_seed", 0)), 1)
	assert_false(service.reservations(String(first.id)).cells.has(cell), "The owner can continue its own prepared plot")
	first.active = false
	assert_false(service.reservations(String(second.id)).cells.has(cell), "An unpaid worker must release its reservation")
	first.active = true
	service.dismiss(String(first.id))
	assert_false(service.reservations(String(second.id)).cells.has(cell))
	assert_false(service.crop_automation.prepared.has(first.id))

func test_online_row_budget_resumes_without_duplicate_assignments_or_checkpoint_changes() -> void:
	for index: int in range(3):
		service.hire("crop")
	service.feed_inventory("crop").add(preload("res://items/seeds/carrot_seed.tres"), 1000)
	service.configure_crop(true, false, false)
	var checkpoint: Dictionary = service.capture(now)
	var until: float = now + 0.25
	service.advance(until, false)
	var expected: Dictionary = service.capture(until)
	service.restore(checkpoint, SaveCatalog.new())
	var attempts: int = 0
	while not service.advance(until, false, 1):
		attempts += 1
		assert_false(service.busy, "Frame yields must release the service lock")
		if attempts > 2000:
			fail_test("Budgeted event did not finish")
			return
	assert_gt(attempts, 1)
	assert_eq(service.capture(until), expected, "Budget changes must not reorder assignment or change saved task times")
	var reserved: Dictionary = {}
	for row: Dictionary in service.records:
		var key: String = service.target_key(row.task)
		if not key.is_empty():
			assert_false(reserved.has(key), "Two workers cannot own the same target")
			reserved[key] = true

func test_offline_checkpoint_pickup_notification_preserves_planned_patrol() -> void:
	service.hire("crop")
	var row: Dictionary = service.record("crop")
	var patrol: Dictionary = {"kind": "patrol", "point": row.position.duplicate(), "finish_at": now + 60.0}
	row.task = patrol.duplicate(true)
	var pile: ItemPickup = ItemPickup.create()
	pile.item = preload("res://items/trees/apple.tres")
	pile.amount = 1
	world.add_child(pile)
	service.prepare_simulation_event(true)
	assert_eq(row.task, patrol, "Publishing an offline checkpoint must preserve scheduled work")
	service.request_scan("crop")
	assert_true(row.task.is_empty(), "External gameplay changes still interrupt idle patrol")

func test_rescan_preserves_due_patrol_until_arrival_is_committed() -> void:
	service.hire("crop")
	var row: Dictionary = service.record("crop")
	var actor: WorkerActor = service.actor_for(String(row.id))
	var destination: Vector2 = actor.global_position + Vector2(50, 0)
	row.task = {"kind": "patrol", "point": WorkerRole.pair(destination), "finish_at": now}
	service.request_scan("crop")
	assert_false(row.task.is_empty(), "A rescan at arrival must leave the due task for the scheduler to finish")
	service.simulated_at = now
	service._scheduler._finish_due_task(service, row, actor, true)
	assert_eq(actor.global_position, destination)
	assert_eq(WorkerRole.point(row.position), destination)
	assert_true(row.task.is_empty())

func test_nearly_ready_fruit_keeps_a_wake_instead_of_waiting_for_dawn() -> void:
	service.hire("crop")
	var row: Dictionary = service.record("crop")
	var tree: FruitTree = world.trees.create_tree(Vector2i(12, 61), world.trees.definitions[&"apple"], now) as FruitTree
	tree.growth_started_at = now - tree.definition.growth_seconds - 1.0
	tree.matures_at = now - 1.0
	tree.last_at = now
	tree.fruit_work = tree.definition.fruit_cycle_seconds - 0.005
	service.bridge.invalidate_ranch()
	assert_almost_eq(service.bridge.next_wake(row, service.feed_inventory(row.id), now), now + 0.25, 0.000001, "The final milliseconds of growth still need a scheduler event")

func test_trough_updates_only_interrupt_patrol_when_refill_becomes_possible() -> void:
	service.hire("crop")
	var row: Dictionary = service.record("crop")
	var trough: AnimalTrough = world.get_node("BarnPen/WaterTrough") as AnimalTrough
	var threshold: int = trough.capacity - trough.water_per_use
	var patrol: Dictionary = {"kind": "patrol", "point": row.position.duplicate(), "finish_at": now + 60.0}
	row.task = patrol.duplicate(true)
	service.trough_levels[trough.get_instance_id()] = threshold + 1
	service._trough_changed(threshold, trough)
	assert_true(row.task.is_empty(), "New refill demand interrupts idle walking")
	row.task = patrol.duplicate(true)
	service._trough_changed(threshold - 1, trough)
	assert_eq(row.task, patrol, "Further depletion must not introduce checkpoint-dependent interruptions")
	service._trough_changed(trough.capacity, trough)
	assert_eq(row.task, patrol, "Refilling does not create another demand")

func test_area_task_keeps_wake_checkpoint_until_last_cell() -> void:
	service.hire("crop")
	var row: Dictionary = service.record("crop")
	var actor: WorkerActor = service.actor_for(String(row.id))
	var wake: float = now - 10.0
	row.wake_at = wake
	# Invalidated cells are skipped but still advance the batch cursor.
	row.task = {"kind": "till", "point": WorkerRole.pair(actor.global_position), "cells": [[-1, -1], [-2, -1]], "cursor": 0, "finish_at": now}
	service.simulated_at = now
	service._scheduler._finish_due_task(service, row, actor, true)
	assert_eq(int(row.task.cursor), 1)
	assert_eq(float(row.wake_at), wake, "A partial batch must preserve its saved wake checkpoint")
	service.simulated_at = float(row.task.finish_at)
	service._scheduler._finish_due_task(service, row, actor, true)
	assert_true(row.task.is_empty())
	assert_eq(float(row.wake_at), service.simulated_at, "Wake changes when the final cell completes")

func test_idle_stroll_is_local_and_falls_back_to_rest_instead_of_distant_path() -> void:
	service.hire("crop")
	var row: Dictionary = service.record("crop")
	var origin: Vector2 = WorkerRole.point(row.position)
	var point: Vector2 = service.bridge.patrol_point(row)
	assert_lte(origin.distance_to(point), 128.01)

func test_static_body_addition_and_removal_invalidate_only_affected_cached_cells() -> void:
	var system: WorkerNavigationSystem = service.navigation
	var cells: Dictionary = {Vector2i(10, 10): true, Vector2i(40, 40): true}
	system.caches["fixture"] = {"origin": Vector2(8, 8), "size": 8.0, "cells": cells}
	var wall: StaticBody2D = StaticBody2D.new()
	wall.position = Vector2(88, 88)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	assert_false(cells.has(Vector2i(10, 10)))
	assert_true(cells.has(Vector2i(40, 40)), "Unrelated terrain cache must survive")
	cells[Vector2i(10, 10)] = false
	world.remove_child(wall)
	assert_false(cells.has(Vector2i(10, 10)), "Removed obstacles must become eligible for sampling again")
	assert_true(cells.has(Vector2i(40, 40)))
	wall.free()

func test_trough_access_cache_is_shared_at_distance_and_revalidated_after_geometry_changes() -> void:
	service.hire("crop")
	var row: Dictionary = service.record("crop")
	var actor: WorkerActor = service.actor_for(String(row.id))
	var pen: AnimalPen = service.bridge.pens()[0]
	var trough: AnimalTrough
	for child: Node in pen.get_children():
		if child is AnimalTrough:
			trough = child as AnimalTrough
			break
	assert_not_null(trough)
	service.bridge._trough_point(row, pen, trough)
	var count: int = service.bridge.trough_physics_queries
	assert_gt(count, 0)
	actor.global_position += Vector2(300, 0)
	service.bridge._trough_point(row, pen, trough)
	assert_eq(service.bridge.trough_physics_queries, count, "A far-away worker must reuse the same access geometry")
	service.navigation.invalidate_region(Rect2(trough.global_position - Vector2(32, 32), Vector2(64, 64)))
	service.bridge._trough_point(row, pen, trough)
	assert_gt(service.bridge.trough_physics_queries, count)

func test_shared_navigation_round_robin_finishes_direct_requests_without_private_grids() -> void:
	# A separate physics space isolates the path test from the authored buildings.
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	var camera: Camera2D = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 512
	camera.limit_bottom = 512
	viewport.add_child(camera)
	var navigators: Array[WorkerNavigation] = []
	for index: int in range(15):
		var actor: WorkerActor = preload("res://scenes/workers/crop_worker.tscn").instantiate() as WorkerActor
		viewport.add_child(actor)
		actor.behaviour.set_physics_process(false)
		actor.global_position = Vector2(64, 32 + index * 24)
		var nav: WorkerNavigation = WorkerNavigation.new()
		nav.movement = actor.movement
		nav.animation = actor.animation
		nav.collision_shape = actor.collision
		nav.camera = camera
		nav.system = service.navigation
		nav.allow_focus_cell = true
		nav.interaction_distance = 12.0
		actor.add_child(nav)
		navigators.append(nav)
	await wait_physics_frames(2)
	for nav: WorkerNavigation in navigators:
		nav.request_focus(nav.movement.body.global_position + Vector2(128, 0))
	for frame: int in range(60):
		service.navigation.pump()
		assert_lte(service.navigation.queries_last_step, WorkerNavigationSystem.QUERY_BUDGET)
		if service.navigation.jobs.is_empty():
			break
		await wait_physics_frames(1)
	assert_eq(service.navigation.caches.size(), 1, "Compatible workers must share terrain probes")
	assert_eq(service.navigation.completed_paths, 15, "Every worker must get its turn")
	for nav: WorkerNavigation in navigators:
		assert_null(nav._grid, "Workers must not allocate a full-map AStarGrid2D each")
		assert_false(nav._path.is_empty())
	viewport.queue_free()

func test_navigation_routes_around_wall_and_invalidates_changed_geometry() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	var camera: Camera2D = Camera2D.new()
	camera.limit_right = 512
	camera.limit_bottom = 512
	camera.limit_left = 0
	camera.limit_top = 0
	viewport.add_child(camera)
	var actor: WorkerActor = preload("res://scenes/workers/crop_worker.tscn").instantiate() as WorkerActor
	viewport.add_child(actor)
	actor.behaviour.set_physics_process(false)
	actor.global_position = Vector2(64, 128)
	var wall: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(16, 96)
	collision.shape = shape
	wall.add_child(collision)
	viewport.add_child(wall)
	wall.position = Vector2(128, 128)
	var nav: WorkerNavigation = WorkerNavigation.new()
	nav.movement = actor.movement
	nav.animation = actor.animation
	nav.collision_shape = actor.collision
	nav.camera = camera
	nav.system = service.navigation
	nav.allow_focus_cell = true
	nav.interaction_distance = 12.0
	actor.add_child(nav)
	await wait_physics_frames(2)
	nav.request_focus(Vector2(192, 128))
	for frame: int in range(600):
		service.navigation.pump()
		nav.move(1.0 / 60.0)
		assert_true(nav._point_clear(actor.global_position), "The swept footprint must never pass through the wall")
		if not nav.is_navigating:
			break
		await wait_physics_frames(1)
	assert_lte(actor.global_position.distance_to(Vector2(192, 128)), 12.0)
	var version: int = service.navigation.geometry_revision
	service.navigation.invalidate_region(Rect2(112, 72, 32, 112))
	assert_gt(service.navigation.geometry_revision, version)
	viewport.queue_free()
