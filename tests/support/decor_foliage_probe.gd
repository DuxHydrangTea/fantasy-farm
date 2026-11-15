extends SceneTree
## Rendered regression: real decor, original pixels, shared actor feed and recovery.
var world: Node2D
var camera: Camera2D
var output: String
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error(label)

func capture_image() -> Image:
	world.grass.sync_tile_materials()
	for frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func contact(point: Vector2) -> void:
	world.player.global_position = point
	world.grass.interactions.reset_motion(world.player)
	world.grass.interactions.tick(0.02, Rect2(0, 0, 3000, 2000), world.grass.effect, true)

func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(768, 512)
	world = load("res://world/main_world.tscn").instantiate() as Node2D
	root.add_child(world)
	world.land.state.restore_blocks(13, 4)
	world.player.camera.enabled = false
	await create_timer(0.4).timeout
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.get_node("TimeManager").process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in world.find_children("*", "", true, false):
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is CanvasLayer or node is CanvasModulate or node is PointLight2D:
			node.hide()
	world.player.animation.animated_sprite.hide()
	world.player.get_node("DustParticles").hide()
	world.player.get_node("OcclusionSilhouette").hide()
	check(world.grass.active, "GPU foliage adapter is active")
	check(world.grass.decor_materials.sprite_count > 0, "Authored decor participates")
	world.grass.effect.set_shader_parameter(&"wind_strength", 0.0)
	world.grass.effect.set_shader_parameter(&"use_test_time", true)
	world.grass.effect.set_shader_parameter(&"test_time", 0.0)
	camera = Camera2D.new()
	world.add_child(camera)
	camera.make_current()
	for path: String in ["EastMeadowDecor/MeadowFlower000", "EastMeadowDecor/GrassTuft0", "EastMeadowDecor/NorthOak/Crown", "MeadowRestDetails/PicnicOak/Crown"]:
		var sprite: Sprite2D = world.get_node(path) as Sprite2D
		var material: ShaderMaterial = sprite.material as ShaderMaterial
		check(material != null, path + " has a foliage material")
		if material == null:
			continue
		var area: Rect2 = sprite.get_rect()
		var anchor: Vector2 = sprite.to_global(area.position + Vector2(area.size.x * 0.5, float(material.get_shader_parameter(&"root_pixel"))))
		camera.position = sprite.to_global(area.get_center())
		camera.zoom = Vector2.ONE * (5.0 if area.size.y > 32 else 10.0)
		contact(anchor + Vector2(80, 0))
		var calm: Image = await capture_image()
		var material_before: Material = sprite.material
		sprite.material = null
		var original: Image = await capture_image()
		check(calm.get_data() == original.get_data(), path + " retains original pixels when calm")
		sprite.material = material_before
		contact(anchor + Vector2(4, 0))
		var bent: Image = await capture_image()
		check(calm.get_data() != bent.get_data(), path + " responds to the real player actor feed")
		var name: String = path.replace("/", "-")
		calm.save_png(output + "/" + name + "-calm.png")
		bent.save_png(output + "/" + name + "-contact.png")
		contact(anchor + Vector2(80, 0))
		var recovered: Image = await capture_image()
		check(calm.get_data() == recovered.get_data(), path + " recovers after the player leaves")
	# Exercise actual character movement as well as stationary contact pressure.
	var tuft: Sprite2D = world.get_node("EastMeadowDecor/GrassTuft0") as Sprite2D
	var tuft_area: Rect2 = tuft.get_rect()
	var tuft_root: Vector2 = tuft.to_global(tuft_area.position + Vector2(tuft_area.size.x * 0.5, float(tuft.material.get_shader_parameter(&"root_pixel"))))
	camera.position = tuft.global_position
	camera.zoom = Vector2(10, 10)
	contact(tuft_root + Vector2(-40, 0))
	var walking_base: Image = await capture_image()
	world.player.process_mode = Node.PROCESS_MODE_ALWAYS
	world.player.set_process(false)
	world.player.set_physics_process(false)
	await physics_frame
	await physics_frame
	world.player.state.touch_direction = Vector2.RIGHT
	var walking_bent: bool = false
	for frame: int in range(48):
		await physics_frame
		world.player.state._physics_process(1.0 / 60.0)
		world.grass.interactions.tick(1.0 / 60.0, Rect2(0, 0, 3000, 2000), world.grass.effect, true)
		if absf(world.player.global_position.x - tuft_root.x) < 8:
			var walking_image: Image = await capture_image()
			if walking_base.get_data() != walking_image.get_data():
				walking_bent = true
				walking_image.save_png(output + "/player-walking-through-grass.png")
		if world.player.global_position.x > tuft_root.x + 24:
			break
	world.player.state.touch_direction = Vector2.ZERO
	check(world.player.global_position.x > tuft_root.x, "Actual character movement crosses the decor")
	check(walking_bent, "Walking through decor bends rendered pixels")
	# Conversion can be toggled without leaving static copies or stale materials.
	world.grass.set_conversion(false)
	check((world.get_node("EastMeadowDecor/MeadowFlower000") as Sprite2D).material == null, "Fallback restores decor")
	check(world.grass.set_conversion(true), "Re-enabling restores interactive decor")
	print("DECOR_FOLIAGE_PROBE=" + JSON.stringify({"sprites": world.grass.decor_materials.sprite_count, "tile_species": world.grass.decor_materials.tile_count, "failures": failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
