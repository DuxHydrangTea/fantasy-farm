extends CanvasLayer

const ToolSelection = preload("res://components/tool_selection_component.gd")
const Slot = preload("res://components/inventory_slot.gd")
const SLOT_ACTIONS: Array[StringName] = [&"hotbar_1", &"hotbar_2", &"hotbar_3", &"hotbar_4", &"hotbar_5", &"hotbar_6"]

@export var selection: ToolSelection
@onready var slots: HBoxContainer = $Root/Bottom/Column/Slots
@onready var selected_name: Label = $Root/Bottom/Column/SelectedName
var buttons: Array[TextureButton] = []

func _ready() -> void:
	assert(selection != null, "Hotbar requires ToolSelection")
	for index: int in range(selection.HOTBAR_SIZE):
		var button: Slot = Slot.new()
		button.name = "Slot" + str(index)
		button.inventory = selection.inventory
		button.slot_index = index
		button.show_shortcut = true
		button.pressed.connect(_select_slot.bind(index))
		slots.add_child(button)
		buttons.append(button)
	selection.selection_changed.connect(_on_selection_changed)
	_on_selection_changed(selection.selected_index, &"")

func _select_slot(index: int) -> void:
	selection.select_slot(index)
	_on_selection_changed(selection.selected_index, &"")

func _on_selection_changed(index: int, _tool: StringName) -> void:
	for i: int in range(buttons.size()):
		buttons[i].set_pressed_no_signal(i == index)
		buttons[i].get_node("SelectionFrame").visible = i == index
	selected_name.text = selection.get_selected_name()

func _unhandled_input(event: InputEvent) -> void:
	if selection.inventory_open:
		return
	if event is InputEventKey:
		if not event.is_pressed() or event.is_echo():
			return
		for index: int in range(SLOT_ACTIONS.size()):
			if event.is_action_pressed(SLOT_ACTIONS[index]):
				selection.select_slot(index)
				get_viewport().set_input_as_handled()
				return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse == null or not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
		selection.cycle_selection(-1)
	elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		selection.cycle_selection(1)
	else:
		return
	get_viewport().set_input_as_handled()
