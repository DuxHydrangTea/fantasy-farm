class_name ItemSlotView
extends Button

@onready var item_icon: TextureRect = $Icon
@onready var quantity_label: Label = $Quantity


func display_slot(slot: ItemSlot) -> void:
	item_icon.texture = null
	quantity_label.text = ""
	tooltip_text = ""

	if slot == null or slot.is_empty():
		return

	item_icon.texture = slot.item.icon
	tooltip_text = slot.item.display_name

	if slot.item.item_type != ItemDefinition.ItemType.TOOL:
		quantity_label.text = str(slot.quantity)
