class_name ActionContext
extends RefCounted

enum Kind {
	SWING,
	PLANT,
	WATER_SOIL,
	FILL_WATER,
	FILL_FEED,
	HARVEST
}

var kind: Kind
var target: Interactable
var slot: ItemSlot
var item: ItemDefinition
var inventory: Inventory
var animation_action: StringName

var _executed: bool = false

func _init(
	p_target: Interactable,
	p_kind: Kind,
	p_slot: ItemSlot,
	p_inventory: Inventory,
	p_animation: StringName = &""
) -> void:
	target = p_target
	kind = p_kind
	slot = p_slot
	inventory = p_inventory
	animation_action = p_animation
	
	if slot != null:
		item = slot.item

func requires_animation() -> bool:
	return not animation_action.is_empty()
	
func has_current_item() -> bool:
	return (
		slot != null
		and not slot.is_empty()
		and item != null
		and slot.item == item
	)

func execute_once() -> bool:
	if _executed:
		return false
		
	_executed = true
	
	if kind != Kind.HARVEST and not has_current_item():
		return false
	
	if kind == Kind.SWING:
		return true
	
	if not is_instance_valid(target):
		return false
		
	return target.interact_with_item(self)	
