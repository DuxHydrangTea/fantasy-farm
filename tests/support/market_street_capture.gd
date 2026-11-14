extends SceneTree
## Visual review: godot --path . --script res://tests/support/market_street_capture.gd -- --label=final

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var label: String = "review"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--label="):
			label = argument.trim_prefix("--label=").validate_filename()
	var folder: String = ProjectSettings.globalize_path("res://") + ".godot/decor-review/market-street/" + label
	DirAccess.make_dir_recursive_absolute(folder)
	var world: Node2D = load("res://world/main_world.tscn").instantiate() as Node2D
	root.add_child(world)
	(world.get_node("Player/Camera2D") as Camera2D).enabled = false
	for layer: Node in world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()
	var camera: Camera2D = Camera2D.new()
	var player_camera: Camera2D = world.get_node("Player/Camera2D") as Camera2D
	camera.limit_left = player_camera.limit_left
	camera.limit_top = player_camera.limit_top
	camera.limit_right = player_camera.limit_right
	camera.limit_bottom = player_camera.limit_bottom
	world.add_child(camera)
	camera.make_current()
	await create_timer(0.5).timeout
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for tint: Node in world.find_children("*", "CanvasModulate", true, false):
		(tint as CanvasModulate).hide()
	for light: Node in world.find_children("*", "PointLight2D", true, false):
		(light as PointLight2D).hide()
	var shots: Array[Array] = [
		["overview", Vector2(1200, 140), 1.2],
		["seeds-flowers", Vector2(850, 140), 2.5],
		["restaurant", Vector2(1232, 140), 3.0],
		["pets-smith", Vector2(1680, 140), 2.5],
		["east-square", Vector2(1945, 490), 1.8],
		["storage-yard", Vector2(2220, 1135), 2.0],
	]
	for shot: Array in shots:
		camera.position = shot[1]
		camera.zoom = Vector2.ONE * float(shot[2])
		await process_frame
		await RenderingServer.frame_post_draw
		var result: Error = root.get_texture().get_image().save_png(folder + "/" + str(shot[0]) + ".png")
		assert(result == OK, "Capture failed: " + str(shot[0]))
	camera.position = Vector2(1200, 140)
	camera.zoom = Vector2(1.2, 1.2)
	for tint: Node in world.find_children("*", "CanvasModulate", true, false):
		(tint as CanvasModulate).show()
		(tint as CanvasModulate).color = Color(0.22, 0.25, 0.45)
	for light: Node in world.find_children("*", "PointLight2D", true, false):
		(light as PointLight2D).show()
		(light as PointLight2D).enabled = true
		(light as PointLight2D).energy = 0.85
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder + "/night.png") == OK)
	print("Market screenshots saved: ", folder)
	world.queue_free()
	await process_frame
	quit()
