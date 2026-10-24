extends Node2D
## Standalone F6 lab. No FarmWorld/persistence binding and no per-tuft scene nodes.
@export var field: GrassField
@export var camera: Camera2D
var _status: Label
var _last_hud: int = 0
var _forced_frame: int = -1

func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.content_scale_size = Vector2i(640, 520)
	get_tree().root.size = Vector2i(1024, 832)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var top: VBoxContainer = VBoxContainer.new()
	top.position = Vector2(12, 8)
	layer.add_child(top)
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("f5f2db"))
	title.text = "GRASS GPU · G1 · 324 tufts / 1 grass node"
	top.add_child(title)
	var controls: Label = Label.new()
	controls.add_theme_font_size_override("font_size", 12)
	controls.add_theme_color_override("font_color", Color("f5f2db"))
	controls.text = "W wind · A animation · F frame · wheel zoom · P pause · T time scale"
	top.add_child(controls)
	_status = Label.new()
	_status.position = Vector2(12, 478)
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color("f5f2db"))
	layer.add_child(_status)
	_refresh()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 520), Color("325b3b"))
	for row: int in range(18):
		var y: float = field.position.y + row * field.spacing.y
		draw_line(Vector2(76, y), Vector2(558, y), Color(0.65, 0.8, 0.5, 0.12))

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _last_hud > 250:
		_last_hud = Time.get_ticks_msec()
		_refresh()

func _refresh() -> void:
	_status.text = "Wind %.2f · Frames %s · Zoom %.2f · Scene paused %s\nGrass CPU process: %s / physics: %s · G2 chunks / G3 actor bending pending" % [field.wind_strength, "GPU" if _forced_frame < 0 and field.animate_frames else str(maxi(0, _forced_frame)), camera.zoom.x, get_tree().paused, field.is_processing(), field.is_physics_processing()]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W:
				field.set_wind(0.85 if field.wind_strength == 0.0 else 0.0)
			KEY_A:
				field.set_animation(not field.animate_frames)
			KEY_F:
				_forced_frame = _forced_frame + 1 if _forced_frame < 7 else -1
				field.effect.set_shader_parameter(&"fixed_frame", _forced_frame)
			KEY_P:
				get_tree().paused = not get_tree().paused
			KEY_T:
				Engine.time_scale = 0.0 if Engine.time_scale > 0.0 else 1.0
		_refresh()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = Vector2.ONE * minf(3.0, camera.zoom.x + 0.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = Vector2.ONE * maxf(0.5, camera.zoom.x - 0.25)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
