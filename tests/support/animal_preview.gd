extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var world: Node2D = preload("res://world/main_world.tscn").instantiate() as Node2D
	root.add_child(world)
	world.get_node("Player/Camera2D").enabled = false
	world.get_node("Player/Hotbar").hide()
	var camera: Camera2D = Camera2D.new()
	camera.position = Vector2(1200, 402)
	camera.zoom = Vector2(3, 3)
	world.add_child(camera)
	camera.make_current()
	var animal: Node = world.get_node("CoopPen/Chicken")
	animal.needs.update_at(animal.needs.time_manager.now() + 150.0)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	quit(root.get_texture().get_image().save_png("res://.godot/animal-preview.png"))
