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
	var behaviours: bool = OS.get_cmdline_user_args().has("behaviours")
	if behaviours:
		for sample: Array in [["Chicken", &"forage"], ["Chicken_2", &"sleep"], ["Chicken_3", &"rest"]]:
			var target: Node = world.get_node("CoopPen/" + String(sample[0]))
			target.behaviour.definition = target.definition.duplicate()
			target.behaviour.definition.forage_seconds = Vector2(20, 20)
			target.behaviour.definition.rest_seconds = Vector2(20, 20)
			target.behaviour.definition.sleep_seconds = Vector2(20, 20)
			target.behaviour.request_behaviour(sample[1])
	await create_timer(2.5 if behaviours else 1.0).timeout
	await RenderingServer.frame_post_draw
	if behaviours:
		for node_name: String in ["Chicken", "Chicken_2", "Chicken_3"]:
			var target: Node = world.get_node("CoopPen/" + node_name)
			print(node_name, " preview animation: ", target.sprite.animation, " frame: ", target.sprite.frame)
	var path: String = "res://.godot/animal-behaviours-preview.png" if behaviours else "res://.godot/animal-preview.png"
	quit(root.get_texture().get_image().save_png(path))
