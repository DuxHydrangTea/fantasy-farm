class_name FruitTreeActionMenu
extends TradeMenu
## Các thao tác nhanh cho cây ăn quả trưởng thành.

const VIEWPORT_MARGIN: Vector2 = Vector2(8, 8)
const CANOPY_GAP: float = 8.0

var world: FarmWorld
var tree: FruitTree
var harvest_button: Button
var details_button: Button
var panel: PanelContainer
var _buttons: Array[Button] = []
var _status: Label
var _error: String = ""
var _camera: Camera2D
var _original_camera_offset: Vector2

func _ready() -> void:
	layer = 24
	root = Control.new()
	root.theme = preload("res://resources/ui/cozy_hud/inventory_theme.tres")
	add_child(root)
	root.gui_input.connect(_outside_input)
	root.resized.connect(_place_panel)
	panel = PanelContainer.new()
	root.add_child(panel)
	panel.custom_minimum_size.x = 184.0
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	harvest_button = _add_button(column, _harvest)
	details_button = _add_button(column, _details)
	close_button = _add_button(column)
	_status = Label.new()
	_status.custom_minimum_size.x = 152.0
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 15)
	column.add_child(_status)
	_refresh_text()
	super._ready()

func _add_button(parent: VBoxContainer, action: Callable = Callable()) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size.y = 48.0
	if action.is_valid():
		button.pressed.connect(action)
	parent.add_child(button)
	_buttons.append(button)
	return button

func open_tree(target: FruitTree) -> bool:
	if not world.grafting.access_error(target).is_empty() or not super.open(null, world.player):
		return false
	tree = target
	_camera = get_viewport().get_camera_2d()
	if is_instance_valid(_camera):
		_original_camera_offset = _camera.offset
	_error = ""
	_refresh_text()
	harvest_button.grab_focus()
	_place_panel()
	return true

func _finish_close(show_thanks: bool) -> void:
	if is_instance_valid(_camera) and _camera.offset != _original_camera_offset:
		_camera.offset = _original_camera_offset
		if _camera.is_inside_tree():
			_camera.force_update_scroll()
	_camera = null
	tree = null
	super._finish_close(show_thanks)

func _place_panel() -> void:
	if not is_open or not is_instance_valid(tree):
		return
	var sprite: Sprite2D = tree.sprite
	var canopy_world: Vector2 = tree.global_position
	if sprite.texture != null:
		var bounds: Rect2i = PerennialTree.visible_bounds(sprite.texture)
		var canopy: Vector2 = Vector2(bounds.get_center().x, bounds.position.y)
		canopy_world = sprite.to_global(sprite.get_rect().position + canopy)
	var world_to_menu: Transform2D = root.get_global_transform_with_canvas().affine_inverse() * tree.get_canvas_transform()
	var anchor: Vector2 = world_to_menu * canopy_world
	panel.size = panel.get_combined_minimum_size()
	var panel_offset: Vector2 = Vector2(panel.size.x * 0.5, panel.size.y + CANOPY_GAP)
	if is_instance_valid(_camera) and _camera.is_current() and not _closing:
		# Chừa chỗ trên tán khi cây ở sát mép trên màn hình.
		var camera_shift: Vector2 = world_to_menu.basis_xform(_camera.offset - _original_camera_offset)
		var unshifted_top: float = anchor.y + camera_shift.y - panel_offset.y
		var room_needed: float = maxf(0.0, VIEWPORT_MARGIN.y - unshifted_top)
		var next_offset: Vector2 = _original_camera_offset - world_to_menu.affine_inverse().basis_xform(Vector2(0, room_needed))
		if not _camera.offset.is_equal_approx(next_offset):
			_camera.offset = next_offset
			_camera.force_update_scroll()
			anchor -= world_to_menu.basis_xform(next_offset - _original_camera_offset) - camera_shift
	var limits: Vector2 = (root.size - panel.size - VIEWPORT_MARGIN).max(VIEWPORT_MARGIN)
	panel.position = (anchor - panel_offset).clamp(VIEWPORT_MARGIN, limits).round()

func _outside_input(event: InputEvent) -> void:
	if not is_open or not event.is_pressed():
		return
	if (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]) or event is InputEventScreenTouch:
		root.accept_event()
		close()

func _input(event: InputEvent) -> void:
	if not is_open or not event.is_pressed() or event.is_echo():
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var index: int = _buttons.find(focused) if focused is Button else -1
	if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down"):
		get_viewport().set_input_as_handled()
		var step: int = -1 if event.is_action_pressed(&"ui_up") else 1
		_buttons[posmod(index + step, _buttons.size()) if index >= 0 else 0].grab_focus()
	elif event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_buttons[maxi(0, index)].pressed.emit()
	else:
		super._input(event)

func _harvest() -> void:
	if not is_open or _closing:
		return
	_error = world.grafting.collect(tree)
	if _error.is_empty():
		close(false)
		world.grafting.save_changes.call_deferred()
	else:
		_refresh_text()
		_place_panel()

func _details() -> void:
	if not is_open or _closing:
		return
	var target: FruitTree = tree
	close(false)
	world.graft_menu.open_tree(target)

func _refresh_text() -> void:
	harvest_button.text = tr("Harvest")
	details_button.text = tr("Details")
	close_button.text = tr("Exit")
	_status.text = tr(_error) if not _error.is_empty() else ""
	_status.visible = not _error.is_empty()

func _process(_delta: float) -> void:
	if is_open and (not is_instance_valid(tree) or tree.removed):
		close(false)
	elif is_open:
		_place_panel()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()
