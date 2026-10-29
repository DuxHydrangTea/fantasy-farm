class_name CropWorkerPolicy
extends RefCounted
## Queries only on scheduler events. Terrain cache is bounded to the open field.
var world: FarmWorld
var cells: Array[Vector2i] = []
var soils: Dictionary[Vector2i, int] = {}
var cached_columns: int = -1
var waiting: String = ""

func _init(scene: FarmWorld) -> void:
	world = scene

func invalidate() -> void:
	cached_columns = -1

func soil_changed(cell: Vector2i, state: int) -> void:
	soils[cell] = state

func first_item(fertilizer: bool = false, worker_id: String = "") -> ItemDefinition:
	var bag: InventoryComponent = world.storages.inventory("farm_supply_storage")
	for i: int in range(bag.slot_count):
		var slot: Dictionary = bag.slot(i)
		var item: ItemDefinition = slot.item as ItemDefinition
		if item == null or int(slot.count) <= 0:
			continue
		var suitable: bool = item.item_type == ItemDefinition.ItemType.BOOSTER and item.booster_kind == ItemDefinition.BoosterKind.FERTILIZER if fertilizer else item.item_type == ItemDefinition.ItemType.SEED and item.crop is CropDefinition and item.crop.is_valid()
		if suitable and bag.count_item(item.item_id) > world.workers.reserved_items(String(item.item_id), worker_id):
			return item
	return null

func _cache() -> void:
	if cached_columns == world.land.state.unlocked_columns:
		return
	cached_columns = world.land.state.unlocked_columns
	cells.clear()
	soils.clear()
	var layer: TileMapLayer = world.farming.farmland
	for cell: Vector2i in layer.get_used_cells():
		if not LandExpansionState.REGION.has_point(cell) or not world.land.state.is_unlocked(cell):
			continue
		var data: TileData = layer.get_cell_tile_data(cell)
		if data != null and data.has_custom_data(&"can_plant") and data.get_custom_data(&"can_plant") == true:
			cells.append(cell)
			soils[cell] = int(world.farming.get_soil_state(cell))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))

func task(kind: String, cell: Vector2i, priority: int, item: ItemDefinition = null) -> Dictionary:
	var point: Vector2 = world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell))
	var result: Dictionary = {"kind": kind, "id": "%d_%d" % [cell.x, cell.y], "point": WorkerRole.pair(point), "priority": priority, "cell": [cell.x, cell.y], "revision": world.workers.crop_automation.revision}
	if item != null:
		result["item"] = String(item.item_id)
	return result

func planting_task(row: Dictionary) -> Dictionary:
	waiting = ""
	var settings: CropAutomationState = world.workers.crop_automation
	if not settings.auto_plant:
		return {}
	var item: ItemDefinition = first_item(false, row.id)
	if item == null:
		waiting = "Waiting for crop seeds in supply storage."
		return {}
	_cache()
	var actor: WorkerActor = world.workers.actor_for(row.id)
	var origin: Vector2 = WorkerRole.point(row.position)
	var prepared: Vector2i = settings.prepared_for(row.id)
	if LandExpansionState.REGION.has_point(prepared) and (world.farming.get_crop(prepared) != null or int(soils.get(prepared, 0)) == FarmingController.Soil.UNTILLED or not world.farming.can_plant(prepared, actor)):
		settings.prepared.erase(row.id)
		prepared = settings.prepared_for(row.id)
	var excluded: Dictionary = {}
	var timestamp: float = world.farming.time_manager.now()
	for attempt: int in range(32):
		var best: Vector2i = Vector2i(-1, -1)
		var best_rank: int = 0x7FFFFFFFFFFFFFFF
		var best_soil: int = 2
		var distance: float = INF
		for cell: Vector2i in cells:
			if excluded.has(cell) or world.farming._occupied.has(cell) or world.farming.get_crop(cell) != null or not world.workers.target_available(row, task("plant", cell, 4)):
				continue
			var id: String = "%s:%d_%d" % [row.id, cell.x, cell.y]
			if float(world.workers.blocked_targets.get(id, 0)) > timestamp:
				continue
			var soil: int = int(soils.get(cell, 0))
			if soil == FarmingController.Soil.UNTILLED and LandExpansionState.REGION.has_point(prepared):
				continue # At most one worker-created plot waiting for its seed.
			var rank: int = -1 if cell == prepared else int(settings.plots.get(cell, {}).get("last", 0))
			var unprepared: int = 1 if soil == FarmingController.Soil.UNTILLED else 0
			var point: Vector2 = world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell))
			var next_distance: float = origin.distance_squared_to(point)
			if rank < best_rank or (rank == best_rank and (unprepared < best_soil or (unprepared == best_soil and next_distance < distance))):
				best = cell
				best_rank = rank
				best_soil = unprepared
				distance = next_distance
		if best.x < 0:
			break
		var untilled: bool = int(soils[best]) == FarmingController.Soil.UNTILLED
		if world.farming.can_till(best, actor) if untilled else world.farming.can_plant(best, actor):
			return task("till" if untilled else "plant", best, 5 if untilled else 4, item)
		excluded[best] = true
		world.workers.blocked_targets["%s:%d_%d" % [row.id, best.x, best.y]] = timestamp + 120.0
	waiting = "No reachable empty plot is available."
	return {}

func fertilizer_task(cell: Vector2i, crop: Crop, item: ItemDefinition = null, sync_apiary: bool = true, worker_id: String = "crop") -> Dictionary:
	var settings: CropAutomationState = world.workers.crop_automation
	if not settings.auto_fertilize or not settings.owns(cell, crop) or crop.fertilized:
		return {}
	if item == null:
		item = first_item(true, worker_id)
	# Late crops cannot accept fertilizer. Avoid a physics query for every
	# mature plot while a full field is waiting for warehouse space.
	if item == null:
		return {}
	if not sync_apiary and not crop.fertilizer_error(world.farming.time_manager.now()).is_empty():
		return {}
	var actor: WorkerActor = world.workers.actor_for(worker_id)
	if not world.farming.fertilizer_error(cell, actor, sync_apiary).is_empty():
		return {}
	var result: Dictionary = task("fertilize", cell, 2, item)
	result["crop"] = String(crop.definition.crop_id)
	result["planted_at"] = crop.planted_at
	return result

func commit(row: Dictionary, job: Dictionary) -> bool:
	var settings: CropAutomationState = world.workers.crop_automation
	var service: WorkerService = world.workers
	if not service.busy or world.storages.busy or settings.paused or not row.employed or not row.active or int(job.get("revision", -1)) != settings.revision:
		return false
	var cell: Vector2i = Vector2i(int(job.cell[0]), int(job.cell[1]))
	if not world.land.state.is_unlocked(cell) or not LandExpansionState.REGION.has_point(cell) or world.farming.is_area_busy():
		return false
	var actor: WorkerActor = service.actor_for(row.id)
	var bag: InventoryComponent = world.storages.inventory("farm_supply_storage")
	world.storages.busy = true
	var success: bool = false
	if job.kind == "till" and settings.auto_plant and first_item(false, row.id) != null and world.farming.get_crop(cell) == null:
		success = world.farming.apply_area(&"tool", [cell], null, -1, null, actor).changed == 1
		if success:
			settings.clear_prepared(cell)
			settings.prepared[row.id] = cell
	elif job.kind == "plant" and settings.auto_plant:
		var item: ItemDefinition = world.storages.seed_item(StringName(job.item))
		if item != null and bag.count_item(item.item_id) > 0:
			success = world.farming.apply_area(&"plant", [cell], bag, -1, item, actor, true).changed == 1
			if success:
				settings.remember(cell, world.farming.get_crop(cell))
	elif job.kind == "fertilize" and settings.auto_fertilize:
		var crop: Crop = world.farming.get_crop(cell)
		var item: ItemDefinition = first_item(true, row.id)
		if item != null and String(item.item_id) == String(job.item) and settings.owns(cell, crop) and String(crop.definition.crop_id) == String(job.crop) and crop.planted_at == float(job.planted_at) and world.farming.fertilizer_error(cell, actor).is_empty():
			var before: Array[Dictionary] = world.storages._snapshot(bag)
			if bag.remove(item.item_id, 1, false) == 1:
				success = world.farming.fertilize(cell, actor)
				if success:
					bag.changed.emit()
				else:
					bag.replace_slots(before, false)
	world.storages.busy = false
	return success
