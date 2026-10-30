extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var service: WorkerService
var clock: Array[float]
var now: float
var original_clock: Callable
var original_clock_floor: float
var _full_limits: Rect2i

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
	assert_eq(service.hire("crop"), "")
	var camera: Camera2D = world.player.camera
	_full_limits = Rect2i(camera.limit_left, camera.limit_top, camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)
	for pile: Node in world.get_tree().get_nodes_in_group(&"item_pickups"):
		pile.free()

func after_each() -> void:
	world.farming.time_manager.clock_source = original_clock
	world.farming.time_manager._last_timestamp = original_clock_floor

## Physics queries only see bodies once the world has processed physics frames
## (same pattern as test_crop_automation.gd). Bodies added while the world is
## DISABLED never register, so keep this on until after any runtime bodies exist.
func _enable_physics() -> void:
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.player.state.set_physics_process(false)
	var row: Dictionary = service.record("crop")
	var actor: WorkerActor = service.actor_for(row.id)
	actor.behaviour.set_physics_process(false)
	await wait_physics_frames(2)

func _freeze_physics() -> void:
	world.process_mode = Node.PROCESS_MODE_DISABLED

func _shrink_camera_to_village() -> void:
	var ground: TileMapLayer = world.farming.farmland
	var center: Vector2 = ground.to_global(ground.map_to_local(Vector2i(30, 5)))
	var camera: Camera2D = world.player.camera
	camera.limit_left = int(center.x) - 160
	camera.limit_top = int(center.y) - 160
	camera.limit_right = int(center.x) + 160
	camera.limit_bottom = int(center.y) + 160

func test_stroll_point_stays_within_camera_bounds_and_outside_zone() -> void:
	_shrink_camera_to_village()
	await _enable_physics()
	await _freeze_physics()
	var row: Dictionary = service.record("crop")
	var point: Vector2 = service.bridge.patrol_point(row)
	var camera: Camera2D = world.player.camera
	assert_true(point.x >= float(camera.limit_left) and point.x <= float(camera.limit_right))
	assert_true(point.y >= float(camera.limit_top) and point.y <= float(camera.limit_bottom))
	assert_false(service.bridge.zone_contains(row, point))

func test_stroll_avoids_recently_blocked_target() -> void:
	_shrink_camera_to_village()
	await _enable_physics()
	await _freeze_physics()
	var row: Dictionary = service.record("crop")
	var first: Vector2 = service.bridge.patrol_point(row)
	var key: String = "%s:patrol:%d_%d" % [String(row.id), roundi(first.x), roundi(first.y)]
	service.blocked_targets[key] = world.farming.time_manager.now() + 120.0
	var second: Vector2 = service.bridge.patrol_point(row)
	assert_ne(second, first)

func test_stroll_falls_back_to_zone_corner_when_no_walkable_point() -> void:
	# 60x60 px of camera bounds: after the sampler's -24 grow and the 48 px
	# minimum stroll distance every candidate is rejected, exhausting the
	# sampler without depending on physics-space registration in tests.
	_shrink_camera_to_village()
	var camera: Camera2D = world.player.camera
	camera.limit_right = int(camera.limit_left) + 60
	camera.limit_bottom = int(camera.limit_top) + 60
	var row: Dictionary = service.record("crop")
	var actor: WorkerActor = service.actor_for(row.id)
	var center: Vector2 = Vector2(camera.limit_left, camera.limit_top) + Vector2(30, 30)
	actor.global_position = center
	row.position = WorkerRole.pair(center)
	var point: Vector2 = service.bridge.patrol_point(row)
	assert_true(service.bridge.zone_contains(row, point))

func test_idle_worker_patrols_outside_their_zone() -> void:
	_shrink_camera_to_village()
	service.advance(now + 0.5)
	var task: Dictionary = service.record("crop").task
	assert_eq(String(task.get("kind")), "patrol")
	assert_false(service.bridge.zone_contains(service.record("crop"), WorkerRole.point(task.point)))

func test_rest_between_strolls_is_one_to_three_seconds() -> void:
	var rest: float = service.bridge.rest_seconds(service.record("crop"))
	assert_true(rest >= 1.0 and rest <= 3.0)

func test_worker_rests_between_strolls_after_commit() -> void:
	_shrink_camera_to_village()
	var t: float = now + 0.5
	var found: bool = false
	for step: int in range(400):
		t += 1.0
		service.advance(t)
		var row: Dictionary = service.record("crop")
		if row.task.is_empty() and float(row.wake_at) > t:
			found = true
			break
	assert_true(found, "After a stroll commits, the worker rests with wake_at 1-3s ahead")

func test_online_arrival_deferral_keeps_task() -> void:
	# Online ticks while the actor is still walking must keep extending the
	# same task (finish_at +0.25s), never drop and re-roll it.
	_shrink_camera_to_village()
	service.advance(now + 0.5)
	var row: Dictionary = service.record("crop")
	var start_id: String = String(row.task.get("id"))
	var t: float = now + 0.5
	for i: int in range(300):
		t += 0.25
		service.advance(t, false)
	var after: Dictionary = service.record("crop").task
	assert_false(after.is_empty(), "A walking worker keeps its task online")
	assert_eq(String(after.get("id")), start_id, "Online deferral must extend the same task, not re-roll it")

func test_save_schema_accepts_out_of_zone_patrol_task() -> void:
	_shrink_camera_to_village()
	service.advance(now + 0.5)
	# Preflight validates against the production camera bounds, so restore the
	# full world view before capturing: the strolling worker itself is at the
	# farm spawn while its stroll target sits in the village.
	var camera: Camera2D = world.player.camera
	camera.limit_left = _full_limits.position.x
	camera.limit_top = _full_limits.position.y
	camera.limit_right = _full_limits.end.x
	camera.limit_bottom = _full_limits.end.y
	clock[0] = now + 0.5
	var catalog: SaveCatalog = SaveCatalog.new()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var snapshot: Dictionary = adapter.capture("stroll_test", 1, world.farming.time_manager.now())
	assert_true(SaveSchema.validate(snapshot, catalog).ok)
	var preflight: Dictionary = adapter.preflight(snapshot)
	assert_true(bool(preflight.ok), "Preflight: " + str(preflight))
