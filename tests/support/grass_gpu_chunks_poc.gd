extends Node2D
## F6 G2 lab: world/camera/actor markers are fixtures; only GrassChunkField is the feature.
var field: GrassChunkField
var camera: Camera2D
var player: Node2D
var animal: Node2D
var _hud: Label
var _elapsed: float = 0.0
var _hud_at: int = 0

func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.content_scale_size = Vector2i(640, 480)
	get_tree().root.size = Vector2i(1024, 768)
	var background: Polygon2D = Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2(-200, -200), Vector2(2300, -200), Vector2(2300, 1300), Vector2(-200, 1300)])
	background.color = Color("355c37")
	background.z_index = -2
	add_child(background)
	field = GrassChunkField.new()
	for y: int in range(64):
		for x: int in range(128):
			var tall: bool = y % 5 != 0
			field.samples.append({"type": 10 + x % 5 if tall else 15 + x % 3,
				"transform": Transform2D(0.0, Vector2(x * 16, y * 16)), "phase": float((x + y) % 17) / 17.0,
				"tall": tall, "z_index": 0 if tall else -1})
	add_child(field)
	player = _marker(Color("f6c54a"))
	player.position = Vector2(320, 224)
	add_child(player)
	var pen: AnimalPen = AnimalPen.new()
	pen.y_sort_enabled = true
	pen.position = Vector2(240, 140)
	add_child(pen)
	animal = _marker(Color("9dcfff"))
	pen.add_child(animal)
	camera = Camera2D.new()
	camera.position = player.position
	camera.zoom = Vector2(2.5, 2.5)
	add_child(camera)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(4, 4)
	panel.size = Vector2(435, 148)
	panel.color = Color(0.03, 0.08, 0.04, 0.9)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	_hud = Label.new()
	_hud.position = Vector2(8, 8)
	_hud.add_theme_color_override("font_color", Color("fff4d0"))
	_hud.add_theme_color_override("font_shadow_color", Color("14251b"))
	_hud.add_theme_constant_override("shadow_offset_x", 1)
	_hud.add_theme_constant_override("shadow_offset_y", 1)
	_hud.add_theme_font_size_override("font_size", 13)
	layer.add_child(_hud)
	queue_redraw()

func _marker(color: Color) -> Node2D:
	var root: Node2D = Node2D.new()
	var body: Polygon2D = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-5, -22), Vector2(5, -22), Vector2(5, 0), Vector2(-5, 0)])
	body.color = color
	root.add_child(body)
	var foot: Line2D = Line2D.new()
	foot.points = PackedVector2Array([Vector2(-6, 0), Vector2(6, 0)])
	foot.width = 1
	foot.default_color = Color.WHITE
	root.add_child(foot)
	return root

func _draw() -> void:
	for x: int in range(0, 2049, 256):
		draw_line(Vector2(x, 0), Vector2(x, 1024), Color(0.7, 0.8, 0.4, 0.2))
	for y: int in range(0, 1025, 256):
		draw_line(Vector2(0, y), Vector2(2048, y), Color(0.7, 0.8, 0.4, 0.2))

func _process(delta: float) -> void:
	_elapsed += delta
	player.position += Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * delta * 100.0
	animal.position = Vector2(80 + sin(_elapsed * 0.7) * 90, 70 + cos(_elapsed) * 35)
	camera.position = player.position
	if Time.get_ticks_msec() - _hud_at > 250:
		_hud_at = Time.get_ticks_msec()
		var stats: Dictionary = field.renderer.stats()
		_hud.text = "G2 GRASS / 8192 tufts / 1 feature node\nArrows move yellow marker / wheel zoom\nC chunk 256/512 / H hide / R reload\nBlue marker is nested in AnimalPen\nChunk %d / active %d / cache %d / batches %d\nGPU instances %d / builds %d / queries %d\nG3 actor bending pending\n%s" % [field.chunk_size, stats.active_chunks, stats.resident_chunks, stats.live_leaves, stats.resident_instances, stats.builds, stats.index_queries, stats.error]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				field.chunk_size = 512 if field.chunk_size == 256 else 256
				field.rebuild()
			KEY_H:
				field.visible = not field.visible
			KEY_R:
				field.rebuild()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = Vector2.ONE * minf(5.0, camera.zoom.x + 0.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = Vector2.ONE * maxf(0.75, camera.zoom.x - 0.25)
