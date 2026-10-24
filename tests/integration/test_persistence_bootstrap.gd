extends GutTest

const WORLD: PackedScene = preload("res://world/main_world.tscn")

func test_preview_can_be_freed_before_first_frame_without_resuming_a_dead_instance() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	add_child(world)
	world.free()
	await wait_process_frames(3)
	assert_null(SaveManager.adapter)

func test_deferred_main_scene_assignment_still_binds_persistence() -> void:
	var previous: Node = get_tree().current_scene
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	get_tree().root.add_child(world)
	# Startup can assign current_scene after the node's deferred _start call.
	get_tree().set_deferred("current_scene", world)
	await wait_process_frames(6)
	var persistence: WorldPersistence = world.get_node("WorldPersistence") as WorldPersistence
	assert_eq(persistence._service, SaveManager)
	assert_not_null(SaveManager.adapter)
	assert_true(SaveManager.writes_enabled)
	get_tree().current_scene = previous
	world.free()
	assert_null(SaveManager.adapter, "Removing the world releases the global save binding")

func test_preview_world_never_binds_the_save_service() -> void:
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	add_child_autofree(world)
	await wait_process_frames(6)
	var persistence: WorldPersistence = world.get_node("WorldPersistence") as WorldPersistence
	assert_null(persistence._service)
	assert_null(SaveManager.adapter)
