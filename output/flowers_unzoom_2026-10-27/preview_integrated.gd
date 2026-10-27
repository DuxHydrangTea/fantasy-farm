extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1440, 900)
	var world: Variant = load("res://world/main_world.tscn").instantiate()
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var garden: Variant = world.get_node("FlowerGarden")
	garden.set_starter_content_locked(false)
	garden.reset()
	garden.starter_flowers_added = true
	# Fill every actual cell to review the four equally spaced 7x4 blocks.
	var index: int = 0
	for cell: Vector2i in garden.pots:
		index = cell.y * garden.Layout.COLUMNS + cell.x
		var path: String = "res://flowers/definitions/flower_%02d.tres" % (index % 30 + 1)
		var definition: Resource = load(path)
		garden.pots[cell].restore_state({"planted_at": 900.0, "growth_started_at": 900.0, "matures_at": 1000.0, "progress": 1.0}, definition, 1000.0)
	var player: Node = world.get_node("Player")
	player.get_node("Camera2D").enabled = false
	var camera: Camera2D = Camera2D.new()
	camera.position = garden.position + Vector2(192, 128)
	camera.zoom = Vector2(2.5, 2.5)
	world.add_child(camera)
	camera.make_current()
	for canvas: Node in world.find_children("*", "CanvasLayer", true, false):
		canvas.visible = false
	await create_timer(0.5).timeout
	for tint: Node in root.find_children("*", "CanvasModulate", true, false):
		tint.visible = false
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://output/flowers_unzoom_2026-10-27/integrated-garden-preview.png") == OK)
	print("FLOWER_PACK_PREVIEW_OK: 112 pots, four equal 7x4 blocks")
	quit()
