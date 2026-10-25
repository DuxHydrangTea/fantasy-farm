extends GutTest
## M0: worker body + waypoint patrol on the real world. No roles, no basket,
## no save — those arrive in M1+ per docs/hired_workers.md.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const WORKER: WorkerDefinition = preload("res://resources/workers/orchard_hand.tres")

func test_definition_is_valid_and_paced() -> void:
	assert_true(WORKER.is_valid())
	assert_between(WORKER.move_speed, 20.0, 400.0)
	assert_between(WORKER.work_seconds, 0.5, 10.0)
	assert_gt(WORKER.footprint.x, 0.0)
	for action: StringName in [&"idle_down", &"walk_down"]:
		assert_true(WORKER.frames.has_animation(action), String(action))

func test_actor_composes_components_and_reissues_goal_when_cancelled() -> void:
	var actor: WorkerActor = WorkerActor.new()
	actor.definition = WORKER
	add_child(actor)
	assert_not_null(actor.movement)
	assert_not_null(actor.animation)
	assert_not_null(actor.behaviour)
	assert_true(actor.is_in_group(&"grass_interactors"), "worker bends GPU grass")
	assert_eq(actor.movement.speed, WORKER.move_speed)
	var points: Array[Vector2] = [actor.global_position + Vector2(80, 0), actor.global_position + Vector2(80, 80)]
	actor.configure_patrol(points)
	await wait_frames(2)
	assert_true(actor.behaviour.has_goal)
	assert_true(actor.movement.has_target)
	# MovementComponent auto-cancels after ~0.2s blocked; the worker behaviour
	# must re-issue the same goal until its own 2s stuck budget runs out.
	actor.movement.cancel_target()
	await wait_frames(2)
	assert_true(actor.behaviour.has_goal, "goal survives the component's cancel")
	assert_almost_eq(actor.behaviour.current_goal.x, points[0].x, 0.5)
	actor.queue_free()
	await get_tree().process_frame

func test_actor_without_definition_stands_idle_safely() -> void:
	var actor: WorkerActor = WorkerActor.new()
	add_child(actor)
	assert_false(actor.behaviour.is_physics_processing())
	actor.queue_free()
	await get_tree().process_frame

func test_debug_world_spawns_patrolling_orchard_worker() -> void:
	if not OS.is_debug_build():
		pending("Debug worker only spawns in debug builds")
		return
	var scene: FarmWorld = WORLD.instantiate() as FarmWorld
	scene.debug_worker_enabled = true
	add_child(scene)
	var worker: WorkerActor = scene.debug_worker
	assert_not_null(worker)
	assert_eq(worker.get_parent(), scene, "worker sorts as a world-root sibling")
	assert_eq(worker.definition.worker_id, &"orchard_hand")
	assert_gte(worker.behaviour.patrol_points.size(), 3)
	var region: Rect2i = TreePlantation.FRUIT_REGION
	var ground: TileMapLayer = scene.farming.ground
	var a: Vector2 = ground.map_to_local(region.position)
	var b: Vector2 = ground.map_to_local(region.position + region.size)
	var bounds: Rect2 = Rect2(a, b - a).grow(-40.0)
	for point: Vector2 in worker.behaviour.patrol_points:
		assert_true(bounds.has_point(point), "waypoint %s inside fruit region" % [point])
	var start: Vector2 = worker.global_position
	await wait_seconds(2.0)
	assert_ne(worker.global_position, start, "worker is walking")
	assert_true(worker.behaviour.has_goal)
	scene.free()
	await get_tree().process_frame
