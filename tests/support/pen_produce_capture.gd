extends SceneTree
## Real pens and their live stock labels in a disposable review profile.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var output: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1536, 1024)
	var world: Node2D = load("res://world/main_world.tscn").instantiate() as Node2D
	root.add_child(world)
	world.land.state.restore_blocks(13, 4)
	world.player.camera.enabled = false
	await create_timer(0.4).timeout
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.get_node("TimeManager").process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in world.find_children("*", "CanvasLayer", true, false):
		node.hide()
	for node: Node in world.find_children("*", "CanvasModulate", true, false):
		node.hide()
	var examples: Array[Array] = [
		["CoopPen", "res://items/animal_produces/chicken_egg.tres", 1110],
		["BarnPen", "res://items/animal_produces/cow_milk.tres", 1200],
		["BarnPen", "res://items/animal_produces/sheep_wool.tres", 750],
		["BarnPen", "res://items/animal_produces/pig_truffle.tres", 600],
		["BarnPen", "res://items/animal_produces/horse_compost.tres", 450],
		["PondPen", "res://items/animal_produces/duck_egg.tres", 360]]
	for row: Array in examples:
		var pen: Node2D = world.get_node(row[0]) as Node2D
		pen.produce_storage.deposit(load(row[1]), row[2])
	var camera: Camera2D = Camera2D.new()
	world.add_child(camera)
	camera.make_current()
	for shot: Array in [["overview", Vector2(1408, 552), 1.3], ["chicken", Vector2(1325, 280), 3.5], ["cattle-full", Vector2(1198, 564), 3.5], ["ducks", Vector2(1628, 620), 4.0]]:
		camera.position = shot[1]
		camera.zoom = Vector2.ONE * shot[2]
		for frame: int in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output + "/" + shot[0] + ".png") == OK)
	print("Pen storage captures saved: ", output)
	world.queue_free()
	await process_frame
	quit()
