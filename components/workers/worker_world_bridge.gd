class_name WorkerWorldBridge
extends RefCounted
## Scene/API boundary; scheduling policy and persisted tasks contain only primitives.
var world: FarmWorld
var storage_waiting: Dictionary = {}

func _init(scene: FarmWorld) -> void:
	world = scene

func pens() -> Array[AnimalPen]:
	var result: Array[AnimalPen] = []
	for node: Node in world.get_children():
		if node is AnimalPen:
			result.append(node as AnimalPen)
	return result

func pen_for(id: String) -> AnimalPen:
	for pen: AnimalPen in pens():
		if String(pen.persistent_id) == id:
			return pen
	return null

func home(role: String, zone: String = "") -> Vector2:
	if role == "ranch":
		var pen: AnimalPen = pen_for(zone)
		if pen != null:
			var point: Vector2 = pen.to_global(pen.allowed_bounds(20).position + Vector2(20, 20))
			return (pen as PondPen).closest_land(point) if pen is PondPen else point
	var cell: Vector2i = TreePlantation.FRUIT_REGION.position + Vector2i(1, 4) if role == "orchard" else Vector2i(LandExpansionState.REGION.end.x - world.land.state.unlocked_columns + 1, LandExpansionState.REGION.position.y + 1)
	return world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell))

func zone_contains(row: Dictionary, point: Vector2, columns: int = -1) -> bool:
	if row.role == "ranch":
		var pen: AnimalPen = pen_for(row.zone)
		return pen != null and pen.contains_world(point, 4)
	var cell: Vector2i = world.farming.world_to_cell(point)
	if row.role == "orchard":
		return TreePlantation.FRUIT_REGION.has_point(cell)
	return LandExpansionState.REGION.has_point(cell) and LandExpansionState.cell_is_open(cell, world.land.state.unlocked_columns if columns < 0 else columns)

func sync(timestamp: float, offline: bool = true) -> void:
	world.weather.advance(timestamp)
	world.apiary.advance(timestamp)
	world.trees.advance(timestamp)
	world.farming._refresh_crops(timestamp)
	if offline:
		for pen: AnimalPen in pens():
			pen.advance_offline(timestamp, true)

func _task(kind: String, id: String, point: Vector2, priority: int) -> Dictionary:
	return {"kind": kind, "id": id, "point": WorkerRole.pair(point), "priority": priority}

func candidates(row: Dictionary, feed_inventory: InventoryComponent) -> Array[Dictionary]:
	var output_inventory: InventoryComponent = world.workers.output_inventory()
	storage_waiting[row.role] = false
	var tasks: Array[Dictionary] = []
	if row.role == "orchard":
		for tree: PerennialTree in world.trees.trees.values():
			if tree is FruitTree and not tree.removed and (tree as FruitTree).has_fruit():
				if output_inventory.capacity_for((tree as FruitTree).harvest_item()) < (tree as FruitTree).harvest_amount():
					storage_waiting[row.role] = true
					continue
				var task: Dictionary = _task("fruit", "%d_%d" % [tree.cell.x, tree.cell.y], tree.global_position + Vector2(0, 12), 0)
				task["cell"] = [tree.cell.x, tree.cell.y]
				tasks.append(task)
	elif row.role == "crop":
		for cell: Vector2i in world.farming.crop_cells():
			var crop: Crop = world.farming.get_crop(cell)
			if not world.land.state.is_unlocked(cell):
				continue
			var kind: String = ""
			if crop.is_mature():
				if output_inventory.capacity_for(crop.definition.harvest_item) >= world.farming.harvest_amount(cell):
					kind = "harvest"
				else:
					storage_waiting[row.role] = true
			elif world.farming.can_water(cell) and not crop.is_mature():
				kind = "water_crop"
			if not kind.is_empty():
				var task: Dictionary = _task(kind, "%d_%d" % [cell.x, cell.y], world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell)), 0 if kind == "harvest" else 1)
				task["cell"] = [cell.x, cell.y]
				tasks.append(task)
			var fertilizer: Dictionary = world.workers.crop_policy.fertilizer_task(cell, crop)
			if not fertilizer.is_empty():
				tasks.append(fertilizer)
		var opening: Dictionary = world.workers.crop_policy.planting_task(row)
		if not opening.is_empty():
			tasks.append(opening)
	else:
		var pen: AnimalPen = pen_for(row.zone)
		if pen != null:
			for node: Node in pen.get_children():
				if not node is AnimalTrough:
					continue
				var trough: AnimalTrough = node as AnimalTrough
				var kind: String = ""
				if trough.kind == AnimalTrough.Kind.FOOD and (trough.feed_items_needed(feed_inventory) > 0 or (trough.feed_reserve > 0 and trough.stock < trough.capacity)):
					kind = "feed"
				elif trough.kind == AnimalTrough.Kind.WATER and trough.stock <= trough.capacity - trough.water_per_use:
					kind = "water_trough" if int(row.water_units) > 0 else "fetch_water"
				if not kind.is_empty():
					var point: Vector2 = pen.clamp_world(trough.global_position + Vector2(0, 16), 6)
					if kind == "fetch_water":
						point = home("ranch", row.zone) # Explicit free source inside assigned pen.
					tasks.append(_task(kind, String(trough.persistent_id), point, 0 if trough.stock == 0 else 1))
	for node: Node in world.get_tree().get_nodes_in_group(&"item_pickups"):
		var pile: ItemPickup = node as ItemPickup
		if pile == null or not world.is_ancestor_of(pile) or pile.is_queued_for_deletion() or pile.is_attracting() or pile.item == null or pile.item.item_type != ItemDefinition.ItemType.PRODUCE or pile.amount <= 0 or not zone_contains(row, pile.global_position):
			continue
		if output_inventory.capacity_for(pile.item) <= 0:
			storage_waiting[row.role] = true
			continue
		if pile.persistent_id.is_empty():
			pile.persistent_id = StringName("pile_" + Crypto.new().generate_random_bytes(12).hex_encode())
		tasks.append(_task("pickup", String(pile.persistent_id), pile.global_position, 3 if row.role == "crop" and world.workers.crop_automation.auto_plant else 2))
	return tasks

func commit(row: Dictionary, _feed_inventory: InventoryComponent, task: Dictionary) -> bool:
	if task.kind in ["till", "plant", "fertilize"]:
		return row.role == "crop" and world.workers.crop_policy.commit(row, task)
	if task.kind in ["fruit", "harvest", "pickup"]:
		if world.storages.busy:
			return false
		world.storages.busy = true
		var result: bool = _commit_output(row, world.workers.output_inventory(), task)
		world.storages.busy = false
		return result
	match String(task.kind):
		"patrol":
			row.patrol_index = (int(row.patrol_index) + 1) % 4
			return true
		"water_crop":
			return world.farming.water(Vector2i(int(task.cell[0]), int(task.cell[1])))
		"fetch_water":
			row.water_units = 30
			return true
		"feed", "water_trough":
			var pen: AnimalPen = pen_for(row.zone)
			if pen == null:
				return false
			for node: Node in pen.get_children():
				if node is AnimalTrough and String(node.persistent_id) == task.id:
					var trough: AnimalTrough = node as AnimalTrough
					if task.kind == "feed":
						var fed: int = world.storages.refill_feed(trough, true, true)
						if fed > 0:
							world.farming.action_committed.emit(&"refill_food", 1)
						return fed > 0
					var added: int = trough.refill(int(row.water_units))
					row.water_units -= added
					if added > 0:
						world.farming.action_committed.emit(&"refill_water", 1)
					return added > 0
	return false

func _commit_output(row: Dictionary, output_inventory: InventoryComponent, task: Dictionary) -> bool:
	match String(task.kind):
		"fruit":
			var tree: FruitTree = world.trees.trees.get(Vector2i(int(task.cell[0]), int(task.cell[1]))) as FruitTree
			return tree != null and tree.harvest(output_inventory)
		"harvest":
			return world.farming.harvest(Vector2i(int(task.cell[0]), int(task.cell[1])), output_inventory)
		"pickup":
			for node: Node in world.get_tree().get_nodes_in_group(&"item_pickups"):
				var pile: ItemPickup = node as ItemPickup
				if pile != null and world.is_ancestor_of(pile) and String(pile.persistent_id) == task.id and not pile.is_attracting() and zone_contains(row, pile.global_position):
					return pile.item != null and world.storages.definition("produce_warehouse").accepts(pile.item) and pile.collect(output_inventory) > 0
	return false

func next_wake(row: Dictionary, feed_inventory: InventoryComponent, now: float) -> float:
	var next: float = world.weather.schedule.dawn_at(world.weather.schedule.day_at(now) + 1)
	if row.role == "orchard":
		for tree: PerennialTree in world.trees.trees.values():
			if tree is FruitTree and tree.growth_started_at >= 0 and world.workers.output_inventory().capacity_for((tree as FruitTree).harvest_item()) >= (tree as FruitTree).harvest_amount():
				var remaining: float = maxf(0, tree.matures_at - now) + maxf(0, tree.definition.fruit_cycle_seconds - (tree as FruitTree).fruit_work) * 0.75
				if remaining > 0.01:
					next = minf(next, now + remaining)
	elif row.role == "crop":
		for cell: Vector2i in world.farming.crop_cells():
			var crop: Crop = world.farming.get_crop(cell)
			if crop.matures_at > now:
				next = minf(next, crop.matures_at)
			if world.farming._moisture.has(cell):
				next = minf(next, now + maxf(1, float(world.farming._moisture[cell]) / world.weather.schedule.evaporation_rate(now)))
	else:
		next = minf(next, _ranch_boundary(row, feed_inventory, now))
	return maxf(now + 0.25, next)

func _ranch_boundary(record: Dictionary, bag: InventoryComponent, now: float) -> float:
	var pen: AnimalPen = pen_for(record.zone)
	var next: float = world.weather.schedule.next_boundary(now)
	if pen == null:
		return next
	var herd: Array[Dictionary] = []
	var supplies: Array[Dictionary] = []
	var stations: Dictionary = {}
	for child: Node in pen.get_children():
		if child is AnimalActor:
			var actor: AnimalActor = child as AnimalActor
			if actor.is_dead():
				continue
			herd.append({"id": String(actor.persistent_id), "species": int(actor.definition.species), "food_seconds": actor.needs.satiety_depletion_seconds, "water_seconds": actor.needs.hydration_depletion_seconds, "satiety": actor.needs.satiety, "hydration": actor.needs.hydration})
			var production: AnimalProductionComponent = actor.production
			if production.definition != null:
				next = minf(next, now + maxf(1, production.definition.production_seconds - production.progress_seconds))
		elif child is AnimalTrough:
			var trough: AnimalTrough = child as AnimalTrough
			var id: String = String(trough.persistent_id)
			stations[id] = trough
			supplies.append({"id": id, "kind": int(trough.kind), "stock": trough.available_units(), "restoration": trough.restoration_per_unit, "species": trough.allowed_species.duplicate()})
	supplies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.id) < String(b.id))
	PenOfflineModel._top_up(herd, supplies, 0, "satiety")
	PenOfflineModel._top_up(herd, supplies, 1, "hydration")
	var food: Dictionary = PenOfflineModel._rates(herd, supplies, 0, 1.0)
	var water: Dictionary = PenOfflineModel._rates(herd, supplies, 1, world.weather.schedule.water_rate(now))
	for supply: Dictionary in supplies:
		var rate: float = float(food.troughs.get(supply.id, 0.0)) + float(water.troughs.get(supply.id, 0.0))
		if rate <= 0.0:
			continue
		next = minf(next, now + maxf(0.25, float(supply.stock) / rate))
		var trough: AnimalTrough = stations[supply.id] as AnimalTrough
		var units: int = trough.water_per_use if trough.kind == AnimalTrough.Kind.WATER else 1 if trough.feed_reserve > 0 else maxi(1, trough.feed_item.food_units_per_item) if trough.feed_item != null else 1
		if trough.kind == AnimalTrough.Kind.WATER or trough.feed_reserve > 0 or (trough.feed_item != null and bag.count_item(trough.feed_item.item_id) > 0):
			next = minf(next, now + maxf(0.25, (float(supply.stock) - float(trough.capacity - units)) / rate))
	return next

func patrol_point(row: Dictionary) -> Vector2:
	var rect: Rect2
	if row.role == "ranch":
		var pen: AnimalPen = pen_for(row.zone)
		rect = pen.allowed_bounds(20)
		var local: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		var point: Vector2 = pen.to_global(local[int(row.patrol_index)])
		return (pen as PondPen).closest_land(point) if pen is PondPen else point
	var region: Rect2i = TreePlantation.FRUIT_REGION if row.role == "orchard" else LandExpansionState.REGION
	if row.role == "crop":
		region.position.x = region.end.x - world.land.state.unlocked_columns
		region.size.x = world.land.state.unlocked_columns
	var ground: TileMapLayer = world.farming.farmland
	var a: Vector2 = ground.to_global(ground.map_to_local(region.position))
	var b: Vector2 = ground.to_global(ground.map_to_local(region.end))
	rect = Rect2(a, b - a).grow(-12)
	var points: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	return points[int(row.patrol_index)]
