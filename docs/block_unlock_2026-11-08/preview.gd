extends SceneTree
func _initialize() -> void:
	call_deferred("preview")
func preview() -> void:
	var world: Node2D = load("res://world/main_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	for node: Node in world.find_children("*", "Camera2D", true, false):
		(node as Camera2D).enabled = false
	var farm: Node = world.get_node("FarmingController")
	var farmland: TileMapLayer = farm.farmland
	var camera: Camera2D = Camera2D.new()
	camera.position = farmland.to_global(farmland.map_to_local(Vector2i(33, 36)))
	camera.zoom = Vector2(1.25, 1.25)
	root.add_child(camera)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/block_unlock_2026-11-08/first_block.png") == OK)
	var repo: RefCounted = load("res://persistence/local_save_repository.gd").new()
	var loaded: Dictionary = repo.read_profile("local")
	assert(loaded.ok)
	print(JSON.stringify({"new_profile_blocks":world.land.state.unlocked_blocks,"old_save_blocks":loaded.snapshot.land_blocks,"old_save_crops":loaded.snapshot.crops.size(),"version":loaded.snapshot.version}))
	world.free()
	quit()
