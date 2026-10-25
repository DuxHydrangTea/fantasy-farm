class_name GraftService
extends RefCounted
## Manual strategy command. Settle old worker time before changing the next crop.
signal changed
const WAX: StringName = &"grafting_wax"
var world: FarmWorld
var busy: bool = false

func access_error(tree: FruitTree) -> String:
	if busy or world == null or not world.tool_upgrades.profile_ready or world.workers.busy or world.storages.busy or world.wood_market.busy or world.cooking.busy or world.tool_upgrade_state.is_busy():
		return "Grafting is unavailable."
	if not is_instance_valid(tree) or tree.removed or not world.is_ancestor_of(tree) or tree._busy:
		return "This tree is unavailable."
	if not InteractionTarget.new(tree, InteractionTarget.Kind.TREE, world.player).reachable_from(world.player.global_position):
		return "Move closer to this tree."
	if not tree.is_mature():
		return "Wait until the tree is mature."
	return ""

func quote(tree: FruitTree, direction: int) -> Dictionary:
	var error: String = access_error(tree)
	if not error.is_empty():
		return {"ok": false, "error": error}
	if direction not in [FruitTree.Graft.YIELD, FruitTree.Graft.QUALITY] or (direction == FruitTree.Graft.QUALITY and tree.definition.star_harvest_item == null):
		return {"ok": false, "error": "Invalid graft direction."}
	var planned: int = tree.pending_graft if tree.pending_graft != FruitTree.Graft.NONE else tree.active_graft
	if direction == planned:
		return {"ok": false, "error": "This graft direction is already selected."}
	var cost: int = 0 if tree.active_graft == FruitTree.Graft.NONE and tree.pending_graft == FruitTree.Graft.NONE else 1
	return {"ok": world.player.selection.inventory.count_item(WAX) >= cost, "error": "Not enough Grafting Wax in your bag." if world.player.selection.inventory.count_item(WAX) < cost else "", "wax": cost, "revision": tree.graft_revision}

func choose(tree: FruitTree, direction: int, expected_revision: int) -> String:
	var error: String = access_error(tree)
	if not error.is_empty():
		return error
	world.workers.settle(world.farming.time_manager.now())
	var offer: Dictionary = quote(tree, direction)
	if not offer.ok:
		return offer.error
	if tree.graft_revision != expected_revision:
		return "The tree changed. Review its current crop and try again."
	_lock(true)
	tree._busy = true
	var bag: InventoryComponent = world.player.selection.inventory
	if offer.wax > 0:
		bag.remove(WAX, 1, false)
	tree.pending_graft = direction
	tree.graft_revision += 1
	if offer.wax > 0:
		bag.changed.emit()
	changed.emit()
	tree._busy = false
	_lock(false)
	return ""

func collect(tree: FruitTree) -> String:
	var error: String = access_error(tree)
	if not error.is_empty():
		return error
	world.workers.settle(world.farming.time_manager.now())
	error = access_error(tree)
	if not error.is_empty():
		return error
	_lock(true)
	var collected: bool = tree.harvest(world.player.selection.inventory)
	changed.emit()
	_lock(false)
	return "" if collected else "Fruit is not ready or your bag cannot hold the whole crop."

func _lock(value: bool) -> void:
	busy = value
	world.workers.busy = value
	world.storages.busy = value

func order_demand(tree: FruitTree) -> int:
	var count: int = 0
	for row: Dictionary in world.orders.service.capture().slots:
		if not row.has("serial"):
			continue
		var entry: OrderDefinition = world.orders.service.definition(int(row.serial))
		if entry != null:
			for item: ItemDefinition in entry.items:
				if item.matches(tree.definition.harvest_item):
					count += 1
					break
	return count

func kitchen_demand(tree: FruitTree) -> int:
	var count: int = 0
	for recipe: CookingRecipe in ChefCooking.RECIPES:
		if recipe.ingredients.has(tree.definition.star_harvest_item):
			count += 1
	return count
