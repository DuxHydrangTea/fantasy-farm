extends SceneTree
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	var clock: FarmClock = FarmClock.new()
	clock.clock_source = func() -> float: return 1000.0
	root.add_child(clock)
	clock.set_process(false)
	var world: Node2D = preload("res://world/main_world.tscn").instantiate() as Node2D
	var garden: Node = world.get_node("FlowerGarden")
	garden.time_manager = clock
	root.add_child(world)
	for cell: Vector2i in garden.pots:
		if cell.y == 0:
			continue
		var pot: FlowerPot = garden.pots[cell]
		var path: String = "res://flowers/definitions/flower_%02d.tres" % (cell.x % 10 + 1)
		var definition: Resource = load(path)
		var progress: float = float((cell.y - 1) % 5) / 4.0
		pot.restore_state({"planted_at": 880.0,"growth_started_at":880.0,"matures_at":1000.0,"progress":progress},definition,880.0+progress*120.0)
	var player: Node2D = world.get_node("Player")
	player.get_node("Camera2D").enabled = false
	player.get_node("StateComponent").set_physics_process(false)
	player.get_node("AnimationComponent").face(Vector2.RIGHT)
	player.get_node("AnimationComponent").play("idle",true)
	player.position = garden.global_position + Vector2(204,192)
	var camera: Camera2D = Camera2D.new()
	camera.position = Vector2(1416,428)
	camera.zoom = Vector2(1.2,1.2)
	world.add_child(camera)
	camera.make_current()
	await physics_frame
	await physics_frame
	for pot: FlowerPot in garden.pots.values():
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = pot.get_node("CollisionShape2D").shape
		query.transform = pot.get_node("CollisionShape2D").global_transform
		query.exclude = [pot.get_rid()]
		query.collision_mask = 1
		assert(pot.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(),"Flower pot overlaps world obstacle: "+str(pot.cell))
	print("FLOWER_PREVIEW: %d pots; no obstacle overlap; 10 visual variants; 5 stages" % garden.pots.size())
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.godot/flower-garden-preview.png") == OK)
	quit()

