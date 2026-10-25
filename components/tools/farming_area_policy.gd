class_name FarmingAreaPolicy
extends RefCounted
## Same deterministic footprint/eligibility for preview and impact-time commit.
static func tool_for(action: StringName) -> StringName:
	return &"hoe" if action == &"tool" else &"watering_can" if action == &"water" else &"sowing" if action == &"plant" else &""

static func cells(origin: Vector2i, facing: Vector2i, size: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if size < 1 or size > ToolUpgradeState.MAX_LEVEL or absi(facing.x) + absi(facing.y) != 1:
		return result
	var right: Vector2i = Vector2i(-facing.y, facing.x)
	var left: int = -floori(float(size - 1) / 2.0)
	for row: int in range(1, size + 1):
		for column: int in range(left, left + size):
			result.append(origin + facing * row + right * column)
	return result

static func evaluate(farm: FarmingController, action: StringName, targets: Array[Vector2i], inventory: InventoryComponent = null, slot: int = -1, actor: PhysicsBody2D = null, planting_seed: ItemDefinition = null, shared: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seeds: int = 0
	if action == &"plant" and inventory != null:
		var stack: Dictionary = inventory.slot(slot)
		var item: ItemDefinition = planting_seed if shared else stack.item as ItemDefinition
		if item != null and item.item_type == ItemDefinition.ItemType.SEED and item.crop is CropDefinition and item.crop.is_valid():
			seeds = inventory.count_item(item.item_id) if shared else int(stack.count)
	for cell: Vector2i in targets:
		var valid: bool = farm.can_till(cell, actor) if action == &"tool" else farm.can_water(cell, actor) if action == &"water" else farm.can_plant(cell, actor) if action == &"plant" else false
		var ready: bool = valid and (action != &"plant" or seeds > 0)
		if ready and action == &"plant":
			seeds -= 1
		result.append({"cell": cell, "valid": valid, "ready": ready})
	return result
