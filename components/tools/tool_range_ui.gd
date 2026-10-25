class_name ToolRangeUI
extends CanvasLayer
## One shared PC/touch selector, driven by profile state and the action policy.
var world: FarmWorld
var root: Control
var button: Button

func _ready() -> void:
	layer = 19
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://resources/ui/game_theme.tres")
	add_child(root)
	UIScaleComponent.attach(self, root)
	button = Button.new()
	button.name = "ToolArea"
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 18)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(cycle)
	root.add_child(button)
	if not InputMap.has_action(&"cycle_tool_area"):
		InputMap.add_action(&"cycle_tool_area")
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_R
		InputMap.action_add_event(&"cycle_tool_area", key)
	_process(0.0)

func can_cycle() -> bool:
	return not get_tree().paused and not (MobileLayout.is_touch(get_viewport()) and root.size.y > root.size.x) and not world.player.selection.is_menu_open() and world.player.state.current_state not in [StateComponent.State.TOOL, StateComponent.State.WATER] and not world.player.farming_actions.upgrade_kind().is_empty()

func cycle() -> void:
	if not can_cycle():
		return
	var kind: StringName = world.player.farming_actions.upgrade_kind()
	var progress: ToolUpgradeState = world.tool_upgrade_state
	progress.select_size(kind, progress.selected_size(kind) % progress.level(kind) + 1)
	_process(0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cycle_tool_area") and not event.is_echo() and can_cycle():
		cycle()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var kind: StringName = world.player.farming_actions.upgrade_kind()
	root.visible = not kind.is_empty() and not world.player.selection.is_menu_open() and not (MobileLayout.is_touch(get_viewport()) and root.size.y > root.size.x)
	if not root.visible:
		return
	var size: int = world.tool_upgrade_state.selected_size(kind)
	var touch: bool = MobileLayout.is_touch(get_viewport())
	button.size = Vector2(84, 56) if touch else Vector2(220, 44)
	button.position = Vector2(root.size.x - 92, root.size.y - 174) if touch else Vector2(root.size.x - 232, 12)
	button.disabled = not can_cycle() or world.tool_upgrade_state.level(kind) <= 1
	button.text = ("%d×%d" if touch else tr("Area: %d×%d · R")) % [size, size]
	if kind == &"sowing":
		var rows: Array[Dictionary] = world.player.farming_actions.last_preview
		var ready: int = 0
		for row: Dictionary in rows:
			ready += 1 if row.ready else 0
		button.text += ("\n" if touch else " · ") + "%d/%d" % [ready, size * size]
	button.tooltip_text = tr("Change tool area. Green: ready. Yellow: missing seeds. Red: blocked.")
