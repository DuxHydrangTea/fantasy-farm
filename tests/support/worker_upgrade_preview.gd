extends "res://tests/support/worker_layout_fixture.gd"
## Native, save-isolated UI preview. Optional -- OUTPUT_DIRECTORY saves two views.
func _ready() -> void:
	super._ready()
	world.player.wallet.set_balance(2000000)
	world.workers.hire("crop")
	world.workers.hire("crop")
	menu._refresh()
	(menu.upgrade_view.get_parent() as TabContainer).current_tab = 1
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		return
	var output: String = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		get_window().size = resolution
		get_window().content_scale_size = resolution
		for frame: int in range(12):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("worker-upgrades-%dx%d.png" % [resolution.x, resolution.y]))
	# Real pointer events exercise the same mouse emulation used by touch devices.
	var scroll: ScrollContainer = menu.get_node("%WorkScroll") as ScrollContainer
	for track: String in ["speed", "harvest"]:
		var button: Button = menu.upgrade_view.buttons[track] as Button
		scroll.ensure_control_visible(button)
		for frame: int in range(6):
			await get_tree().process_frame
		var before: int = world.workers.upgrades.level(track)
		var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.position = point
		touch.pressed = true
		Input.parse_input_event(touch)
		await get_tree().process_frame
		touch = InputEventScreenTouch.new()
		touch.position = point
		touch.pressed = false
		Input.parse_input_event(touch)
		for frame: int in range(4):
			await get_tree().process_frame
		if world.workers.upgrades.level(track) != before + 1:
			push_error("Touch purchase failed: " + track)
			get_tree().quit(1)
			return
	print("WORKER_UPGRADE_UI ", JSON.stringify({"save_bound": SaveManager.adapter != null, "actors": world.workers.actors.size(), "upgrades": menu.upgrade_view.buttons.size(), "touch_purchases": 2}))
	get_tree().quit()
