extends SceneTree

# Optional rendered QA: godot --path . -s tests/support/hotbar_preview.gd
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var background: CanvasLayer = CanvasLayer.new()
	background.layer = -10
	root.add_child(background)
	var grass: ColorRect = ColorRect.new()
	grass.color = Color(0.24, 0.50, 0.28)
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(grass)
	grass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var player: Node2D = preload("res://scenes/characters/player.tscn").instantiate() as Node2D
	player.position = Vector2(960, 540)
	root.add_child(player)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("compact"):
		root.content_scale_size = Vector2i(1280, 720)
	if args.has("inventory"):
		player.get_node("InventoryUI").open()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var path: String = "res://.godot/inventory-preview.png" if args.has("inventory") else "res://.godot/hotbar-preview.png"
	if args.has("compact"):
		path = "res://.godot/inventory-preview-720.png"
	var result: Error = screenshot.save_png(path)
	print("Hotbar preview capture: ", result)
	quit(result)
