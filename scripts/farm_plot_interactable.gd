class_name FarmPlotInteraction
extends Interactable

@onready var plot: FarmPlot = get_parent() as FarmPlot

func _ready() -> void:
	assert(plot != null, "Component phải nằm dưới FarmPlot")
	
func prepare_action(
	slot: ItemSlot,
	inventory: Inventory
) -> ActionContext:
	# Ưu tiên thu hoạc
	if plot.is_mature():
		if not is_instance_valid(inventory):
			return null
		
		if not plot.crop.has_valid_harvest():
			return null
			
		return ActionContext.new(
			self,
			ActionContext.Kind.HARVEST,
			slot,
			inventory
		)
	
	if slot == null or slot.is_empty():
		return null
		
	# Hành động gieo hạt
	var item := slot.item
	if item.item_type == ItemDefinition.ItemType.SEED:
		if plot.has_crop():
			return null
		
		if item.crop == null or not item.crop.is_valid():
			return null
		
		return ActionContext.new(
			self,
			ActionContext.Kind.PLANT,
			slot,
			inventory,
			ToolState.ACTION_TOOL
		)
	
	# Hành động tưới cây
	if (
		item.item_type == ItemDefinition.ItemType.TOOL
		and item.tool_type == ItemDefinition.ToolType.WATERING_CAN
	):
		return ActionContext.new(
			self,
			ActionContext.Kind.WATER_SOIL,
			slot,
			inventory,
			ToolState.ACTION_WATER
		)
	
	return null

func interact_with_item(context: ActionContext) -> bool:
	match context.kind:
		ActionContext.Kind.PLANT:
			if not plot.plant(context.item.crop):
				return false
			
			return context.slot.consume_seed(1)
		ActionContext.Kind.WATER_SOIL:
			return plot.water()
		ActionContext.Kind.HARVEST:
			return _harvest(context.inventory)
	
	return false
	
func _harvest(inventory: Inventory) -> bool:
	if not plot.is_mature():
		return false
		
	if not is_instance_valid(inventory):
		return false
		
	var definition := plot.crop
	
	if definition == null or not definition.has_valid_harvest():
		return false
		
	if not inventory.try_add_item(
		definition.harvest_item,
		definition.harvest_amount
	):
		print("Kho không đủ chỗ nhận toàn bộ sản lượng")
		return false
		
	return plot.harvest()
