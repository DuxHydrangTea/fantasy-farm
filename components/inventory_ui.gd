class_name InventoryUI
extends CanvasLayer
@export var close_button: BaseButton
# Signal-driven grid adapted from the Godot skill's inventory_ui.gd template.
@export var selection: ToolSelectionComponent
@export var root: Control
@export var panel: PanelContainer
@export var grid: GridContainer
@export var details: Label
@export var capacity: Label
var buttons: Array[InventorySlot] = []
var inspected_index: int = 0

func _ready() -> void:
	root.hide()
	for index: int in range(selection.inventory.slot_count):
		var button: InventorySlot = InventorySlot.new()
		button.name = "Slot" + str(index)
		button.inventory = selection.inventory
		button.slot_index = index
		button.compact = true
		button.show_shortcut = index < selection.HOTBAR_SIZE
		button.pressed.connect(_inspect_slot.bind(index))
		grid.add_child(button)
		buttons.append(button)
	close_button.pressed.connect(close)
	selection.inventory_visibility_changed.connect(_on_visibility_changed)
	selection.inventory.changed.connect(_refresh)
	root.resized.connect(_fit_panel)
	_fit_panel()
	_refresh()

func _fit_panel() -> void:
	var size: Vector2 = root.get_viewport_rect().size
	panel.custom_minimum_size = Vector2(minf(520.0, size.x - 32.0), minf(540.0, size.y - 32.0))

func open() -> void:
	selection.set_inventory_open(true)

func close() -> void:
	selection.set_inventory_open(false)

func _on_visibility_changed(value: bool) -> void:
	root.visible = value
	if value:
		_fit_panel()
		_refresh()

func _inspect_slot(index: int) -> void:
	inspected_index = index
	if index < selection.HOTBAR_SIZE:
		selection.select_slot(index)
	_refresh()

func _refresh() -> void:
	var used: int = 0
	for index: int in range(buttons.size()):
		var selected: bool = index == inspected_index
		buttons[index].set_selected(selected)
		if selection.inventory.slot(index).item != null:
			used += 1
	var stack: Dictionary = selection.inventory.slot(inspected_index)
	details.text = "%s  ×%d" % [stack.item.display_name, stack.count] if stack.item != null else "Ô trống — kéo vật phẩm vào đây"
	capacity.text = "%d / %d ô" % [used, buttons.size()]

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	var key: InputEventKey = event as InputEventKey
	if event.is_action_pressed("toggle_inventory") or key.physical_keycode == KEY_I:
		selection.set_inventory_open(not selection.inventory_open)
		get_viewport().set_input_as_handled()
	elif selection.inventory_open and key.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif selection.inventory_open:
		get_viewport().set_input_as_handled()
