extends GutTest
## Walk real player routes through the meadow and preserve the existing street.
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

func test_rest_spots_are_reachable_from_the_public_road() -> void:
	var routes: Array[Vector2] = [
		Vector2(2192, 272), Vector2(1992, 472),
		Vector2(2424, 688), Vector2(2176, 920)
	]
	for target: Vector2 in routes:
		navigation.cancel()
		world.player.global_position = Vector2(1856, 240) if target.y < 400 else Vector2(1856, 456) if target.y < 800 else Vector2(1912, 920)
		navigation.request_focus(target)
		for frame: int in range(720):
			navigation.move(1.0 / 60.0)
			if not navigation.is_navigating:
				break
			await wait_physics_frames(1)
		assert_false(navigation.is_navigating, "The meadow route to %s finishes" % target)
		assert_lte(world.player.global_position.distance_to(target), navigation.interaction_distance + world.player.state.movement.arrival_distance, "The rest spot can be reached")
		assert_true(navigation._point_clear(world.player.global_position), "Arrival clears all decoration")

func test_trail_links_and_bench_approaches_fit_the_player() -> void:
	for point: Vector2 in [Vector2(1856, 240), Vector2(1912, 920), Vector2(2192, 272), Vector2(2080, 530), Vector2(2144, 482), Vector2(2424, 688), Vector2(2176, 920)]:
		assert_true(navigation._point_clear(point), "Player fits at %s" % point)
	assert_false(navigation._segment_clear(Vector2(2150, 902), Vector2(2200, 902)), "The south bench has a solid base")
	var meadow: Node2D = world.get_node("EastMeadowDecor") as Node2D
	for lamp: String in ["NorthLamp", "EastLamp", "GardenLamp", "SouthLamp"]:
		var light: PointLight2D = meadow.get_node(lamp + "/PointLight2D") as PointLight2D
		assert_true(light.is_in_group(&"street_lamp_lights"))
		assert_not_null(light.texture, "Meadow lights use the existing atmosphere")

func test_picnic_and_grove_have_clear_player_approaches() -> void:
	for point: Vector2 in [Vector2(2136, 612), Vector2(2072, 652), Vector2(2180, 652), Vector2(2040, 780)]:
		assert_true(navigation._point_clear(point), "Player fits at the new rest spot %s" % point)
	assert_true(navigation._segment_clear(Vector2(2136, 580), Vector2(2136, 624)), "The picnic has an open approach")

func test_world_edges_and_eastern_fence_block_escape() -> void:
	for y: int in range(16, 1696, 32):
		assert_false(navigation._segment_clear(Vector2(2532, y), Vector2(2560, y)), "East outer limit is closed at %s" % y)
		assert_false(navigation._segment_clear(Vector2(12, y), Vector2(-16, y)), "West outer limit is closed at %s" % y)
	for x: int in range(16, 2544, 32):
		assert_false(navigation._segment_clear(Vector2(x, 12), Vector2(x, -16)), "North outer limit is closed at %s" % x)
		assert_false(navigation._segment_clear(Vector2(x, 1684), Vector2(x, 1712)), "South outer limit is closed at %s" % x)

func test_visible_east_fence_has_no_gaps_without_the_outer_safety_wall() -> void:
	# Isolate the two visible fences from trees, water and the outer safety wall.
	# Otherwise an unrelated obstacle can hide a missing fence segment.
	const FENCE_MASK: int = 1 << 20
	for path: String in ["WorldBoundary/VillageFence", "StorageYard/PerimeterFence"]:
		var fence: TileMapLayer = world.get_node(path) as TileMapLayer
		fence.tile_set = fence.tile_set.duplicate(true) as TileSet
		fence.tile_set.set_physics_layer_collision_layer(0, FENCE_MASK)
	world.player.collision_mask = FENCE_MASK
	await wait_physics_frames(2)
	for y: int in range(80, 1616, 2):
		assert_false(navigation._segment_clear(Vector2(2478, y), Vector2(2540, y)), "The visible fence itself blocks the player at y=%s" % y)
