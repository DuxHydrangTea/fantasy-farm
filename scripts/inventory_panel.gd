class_name InventoryPanel
extends PanelContainer

const SLOT_VIEW_SCENE: PackedScene = preload("res://scenes/item_slot_view.tscn")

@export var inventory: Inventory

@onready var slots_grid: GridContainer = $MarginContainer/VBoxContainer/SlotsGrid

var _buttons: Array[ItemSlotView] = []

func _ready() -> void:
	hide()
	
	if not is_instance_valid(inventory):
		push_error("Kho đồ chưa được gán")
		return
	
	if not inventory.is_node_ready():
		await inventory.ready
	
	if not is_instance_valid(inventory):
		return
	
	slots_grid.columns = 4
	
	for index in range(inventory.slots.size()):
		var button := SLOT_VIEW_SCENE.instantiate() as ItemSlotView

		slots_grid.add_child(button)
		_buttons.append(button)
		_refresh_slot(index)
		
	inventory.slot_changed.connect(_refresh_slot)

func _refresh_slot(index: int) ->void:
	if not is_instance_valid(inventory):
		return
	
	if index < 0 or index >= inventory.slots.size():
		return
		
	if index >= _buttons.size():
		return
		
	var slot: ItemSlot = inventory.slots[index]
	var button: ItemSlotView = _buttons[index]
	button.display_slot(slot)

func toggle() -> void:
	if visible:
		close()
	else:
		open_inventory()

func open_inventory() -> void:
	_refresh_all_slots()
	show()
	
func _refresh_all_slots() -> void:
	for index in range(_buttons.size()):
		_refresh_slot(index)

func close() -> void:
	hide()
