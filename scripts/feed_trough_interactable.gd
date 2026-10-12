class_name FeedTroughInteractable
extends Interactable

@export_range(1,32000) var refill_amount: int = 100

@onready var trough: FeedTrough = get_parent() as FeedTrough

func _ready() -> void:
	assert(trough != null, "Component phải nằm dưới FeedTrough")


func prepare_action(
	_slot: ItemSlot,
	_inventory: Inventory
) -> ActionContext:
	if _slot == null or _slot.is_empty():
		return null
	
	var item := _slot.item
	
	if item.item_type != ItemDefinition.ItemType.FEED:
		return null
		
	if _slot.item.food_units_per_item <= 0:
		return null
	
	if trough.get_free_capacity() <= 0:
		return null
	
	return ActionContext.new(
		self,
		ActionContext.Kind.FILL_FEED,
		_slot,
		_inventory,
		ToolState.ACTION_TOOL
	)

func interact_with_item(_context: ActionContext) -> bool:
	if _context.kind != ActionContext.Kind.FILL_FEED:
		return false
	
	var amount := mini(
		_context.item.food_units_per_item,
		trough.get_free_capacity()
	)
	
	if amount <= 0:
		return false
		
	if not _context.slot.consume(1):
		return false
		
	return trough.add_food(amount) > 0
