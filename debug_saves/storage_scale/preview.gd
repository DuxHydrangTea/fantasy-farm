extends Node

func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	_run.call_deferred()

func _run() -> void:
	var world: FarmWorld = load("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	var catalog: SaveCatalog = SaveCatalog.new()
	var repo: LocalSaveRepository = LocalSaveRepository.new("user://saves", catalog)
	var saved: Dictionary = repo.read_profile("local")
	assert(saved.ok and saved.get("found", false))
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var restored: Dictionary = adapter.restore(saved.snapshot, float(saved.snapshot.saved_at))
	assert(restored.ok, str(restored.get("error")))
	world.player.global_position = Vector2(1150, 230)
	world.player.camera.position = Vector2(-150, -10)
	world.player.camera.position_smoothing_enabled = false
	world.player.camera.zoom = Vector2(2, 2)
	world.player.camera.force_update_scroll()
	world.weather.effects._activate(WeatherManager.Weather.SUNNY)
	world.weather.effects.strength = 0.0
	world.weather.day_night.ambient.color = Color.WHITE
	for light: PointLight2D in world.weather.day_night.lights:
		light.enabled = false
	for node: Node in world.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).hide()
	for frame: int in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://debug_saves/storage_scale/preview.png")
	var warehouse: Sprite2D = world.get_node("Warehouse/Sprite2D") as Sprite2D
	var seeds: Sprite2D = world.get_node("SeedInventory/Sprite2D") as Sprite2D
	print(JSON.stringify({"warehouse_scale":str(warehouse.scale), "seeds_scale":str(seeds.scale), "warehouse_rect":str(warehouse.get_global_transform() * warehouse.get_rect()), "seeds_rect":str(seeds.get_global_transform() * seeds.get_rect())}))
	world.free()
	get_tree().quit()
