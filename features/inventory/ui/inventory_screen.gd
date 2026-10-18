class_name InventoryScreen
extends Control

@export var inventory: InventoryComponent
@export var item_view_scene: PackedScene

@onready var items_grid: GridContainer = %ItemsGrid

var _views: Array[InventoryItemView] = []

func _ready() -> void:
	assert(inventory != null, "Ivnentory Compoennt chưa được gán")
	assert(item_view_scene != null, "Item View Scene chưa được gán")
	hide()
	
	for index: int in range(inventory.get_slot_count()):
		var view = item_view_scene.instantiate() as InventoryItemView
		assert(view != null, "Item View phải là Inventory Item View")
		
		view.drag_enabled = true
		view.inventory = inventory
		view.slot_index = index
		items_grid.add_child(view)
		_views.append(view)
	
	inventory.slots_changed.connect(_refresh_slots)
	_refresh_slots()
	
func _refresh_slots() -> void:
	for index: int in range(_views.size()):
		var slot: InventorySlot = inventory.get_slot(index)
		assert(slot != null, "Không tìm thấy ô inventory")
		_views[index].set_item(slot.item, slot.amount)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_inventory"):
		set_open(not visible)
	elif event.is_action_pressed(&"ui_cancel"):
		set_open(false)
	else:
		return
	get_viewport().set_input_as_handled()

func set_open(value: bool) -> void:
	if visible == value:
		return
	visible = value

func is_open() -> bool:
	return visible == true
