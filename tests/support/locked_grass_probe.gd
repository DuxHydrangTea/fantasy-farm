extends Node2D
## Native visual/input QA. World is a child, never the personal-save scene.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const OTHER: ItemDefinition = preload("res://items/seeds/radish_seed.tres")
const FERTILIZER: ItemDefinition = preload("res://items/boosters/crop_fertilizer.tres")
var world: FarmWorld
var _checks: int = 0
var _failures: Array[String] = []
var _output: String

func _ready() -> void:
	_output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_output)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(1280, 720)
	Engine.max_fps = 60
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)

func _frames(count: int = 3) -> void:
	for i: int in range(count):
		await get_tree().process_frame

func _capture(name: String) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = get_viewport().get_visible_rect().size - Vector2(2, 2)
	motion.global_position = motion.position
	get_viewport().push_input(motion, true)
	await _frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output + "/" + name + ".png")

func _click(button: BaseButton) -> void:
	if button.get_parent().get_parent() is ScrollContainer:
		(button.get_parent().get_parent() as ScrollContainer).ensure_control_visible(button)
		await _frames(5)
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await _frames(1)
	event.pressed = false
	get_viewport().push_input(event, true)
	await _frames()

func _touch(id: int, point: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = id
	event.position = point
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _image() -> Image:
	world.grass.sync_tile_materials()
	await _frames(3)
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

func _run() -> void:
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	await _frames(10)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(4,4)
	world.weather.set_weather(WeatherSchedule.Weather.SUNNY)
	world.weather.set_debug_hour(12)
	var point: Vector2 = world.farming.farmland.to_global(world.farming.farmland.map_to_local(Vector2i(50,25)))
	world.player.global_position = point
	world.player.camera.zoom = Vector2(4,4)
	world.player.camera.position_smoothing_enabled = false
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	await _frames(10)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var field: FarmGrassField = world.grass
	var cover: LandGrassCover = world.land.grass_cover
	var node_count: int = world.get_child_count()
	_check(field.active and cover.active,"Locked weeds join active GPU foliage")
	_check(cover.canvases.size() == 4 and cover.materials.size() == 2,"Exactly four draw RIDs and two materials")
	_check(cover.base_count == 44*34,"All locked cells are covered")
	field.effect.set_shader_parameter(&"wind_strength",0.0)
	field.effect.set_shader_parameter(&"actor_count",0)
	field.effect.set_shader_parameter(&"use_test_time",true)
	field.effect.set_shader_parameter(&"test_time",0.0)
	var gpu: Image = await _image()
	gpu.save_png(_output+"/locked-grass-idle.png")
	world.land.set_grass_effect(null)
	var original: Image = await _image()
	original.save_png(_output+"/locked-grass-original.png")
	_check(float(gpu.compute_image_metrics(original,false).get("max",255.0)) <= 1.0,"Idle GPU pixels match original locked grass")
	world.land.set_grass_effect(field.effect)
	# A moving player is read by the one existing actor registry.
	field.interactions.reset_all_motion()
	world.player.global_position = point+Vector2(-4,0)
	field.interactions.tick(0.016,Rect2(point-Vector2(100,100),Vector2(200,200)),field.effect,true)
	world.player.global_position = point+Vector2(4,0)
	field.interactions.tick(0.016,Rect2(point-Vector2(100,100),Vector2(200,200)),field.effect,true)
	_check(int(field.effect.get_shader_parameter(&"actor_count")) > 0,"Player stepping is captured by shared actor feed")
	var contacts: int = int(field.effect.get_shader_parameter(&"actor_count"))
	field.effect.set_shader_parameter(&"actor_count",0)
	var no_contact: Image = await _image()
	field.effect.set_shader_parameter(&"actor_count",contacts)
	var contact: Image = await _image()
	contact.save_png(_output+"/locked-grass-player-contact.png")
	_check(float(no_contact.compute_image_metrics(contact,false).get("max",0.0)) > 1.0,"Locked grass pixels bend under player contact")
	for material: ShaderMaterial in cover.materials:
		_check(material.get_shader_parameter(&"actor_count") == field.effect.get_shader_parameter(&"actor_count"),"Each weed variant receives shared pressure")
	var builds: int = cover.base_builds
	world.land.state.restore_columns(12,4)
	_check(cover.base_count == 36*34,"Unlocking removes weeds from newly owned plots")
	world.land._reveal_column = 44
	world.land._reveal_rows(12)
	_check(cover.reveal_count == 22,"Clearing animation preserves the unrevealed part of the purchased column")
	_check(cover.base_builds == builds+1,"Reveal animation avoids rebuilding all locked weeds")
	world.land.reset_presentation()
	_check(cover.reveal_count == 0,"Load/reset clears reveal overlay")
	_check(world.get_child_count() == node_count,"No new scene nodes for locked grass")
	field.set_conversion(false)
	_check(not cover.active and cover.canvases.is_empty(),"F10/fallback restores static cover and frees RIDs")
	_check(field.set_conversion(true) and cover.active,"GPU cover can be enabled again")
	world.land.state.restore_columns(48,4)
	_check(cover.base_count == 0,"Fully unlocked farm has no weeds")
	var report: Dictionary = {"ok":_failures.is_empty(),"checks":_checks,"failures":_failures,"personal_save_used":false}
	var file: FileAccess = FileAccess.open(_output+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)
