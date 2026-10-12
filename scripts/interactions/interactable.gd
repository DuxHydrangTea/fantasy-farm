class_name Interactable
extends Node

const COMPONENT_PATH: NodePath = ^"Interactable"

func prepare_action(
	_slot: ItemSlot,
	_inventory: Inventory
) -> ActionContext:
	return null

func interact_with_item(_context: ActionContext) -> bool:
	return false
	
static func prepare_for(
	focused_target: Node,
	slot: ItemSlot,
	inventory: Inventory
) -> ActionContext:
	if is_instance_valid(focused_target):
		var component := focused_target.get_node_or_null(COMPONENT_PATH) as Interactable
		
		if component != null:
			var context := component.prepare_action(slot, inventory)
			
			if context != null:
				return context

	if slot == null or slot.is_empty():
		return null
		
	if (
		slot.item.item_type == ItemDefinition.ItemType.TOOL
		or slot.item.item_type == ItemDefinition.ItemType.HOE
	):
		return ActionContext.new(
			null,
			ActionContext.Kind.SWING,
			slot,
			inventory,
			ToolState.ACTION_TOOL
		)
	return null
	
