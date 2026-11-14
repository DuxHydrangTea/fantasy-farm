extends GutTest
## The rest area must be accessible without obstructing the farm's main road.
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

func test_main_road_and_bench_approaches_remain_clear() -> void:
	assert_true(navigation._segment_clear(Vector2(128, 240), Vector2(420, 240)), "Decoration leaves the main road open")
	for point: Vector2 in [Vector2(112, 224), Vector2(276, 218), Vector2(120, 160), Vector2(206, 124), Vector2(168, 148)]:
		assert_true(navigation._point_clear(point), "The real player footprint fits at %s" % point)

func test_clicked_rest_spots_can_be_reached_from_the_main_road() -> void:
	for target: Vector2 in [Vector2(120, 160), Vector2(112, 224), Vector2(276, 218), Vector2(206, 124), Vector2(168, 148)]:
		navigation.cancel()
		world.player.global_position = Vector2(336, 240)
		navigation.request_focus(target)
		for frame: int in range(480):
			navigation.move(1.0 / 60.0)
			if not navigation.is_navigating:
				break
			await wait_physics_frames(1)
		assert_false(navigation.is_navigating, "The route to %s finishes" % target)
		assert_lte(world.player.global_position.distance_to(target), navigation.interaction_distance + world.player.state.movement.arrival_distance, "Clicking %s reaches the rest spot" % target)
		assert_true(navigation._point_clear(world.player.global_position), "Arrival never overlaps a bench, tree or lamp")

func test_bench_feet_block_movement_and_lamps_have_runtime_light_textures() -> void:
	assert_false(navigation._segment_clear(Vector2(84, 210), Vector2(140, 210)), "The river bench has a solid footprint")
	assert_false(navigation._segment_clear(Vector2(248, 204), Vector2(306, 204)), "The birch bench has a solid footprint")
	assert_false(navigation._segment_clear(Vector2(140, 130), Vector2(196, 130)), "The tent has a solid base and an open approach in front")
	for name: String in ["PathLantern", "RiverLantern"]:
		var light: PointLight2D = world.get_node("RiversideRest/" + name + "/PointLight2D") as PointLight2D
		assert_true(light.is_in_group(&"street_lamp_lights"), "The lamp participates in the existing day/night system")
		assert_not_null(light.texture, "The existing atmosphere supplies a real light texture")
