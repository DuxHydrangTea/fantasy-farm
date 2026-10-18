class_name InventoryItemView
extends PanelContainer

@onready var icon: TextureRect = $Content/MarginContainer/Icon
@onready var amount_label: Label = $Content/AmountLabel

var drag_enabled: bool = false
var _item_id: StringName = &""
var inventory: InventoryComponent
var slot_index: int = -1

func _ready() -> void:
	clear_item()
	
func set_item(definition: ItemDefinition, amount: int) -> void:
	if definition == null or amount == 0:
		clear_item()
		return
	
	icon.texture = definition.icon
	tooltip_text = definition.display_name
	amount_label.text = str(amount)
	_item_id = definition.item_id

func clear_item() -> void:
	icon.texture = null
	amount_label.text = ""
	tooltip_text = ""
	_item_id = &""

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled or inventory == null or slot_index < 0:
		return null
		
	if _item_id == &"":
		return null
	
	var preview: TextureRect = TextureRect.new()
	preview.texture = icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(24,24)
	preview.size = Vector2(24,24)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	
	return {
		"type": &"inventory_slot",
		"inventory": inventory,
		"source_index": slot_index,
	}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if inventory == null or not data is Dictionary:
		return false
	
	if data.get("type") != &"inventory_slot":
		return false
	
	if data.get("inventory") != inventory:
		return false
		
	var source_index: Variant = data.get("source_index")
	if not source_index is int  or source_index == slot_index:
		return false
	
	var source: InventorySlot = inventory.get_slot(source_index)
	var target: InventorySlot = inventory.get_slot(slot_index)
	return source != null and not source.is_empty() and target != null

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	
	var source_index: int = data["source_index"]
	inventory.move_or_swap_slot(source_index, slot_index)
