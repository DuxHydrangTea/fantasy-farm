extends Control
## Keep the first scene small; the farm's assets load while this screen renders.
const WORLD_PATH: String = "res://world/main_world.tscn"
@onready var _status: Label = $Center/Column/Status
@onready var _progress: ProgressBar = $Center/Column/Progress
var _requested: bool = false

func _ready() -> void:
	resized.connect(_fit)
	_fit()
	($Center/Column/Back as Button).pressed.connect(func() -> void: get_tree().change_scene_to_file("res://world/start_menu.tscn"))
	_status.text = tr("Loading saved progress…")
	# Let the loading screen draw before requesting the large scene.
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var error: Error = ResourceLoader.load_threaded_request(WORLD_PATH, "PackedScene")
	if error != OK:
		_fail()
		return
	_requested = true

func _process(_delta: float) -> void:
	if not _requested:
		return
	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(WORLD_PATH, progress)
	if not progress.is_empty():
		_progress.value = float(progress[0]) * 100.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_requested = false
		_open_world.call_deferred()
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_fail()

func _open_world() -> void:
	var scene: PackedScene = ResourceLoader.load_threaded_get(WORLD_PATH) as PackedScene
	if scene == null or get_tree().change_scene_to_packed(scene) != OK:
		_fail()

func _fail() -> void:
	_requested = false
	_status.text = tr("Unable to open the farm.")
	($Center/Column/Back as Button).show()

func _fit() -> void:
	($Center/Column as VBoxContainer).custom_minimum_size.x = minf(600, maxf(0, size.x - 32))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
