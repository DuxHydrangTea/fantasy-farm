extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var world: Node2D = preload("res://world/main_world.tscn").instantiate() as Node2D
	root.add_child(world)
	world.get_node("Player/Camera2D").enabled = false
	world.get_node("Player/Hotbar").hide()
	var camera: Camera2D = Camera2D.new()
	camera.position = Vector2(1200, 713)
	camera.zoom = Vector2(1.8, 1.8)
	world.add_child(camera)
	camera.make_current()
	var pen: Node = world.get_node("BarnPen")
	await physics_frame
	await physics_frame
	var actor_count: int = 0
	for child: Node in pen.get_children():
		if child is CharacterBody2D:
			actor_count += 1
			assert(child.wander._target_is_clear(child.global_position), "Spawn overlaps a building, trough or fence: " + String(child.name))
			# Preview only: display one batch from each species without waiting a minute.
			child.production.advance(child.production.definition.production_seconds)
	print("Barn preview animals: ", actor_count)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	quit(root.get_texture().get_image().save_png("res://.godot/barn-preview.png"))
