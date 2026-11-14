extends SceneTree
## Render the real world, independent of the player's saved profile.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var output: String = ProjectSettings.globalize_path("res://") + ".godot/decor-review/coop/review"
	var barn: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument == "--area=barn":
			barn = true
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1536, 1024)
	Engine.max_fps = 60
	var world: Node2D = load("res://world/main_world.tscn").instantiate() as Node2D
	root.add_child(world)
	world.player.camera.enabled = false
	world.land.state.restore_blocks(13, 4)
	for layer: Node in world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()
	var camera: Camera2D = Camera2D.new()
	world.add_child(camera)
	camera.make_current()
	await create_timer(0.4).timeout
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for tint: Node in world.find_children("*", "CanvasModulate", true, false):
		(tint as CanvasModulate).hide()
	for light: Node in world.find_children("*", "PointLight2D", true, false):
		(light as PointLight2D).hide()
	var report: Dictionary = {}
	var review_bounds: Rect2 = Rect2(1000, 584, 400, 304) if barn else Rect2(1000, 280, 400, 272)
	for child: Node in world.get_children():
		if not child is TileMapLayer:
			continue
		var layer: TileMapLayer = child as TileMapLayer
		var cells: Array = []
		for cell: Vector2i in layer.get_used_cells():
			var point: Vector2 = layer.to_global(layer.map_to_local(cell))
			if review_bounds.has_point(point):
				cells.append([cell.x, cell.y, layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell).x, layer.get_cell_atlas_coords(cell).y])
		var sources: Dictionary = {}
		if not cells.is_empty():
			for index: int in range(layer.tile_set.get_source_count()):
				var id: int = layer.tile_set.get_source_id(index)
				var source: TileSetAtlasSource = layer.tile_set.get_source(id) as TileSetAtlasSource
				if source != null:
					sources[id] = {"texture": source.texture.resource_path, "tile_size": str(source.texture_region_size)}
			report[layer.name] = {"cells": cells, "sources": sources}
	var file: FileAccess = FileAccess.open(output + "/tiles.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	var shots: Array[Array] = [
		["overview", Vector2(1200, 408), 3.0],
		["coop-corner", Vector2(1280, 340), 5.0],
		["garden-corner", Vector2(1110, 462), 5.0],
	]
	if barn:
		shots = [["overview", Vector2(1200, 728), 3.0],
			["barn-corner", Vector2(1200, 650), 5.0],
			["care-corner", Vector2(1100, 795), 5.0]]
	for shot: Array in shots:
		camera.position = shot[1]
		camera.zoom = Vector2.ONE * float(shot[2])
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output + "/" + str(shot[0]) + ".png") == OK)
	# Preview population is added only to this disposable review session.
	var animal_scene: PackedScene = load("res://scenes/animals/cow.tscn" if barn else "res://scenes/animals/chicken.tscn") as PackedScene
	var pen: Node2D = world.get_node("BarnPen" if barn else "CoopPen") as Node2D
	var positions: Array[Vector2] = [Vector2(1124, 370), Vector2(1150, 394), Vector2(1180, 446),
		Vector2(1230, 466), Vector2(1284, 397), Vector2(1305, 356), Vector2(1341, 385), Vector2(1106, 470)]
	if barn:
		positions = [Vector2(1134, 708), Vector2(1258, 713), Vector2(1196, 764), Vector2(1304, 803), Vector2(1110, 823)]
	for index: int in range(positions.size()):
		var animal: Node2D = animal_scene.instantiate() as Node2D
		animal.position = pen.to_local(positions[index])
		animal.set("initial_age_seconds", 36001.0 if barn else 3601.0)
		pen.add_child(animal)
		animal.animation.face(Vector2.LEFT if index % 2 == 0 else Vector2.RIGHT)
		animal.animation.play("idle")
	camera.position = Vector2(1200, 728) if barn else Vector2(1200, 408)
	camera.zoom = Vector2(3, 3)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output + "/populated.png") == OK)
	print("Livestock yard captures saved: ", output)
	world.queue_free()
	await process_frame
	quit()
