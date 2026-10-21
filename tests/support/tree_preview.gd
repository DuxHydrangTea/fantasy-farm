extends Node
## Preview dựng trong world riêng, không bind SaveManager hay thay đổi save thật.
var world: FarmWorld

func _ready() -> void:
	_preview.call_deferred()

func _preview() -> void:
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	get_tree().root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.farming.time_manager.set_process(false)
	world.weather.day_night.ambient.color = Color.WHITE
	world.weather.hud.hide()
	for light: PointLight2D in world.weather.day_night.lights:
		light.enabled = false
	world.player.camera.enabled = false
	world.player.hide()
	for child: Node in world.player.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).hide()
	var camera: Camera2D = Camera2D.new()
	camera.position = Vector2(1024, 1140)
	camera.zoom = Vector2(1, 1)
	world.add_child(camera)
	var timestamp: float = world.farming.time_manager.now()
	for index: int in range(4):
		var id: String = ["apple", "peach", "pear", "cherry"][index]
		for growth: int in range(4):
			var tree: FruitTree = world.trees.create_tree(Vector2i(15 + index * 9, 64 + growth * 3), world.trees.definitions[StringName(id)], timestamp) as FruitTree
			if growth > 0:
				tree.water(timestamp)
				tree.refresh(timestamp + (90.0 if growth == 1 else 180.0 if growth == 2 else 270.0))
	for index: int in range(3):
		var id: String = ["oak", "birch", "spruce"][index]
		for growth: int in range(4):
			var tree: TimberTree = world.trees.create_tree(Vector2i(72 + index * 12, 64 + growth * 3), world.trees.definitions[StringName(id)], timestamp) as TimberTree
			if growth > 0:
				tree.refresh(timestamp + (120.0 if growth == 1 else 240.0))
			if growth == 3:
				tree.stump = true
				tree.hits = tree.definition.chop_hits
				tree.regrow_at = tree.last_at + tree.definition.stump_seconds
				tree.update_visual()
	for index: int in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output: Image = get_viewport().get_texture().get_image()
	var cache_path: String = "res://.godot/"
	output.save_png(cache_path + "tree-preview.png")
	var atlas: Image = (load("res://assets/Crops/Fruit_Trees_Fruit_Objects.png") as Texture2D).get_image()
	atlas.resize(800, 160, Image.INTERPOLATE_NEAREST)
	atlas.save_png(cache_path + "fruit-atlas-preview.png")
	print("TREE_PREVIEW_OK")
	world.free()
	get_tree().quit()
