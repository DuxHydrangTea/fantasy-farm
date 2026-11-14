extends GutTest
## Authored decoration must preserve the gate, door and every feeding station.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var navigation: PlayerNavigationComponent

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.land.state.restore_blocks(13, 4)
	navigation = world.player.state.navigation
	# Disabled CharacterBody2D nodes are removed from the physics space.
	# Keep the real physics world active and drive only player movement manually.
	world.process_mode = Node.PROCESS_MODE_INHERIT
	world.player.state.set_physics_process(false)
	navigation.set_physics_process(false)
	await wait_physics_frames(2)

func test_gate_and_coop_door_remain_clear() -> void:
	assert_true(navigation._segment_clear(Vector2(1192, 258), Vector2(1192, 334)), "The full gate approach fits the player")
	assert_true(navigation._segment_clear(Vector2(1325, 350), Vector2(1325, 394)), "Straw, nests and supplies leave the door clear")
	var home: Vector2 = world.workers.bridge.home("ranch", String(world.get_node("CoopPen").persistent_id))
	assert_true(navigation._point_clear(home), "The existing worker water pickup remains usable beside the well")

func test_each_relocated_trough_has_a_reachable_player_approach() -> void:
	for name: String in ["FeedTrough", "FeedTrough2", "WaterTrough", "WaterTrough2"]:
		var trough: AnimalTrough = world.get_node("CoopPen/" + name) as AnimalTrough
		navigation.cancel()
		world.player.global_position = Vector2(1192, 310)
		navigation.request_focus(trough.global_position)
		for frame: int in range(360):
			navigation.move(1.0 / 60.0)
			if not navigation.is_navigating:
				break
			await wait_physics_frames(1)
		assert_false(navigation.is_navigating, name + " completes its route")
		assert_lte(world.player.global_position.distance_to(trough.global_position), navigation.interaction_distance + world.player.state.movement.arrival_distance, name + " is within refill reach")
		assert_true(navigation._point_clear(world.player.global_position), name + " has a safe standing point")

func test_decorative_solids_block_only_their_feet() -> void:
	assert_false(navigation._segment_clear(Vector2(1348, 316), Vector2(1388, 316)), "The stacked bales have a physical footprint")
	assert_false(navigation._segment_clear(Vector2(1052, 353), Vector2(1092, 353)), "The well has a physical footprint")
	assert_true(navigation._segment_clear(Vector2(1120, 420), Vector2(1180, 420)), "The middle of the roaming yard stays open")
