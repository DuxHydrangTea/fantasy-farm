extends SceneTree
const Clock = preload("res://components/time_manager.gd")
const Actor = preload("res://components/animals/animal_actor.gd")
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	var clock: Clock = Clock.new()
	clock.clock_source = func() -> float: return 1000.0
	root.add_child(clock)
	clock.set_process(false)
	var world: Node2D = preload("res://world/main_world.tscn").instantiate() as Node2D
	world.get_node("FarmingController").time_manager=clock
	world.get_node("FlowerGarden").time_manager=clock
	var pen: Node = world.get_node("PondPen")
	for actor: Node in pen.get_children():
		if actor is Actor:
			actor.get_node("NeedsComponent").time_manager=clock
	root.add_child(world)
	world.get_node("Player/Camera2D").enabled=false
	var camera: Camera2D=Camera2D.new()
	camera.position=Vector2(1616,720)
	camera.zoom=Vector2(2,2)
	world.add_child(camera)
	camera.make_current()
	await physics_frame
	await physics_frame
	await physics_frame
	var birds: int=0
	for actor: Node in pen.get_children():
		if actor is Actor:
			birds+=1
			assert(actor.wander._target_is_clear(actor.global_position),"Spawn overlaps obstacle: "+actor.name)
	print("POND_PREVIEW: ",birds," birds; land/water navigation ready=",pen.navigation_ready)
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.godot/waterfowl-preview.png")==OK)
	quit()
