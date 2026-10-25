class_name FarmStorageService
extends Node
## Two world-owned inventories. All transfers stage both sides before notifying.
signal changed(storage_id: String)
var world: FarmWorld
var inventories: Dictionary = {}
var busy: bool = false
var catalog: SaveCatalog

func _ready() -> void:
	for id: String in FarmStorageSaveSchema.DEFINITIONS:
		var config: FarmStorageDefinition = FarmStorageSaveSchema.DEFINITIONS[id]
		inventories[id] = _create_inventory(id, config.slot_count, config.stack_cap)

func _create_inventory(id: String, slots: int, cap: int) -> InventoryComponent:
	var bag: InventoryComponent = InventoryComponent.new()
	bag.name = id
	bag.starting_tools = false
	bag.slot_count = slots
	bag.stack_cap = cap
	add_child(bag)
	bag.changed.connect(_inventory_changed.bind(id))
	return bag

func _inventory_changed(id: String) -> void:
	changed.emit(id)

func import_worker_products(source: InventoryComponent, supplies: bool = false) -> int:
	# Restore/legacy drain holds the worker lock; each item goes to its matching storage.
	if busy or world == null or not world.workers.busy or source == null:
		return 0
	var target: InventoryComponent = inventory("farm_supply_storage" if supplies else "produce_warehouse")
	if source == target:
		return 0
	var old_source: Array[Dictionary] = _snapshot(source)
	var source_slots: Array[Dictionary] = old_source.duplicate(true)
	var target_slots: Array[Dictionary] = _snapshot(target)
	var moved: int = 0
	for slot: Dictionary in old_source:
		var item: ItemDefinition = slot.item as ItemDefinition
		if item == null or (item.item_type != ItemDefinition.ItemType.FEED if supplies else not definition("produce_warehouse").accepts(item)):
			continue
		var amount: int = mini(int(slot.count), _capacity(target_slots, item, target))
		if amount > 0:
			_move_tiers(source_slots, target_slots, item, amount, target)
			moved += amount
	if moved == 0:
		return 0
	busy = true
	if not source.replace_slots(source_slots, false):
		busy = false
		return 0
	if not target.replace_slots(target_slots, false):
		source.replace_slots(old_source, false)
		busy = false
		return 0
	source.changed.emit()
	target.changed.emit()
	busy = false
	return moved

func seed_item(id: StringName) -> ItemDefinition:
	if catalog == null:
		catalog = SaveCatalog.new()
	var item: ItemDefinition = catalog.items.get(String(id)) as ItemDefinition
	return item if item != null and item.item_type == ItemDefinition.ItemType.SEED and definition("farm_supply_storage").accepts(item) else null

func refill_feed(trough: AnimalTrough, to_full: bool, worker: bool = false) -> int:
	if busy or world == null or not is_instance_valid(trough) or not world.is_ancestor_of(trough) or trough.kind != AnimalTrough.Kind.FOOD:
		return 0
	if worker:
		if not world.workers.busy:
			return 0
	else:
		if not available() or world.workers.busy or not world.player.state.trough_interaction.can_reach(trough):
			return 0
		world.workers.settle(world.farming.time_manager.now())
	busy = true
	# Trough API synchronizes the pen before reading demand and spending packs.
	var source: InventoryComponent = inventory("farm_supply_storage")
	var added: int = trough.refill_to_full(source) if to_full else trough.refill_from_inventory(source)
	busy = false
	return added

func plant_from_storage(id: StringName, revision: int, targets: Array[Vector2i]) -> Dictionary:
	var empty: Dictionary = {"changed": 0, "seed_spent": 0}
	if busy or not available() or world.workers.busy or world.farming.is_area_busy():
		return empty
	world.workers.settle(world.farming.time_manager.now())
	var selection: ToolSelectionComponent = world.player.selection
	var chosen_seed: ItemDefinition = seed_item(id)
	if chosen_seed == null or not selection.uses_storage_seeds() or selection.get_selected_item().item_id != id or selection.revision != revision or selection.is_menu_open():
		return empty
	busy = true
	var result: Dictionary = world.farming.apply_area(&"plant", targets, inventory("farm_supply_storage"), -1, chosen_seed, world.player, true)
	busy = false
	return result

func inventory(id: String) -> InventoryComponent:
	return inventories.get(id) as InventoryComponent

func definition(id: String) -> FarmStorageDefinition:
	return FarmStorageSaveSchema.DEFINITIONS.get(id) as FarmStorageDefinition

func available() -> bool:
	return world == null or (world.tool_upgrades != null and world.tool_upgrades.profile_ready)

func _snapshot(bag: InventoryComponent) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i: int in range(bag.slot_count):
		slots.append(bag.slot(i))
	return slots

func _capacity(slots: Array[Dictionary], item: ItemDefinition, bag: InventoryComponent) -> int:
	var result: int = 0
	for slot: Dictionary in slots:
		if slot.item == null:
			result += bag.stack_limit_for(item)
		elif item.matches(slot.item):
			result += maxi(0, bag.stack_limit_for(item) - int(slot.count))
	return result

func _move_tiers(source: Array[Dictionary], target: Array[Dictionary], item: ItemDefinition, amount: int, bag: InventoryComponent) -> void:
	var left: int = amount
	for stack: Dictionary in source:
		if stack.item == null or not item.matches(stack.item):
			continue
		for tier: int in range(3):
			var moved: int = mini(left, int(stack.tiers[tier]))
			if moved > 0:
				stack.tiers[tier] -= moved
				stack.count -= moved
				_add(target, item, moved, bag, tier)
				left -= moved
		if stack.count == 0:
			stack.item = null

func _add(slots: Array[Dictionary], item: ItemDefinition, amount: int, bag: InventoryComponent, tier: int = 0) -> void:
	var left: int = amount
	for stack: Dictionary in slots:
		if stack.item != null and item.matches(stack.item):
			var moved: int = mini(left, bag.stack_limit_for(item) - int(stack.count))
			stack.count += moved
			stack.tiers[tier] += moved
			left -= moved
	for stack: Dictionary in slots:
		if left > 0 and stack.item == null:
			var moved: int = mini(left, bag.stack_limit_for(item))
			stack.item = item
			stack.count = moved
			stack.tiers[tier] += moved
			left -= moved

func transfer(id: String, bag: InventoryComponent, item_id: StringName, amount: int, deposit: bool) -> Dictionary:
	return _transfer(id, bag, item_id, amount, deposit, false)

func transfer_all(id: String, bag: InventoryComponent, deposit: bool) -> Dictionary:
	return _transfer(id, bag, &"", 0, deposit, true)

func _failure(message: String) -> Dictionary:
	return {"ok": false, "moved": 0, "error": message}

func _transfer(id: String, bag: InventoryComponent, item_id: StringName, amount: int, deposit: bool, all_items: bool) -> Dictionary:
	if busy or not available() or inventory(id) == null or bag == null or bag == inventory(id):
		return _failure("Storage is unavailable.")
	if world != null:
		if world.workers.busy or bag != world.player.selection.inventory:
			return _failure("Storage is unavailable.")
		var access: FarmStorageAccess = world.storage_accesses.get(id) as FarmStorageAccess
		if access == null or not access.can_reach(world.player):
			return _failure("Move closer to the storage entrance.")
		world.workers.settle(world.farming.time_manager.now())
	if not all_items and (amount < 1 or amount > 100000000 or item_id.is_empty()):
		return _failure("Choose an item and quantity.")
	if catalog == null:
		catalog = SaveCatalog.new()
	var item: ItemDefinition = catalog.items.get(String(item_id)) as ItemDefinition
	if not all_items and not definition(id).accepts(item):
		return _failure("This item does not belong in this storage.")
	busy = true
	var source: InventoryComponent = bag if deposit else inventory(id)
	var target: InventoryComponent = inventory(id) if deposit else bag
	var old_source: Array[Dictionary] = _snapshot(source)
	var source_slots: Array[Dictionary] = old_source.duplicate(true)
	var target_slots: Array[Dictionary] = _snapshot(target)
	var totals: Dictionary = {}
	for slot: Dictionary in source_slots:
		if slot.item != null:
			var key: String = String(slot.item.item_id)
			totals[key] = int(totals.get(key, 0)) + int(slot.count)
	var moved: int = 0
	for key: String in totals:
		if not all_items and key != String(item_id):
			continue
		var candidate: ItemDefinition = catalog.items.get(key) as ItemDefinition
		if not definition(id).accepts(candidate):
			continue
		var requested: int = int(totals[key]) if all_items else mini(amount, int(totals[key]))
		var accepted: int = mini(requested, _capacity(target_slots, candidate, target))
		if accepted > 0:
			_move_tiers(source_slots, target_slots, candidate, accepted, target)
			moved += accepted
	if moved == 0:
		busy = false
		return _failure("Nothing can be moved. Check the source and destination capacity.")
	if not source.replace_slots(source_slots, false):
		busy = false
		return _failure("Unable to update storage.")
	if not target.replace_slots(target_slots, false):
		source.replace_slots(old_source, false)
		busy = false
		return _failure("Unable to update storage.")
	source.changed.emit()
	target.changed.emit()
	busy = false
	return {"ok": true, "moved": moved, "error": ""}

func capture() -> Dictionary:
	var result: Dictionary = {}
	for id: String in inventories:
		var bag: InventoryComponent = inventory(id)
		var slots: Array = []
		for slot: Dictionary in _snapshot(bag):
			slots.append({"item": String(slot.item.item_id) if slot.item != null else "", "count": int(slot.count), "tiers": slot.tiers.duplicate()})
		result[id] = {"slot_count": bag.slot_count, "stack_cap": bag.stack_cap, "slots": slots}
	return result

func restore(data: Dictionary, resources: SaveCatalog) -> void:
	busy = true
	catalog = resources
	for id: String in FarmStorageSaveSchema.DEFINITIONS:
		var old: InventoryComponent = inventory(id)
		remove_child(old)
		old.free()
		var row: Dictionary = data[id]
		var bag: InventoryComponent = _create_inventory(id, int(row.slot_count), int(row.stack_cap))
		inventories[id] = bag
		var slots: Array[Dictionary] = []
		for slot: Dictionary in row.slots:
			slots.append({"item": resources.items.get(slot.item), "count": int(slot.count), "tiers": slot.tiers.duplicate()})
		bag.replace_slots(slots, false)
	changed.emit("")
	busy = false
