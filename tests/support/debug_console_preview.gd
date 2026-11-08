extends Node
var world: FarmWorld

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var root: Window = get_tree().root
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	root.add_child(world)
	world.tool_upgrades.profile_ready = true
	var console: FarmDebugConsole = world.get_node("DebugConsole") as FarmDebugConsole
	console.set_open(true)
	await console.submit("/help")
	var folder: String = "C:/projects/fantasy-farm/.godot/debug-console-preview"
	DirAccess.make_dir_recursive_absolute(folder)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(844, 390)]:
		root.size = size
		root.content_scale_size = size
		for frame: int in range(6): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("console-%dx%d.png" % [size.x, size.y]))
		assert(Rect2(Vector2.ZERO, Vector2(size)).encloses(console.entry.get_global_rect()), "Input stays on screen")
	assert(SaveManager.adapter == null, "Preview cannot bind playing save")
	console.set_open(false)
	world.free()
	get_tree().quit()
