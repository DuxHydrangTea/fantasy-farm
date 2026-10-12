class_name WaterTroughInteractable
extends Interactable

@export_range(1,32000) var refill_amount: int = 100

@onready var trough: WaterTrough = get_parent() as WaterTrough

func _ready() -> void:
	assert(trough != null, "Component phải nằm dưới WaterTrough")


func prepare_action(
	_slot: ItemSlot,
	_inventory: Inventory
) -> ActionContext:
	if _slot == null or _slot.is_empty():
		return null
	
	var item := _slot.item
	
	if item.item_type != ItemDefinition.ItemType.TOOL:
		return null
		
	if item.tool_type != ItemDefinition.ToolType.WATERING_CAN:
		return null
	
	if trough.get_free_capacity() <= 0:
		return null
	
	return ActionContext.new(
		self,
		ActionContext.Kind.FILL_WATER,
		_slot,
		_inventory,
		ToolState.ACTION_WATER
	)

func interact_with_item(_context: ActionContext) -> bool:
	if _context.kind != ActionContext.Kind.FILL_WATER:
		return false
		
	return trough.add_water(refill_amount) > 0
