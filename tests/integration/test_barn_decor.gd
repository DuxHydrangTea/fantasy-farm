extends GutTest
## Yard decoration must leave room for ranch work and the larger cattle footprint.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var navigation: PlayerNavigationComponent

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.land.state.restore_blocks(13, 4)
	navigation = world.player.state.navigation
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.player.state.set_physics_process(false)
	navigation.set_physics_process(false)
	await wait_physics_frames(2)

func test_gate_door_and_worker_water_pickup_stay_clear() -> void:
	assert_true(navigation._segment_clear(Vector2(1224, 914), Vector2(1224, 838)), "The southern gate stays open")
	assert_true(navigation._segment_clear(Vector2(1198, 650), Vector2(1198, 710)), "The barn doorway has a clear apron")
	assert_true(navigation._segment_clear(Vector2(1224, 840), Vector2(1198, 670)), "The central cattle lane stays open")
	var home: Vector2 = world.workers.bridge.home("ranch", String(world.get_node("BarnPen").persistent_id))
	assert_true(navigation._point_clear(home), "The well does not cover the worker pickup")

func test_all_four_relocated_troughs_can_be_reached_from_the_gate() -> void:
	for name: String in ["FeedTrough", "FeedTrough2", "WaterTrough", "WaterTrough2"]:
		var trough: AnimalTrough = world.get_node("BarnPen/" + name) as AnimalTrough
		navigation.cancel()
		world.player.global_position = Vector2(1224, 852)
		navigation.request_focus(trough.global_position)
		for frame: int in range(420):
			navigation.move(1.0 / 60.0)
			if not navigation.is_navigating:
				break
			await wait_physics_frames(1)
		assert_false(navigation.is_navigating, name + " completes its route")
		assert_lte(world.player.global_position.distance_to(trough.global_position), navigation.interaction_distance + world.player.state.movement.arrival_distance, name + " is within refill reach")
		assert_true(navigation._point_clear(world.player.global_position), name + " provides a safe standing point")

func test_cattle_have_multiple_free_serving_slots_at_every_trough() -> void:
	var cow: AnimalActor = preload("res://scenes/animals/cow.tscn").instantiate() as AnimalActor
	cow.position = Vector2(190, 170)
	world.get_node("BarnPen").add_child(cow)
	cow.behaviour.set_physics_process(false)
	cow.wander.set_physics_process(false)
	var probe: WorkerNavigation = WorkerNavigation.new()
	probe.movement = cow.movement
	probe.animation = cow.animation
	probe.collision_shape = cow.collision
	probe.camera = world.player.camera
	cow.add_child(probe)
	await wait_physics_frames(2)
	for name: String in ["FeedTrough", "FeedTrough2", "WaterTrough", "WaterTrough2"]:
		var trough: AnimalTrough = world.get_node("BarnPen/" + name) as AnimalTrough
		var clear_slots: int = 0
		for offset: Vector2 in trough.access_offsets:
			if probe._point_clear(trough.to_global(offset)):
				clear_slots += 1
		assert_gte(clear_slots, 2, name + " accepts the actual 18×10 cattle footprint")

func test_hay_well_and_bench_have_grounded_collision() -> void:
	assert_false(navigation._segment_clear(Vector2(1300, 640), Vector2(1370, 640)), "The stacked bales block movement from a clear starting point")
	assert_false(navigation._segment_clear(Vector2(1048, 657), Vector2(1090, 657)), "The well blocks movement at its base")
	assert_false(navigation._segment_clear(Vector2(1070, 853), Vector2(1115, 853)), "The bench blocks movement at its feet")
