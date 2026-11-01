class_name WorldPersistence
extends Node
## Only the real running MainWorld binds persistence. GUT/preview instances do not.
@export var world: FarmWorld
var _service: GameSaveManager
var _label: Label
var _hide_at: int = 0
var _notice_panel: PanelContainer
var _notice_timer: Timer
var _notice_success: bool = true

func _ready() -> void:
	# A signal connection is removed if this preview is freed before the frame.
	# An awaiting coroutine instead resumes on a deleted instance during teardown.
	get_tree().process_frame.connect(_start, CONNECT_ONE_SHOT)

func _start() -> void:
	# Web startup can flush deferred calls before the main scene is assigned.
	# Wait one frame before applying the guard that keeps previews isolated.
	if get_tree().current_scene != world:
		return
	_service = SaveManager
	_build_notice()
	_service.status_changed.connect(_notice)
	TimeManager.set_process(true)
	var result: Dictionary = await _service.bind_world(world)
	if not result.ok:
		_service.startup_error = GameText.error(result)
		get_tree().call_deferred("change_scene_to_file", "res://world/start_menu.tscn")

func _build_notice() -> void:
	if _label != null:
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var root: Control = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	UIScaleComponent.attach(layer, root)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_top", 68)
	margin.add_theme_constant_override("margin_right", 16)
	_notice_panel = PanelContainer.new()
	_notice_panel.theme = preload("res://resources/ui/cozy_hud/theme.tres")
	FarmUI.apply(_notice_panel)
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_notice_panel)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.custom_minimum_size.x = 240
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 16)
	_notice_panel.add_child(_label)
	_notice_panel.hide()
	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.timeout.connect(_notice_panel.hide)
	add_child(_notice_timer)
	world.player.selection.inventory_visibility_changed.connect(_menu_changed)
	world.player.selection.shop_visibility_changed.connect(_menu_changed)
	world.player.selection.objectives_visibility_changed.connect(_menu_changed)
	set_process(false)

func _notice(message: String, success: bool) -> void:
	_notice_success = success
	_label.text = message
	_label.add_theme_color_override("font_color", FarmUI.GOOD if success else FarmUI.WARNING)
	_label.show()
	_notice_panel.show()
	if success and world.player.selection.is_menu_open():
		_notice_panel.hide()
	_hide_at = Time.get_ticks_msec() + (4000 if success else 15000)
	_notice_timer.start(4.0 if success else 15.0)

func _menu_changed(open: bool) -> void:
	if open and _notice_success:
		_notice_panel.hide()

func _process(_delta: float) -> void:
	if _label != null and Time.get_ticks_msec() > _hide_at:
		_label.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if _service == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F5:
		_service.save_game()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F9:
		_service.load_game()
		get_viewport().set_input_as_handled()
