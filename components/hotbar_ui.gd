class_name HotbarUI
extends CanvasLayer

const SLOT_ACTIONS: Array[StringName] = [&"hotbar_1", &"hotbar_2", &"hotbar_3", &"hotbar_4", &"hotbar_5", &"hotbar_6"]

@export var selection: ToolSelectionComponent
@export var slots: HBoxContainer
@export var selected_name: Label
var buttons: Array[InventorySlot] = []

func _ready() -> void:
	assert(selection != null, "Hotbar requires ToolSelection")
	for index: int in range(selection.HOTBAR_SIZE):
		var button: InventorySlot = InventorySlot.new()
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
		buttons[i].set_selected(i == index)
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
