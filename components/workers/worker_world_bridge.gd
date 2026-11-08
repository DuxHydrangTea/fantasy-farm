class_name WorkerWorldBridge
extends RefCounted
## Scene/API boundary; scheduling policy and persisted tasks contain only primitives.
const STROLL_ATTEMPTS: int = 2
const STROLL_MIN_DISTANCE: float = 48.0
const STROLL_MAX_DISTANCE: float = 128.0
const CROP_CACHE_LIFETIME: float = 5.0
const ANIMAL_MEDICINE: ItemDefinition = preload("res://items/boosters/animal_medicine.tres")
const PESTICIDE: ItemDefinition = preload("res://items/boosters/pesticide.tres")
const HERBICIDE: ItemDefinition = preload("res://items/boosters/herbicide.tres")
const HealingEffect = preload("res://components/animals/animal_healing_effect.gd")
const CareBubble = preload("res://components/animals/animal_care_bubble.gd")
var present_care_effects: bool = true
var crop_care_waiting: bool = false
var world: FarmWorld
var storage_waiting: Dictionary = {}
var _animals_by_id: Dictionary[String, WeakRef] = {}
var _pen_cache: Dictionary = {}
var _trough_point_cache: Dictionary = {}
var _cached_crop_cells: Array[Vector2i] = []
var _crop_cache_time: float = 0.0
var _crop_cells_dirty: bool = true
var _trough_cache_revision: int = -1
var trough_physics_queries: int = 0
var _ranch_demands: Array[Dictionary] = []
var _sick_animals: Array[WeakRef] = []
var _ranch_missing: bool = false
var _ranch_dirty: bool = true
var _ranch_inventory: InventoryComponent
var _wake_at: float = -INF
var _wake_value: float = INF
var _wake_inventory: InventoryComponent
var stroll_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(scene: FarmWorld) -> void:
	world = scene
	stroll_rng.randomize()

func pens() -> Array[AnimalPen]:
	var result: Array[AnimalPen] = []
	for node: Node in world.get_children():
		if node is AnimalPen:
			result.append(node as AnimalPen)
	return result

func pen_for(id: String) -> AnimalPen:
	var cached_ref: WeakRef = _pen_cache.get(id) as WeakRef
	var cached: AnimalPen = cached_ref.get_ref() as AnimalPen if cached_ref != null else null
	if is_instance_valid(cached) and cached.get_parent() == world and String(cached.persistent_id) == id:
		return cached
	for pen: AnimalPen in pens():
		if String(pen.persistent_id) == id:
			_pen_cache[id] = weakref(pen)
			return pen
	return null

func home(role: String, zone: String = "") -> Vector2:
	if role == "ranch":
		var pen: AnimalPen = pen_for(zone)
		if pen != null:
			var point: Vector2 = pen.to_global(pen.allowed_bounds(20).position + Vector2(20, 20))
			return (pen as PondPen).closest_land(point) if pen is PondPen else point
	var cell: Vector2i = TreePlantation.FRUIT_REGION.position + Vector2i(1, 4) if role == "orchard" else LandExpansionState.block_rect(0).position + Vector2i.ONE
	return world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell))

func zone_contains(row: Dictionary, point: Vector2, columns: int = -1) -> bool:
	# One worker type works everywhere: farm, plantation and pens. Kept as a
	# hook so save preflight and target checks share a single call site.
	return true

func sync(timestamp: float, offline: bool = true) -> void:
	invalidate_ranch()
	world.weather.advance(timestamp, not offline)
	# Refreshing crops advances pollination, which advances the plantation too.
	# Repeating those calls rebuilds the same flower assignments at this instant.
	world.farming._refresh_crops(timestamp)
	if offline:
		for pen: AnimalPen in pens():
			pen.advance_offline(timestamp, true)

func invalidate_crops() -> void:
	_crop_cells_dirty = true
	_wake_at = -INF

func invalidate_ranch() -> void:
	_ranch_dirty = true
	_wake_at = -INF

func _task(kind: String, id: String, point: Vector2, priority: int) -> Dictionary:
	return {"kind": kind, "id": id, "point": WorkerRole.pair(point), "priority": priority}

func _trough_point(row: Dictionary, pen: AnimalPen, trough: AnimalTrough) -> Variant:
	var actor: WorkerActor = world.workers.actor_for(String(row.id))
	if actor == null or actor.collision == null or actor.collision.shape == null:
		return null
	var revision: int = world.workers.navigation.geometry_revision
	if revision != _trough_cache_revision:
		_trough_point_cache.clear()
		_trough_cache_revision = revision
	var key: String = str([trough.get_instance_id(), trough.global_transform, actor.collision.shape.get_rect(), actor.collision.transform, actor.global_scale, actor.collision_mask])
	if not _trough_point_cache.has(key):
		var points: Array[Vector2] = []
		for offset: Vector2 in trough.access_offsets:
			var point: Vector2 = trough.to_global(offset)
			if not pen.contains_world(point, 6) or (pen is PondPen and (pen as PondPen).is_water(point)):
				continue
			trough_physics_queries += 1
			if _stroll_clear(point, actor):
				points.append(point)
		# Cache failed access too; a geometry revision makes it eligible again.
		_trough_point_cache[key] = points
	var best: Variant = null
	var distance: float = INF
	for point: Vector2 in _trough_point_cache[key]:
		var next_distance: float = actor.global_position.distance_squared_to(point)
		if next_distance < distance:
			best = point
			distance = next_distance
	return best

func candidates(row: Dictionary, feed_inventory: InventoryComponent) -> Array[Dictionary]:
	var output_inventory: InventoryComponent = world.workers.output_inventory()
	# No inventory writes occur during this query. Share the slot scan across
	# hundreds of trees/crops that yield the same item; discard it before commit.
	var capacities: Dictionary = {}
	storage_waiting[row.role] = false
	var tasks: Array[Dictionary] = []
	var held: Dictionary = world.workers.reservations(String(row.id))
	crop_care_waiting = false
	var missing: PackedStringArray = []
	world.workers.waiting_reasons.erase(String(row.id))
	
	# Cache crop cells to reduce repeated farming.crop_cells() calls
	var now: float = world.farming.time_manager.now()
	if _crop_cells_dirty or now - _crop_cache_time > CROP_CACHE_LIFETIME:
		_cached_crop_cells = world.farming.crop_cells()
		_crop_cache_time = now
		_crop_cells_dirty = false
	
	for tree: PerennialTree in world.trees.trees.values():
		if tree is FruitTree and not tree.removed and (tree as FruitTree).has_fruit():
			if _capacity(output_inventory, (tree as FruitTree).harvest_item(), capacities) < (tree as FruitTree).harvest_amount():
				storage_waiting[row.role] = true
				continue
			var task: Dictionary = _task("fruit", "%d_%d" % [tree.cell.x, tree.cell.y], tree.global_position + Vector2(0, 12), 0)
			task["cell"] = [tree.cell.x, tree.cell.y]
			tasks.append(task)
	# The event already synchronized growth. Only fertilizer eligibility
	# needs an extra sync after a same-event harvest/plant mutation.
	var fertilizer_item: ItemDefinition = world.workers.crop_policy.first_item(true, row.id) if world.workers.crop_automation.auto_fertilize else null
	var pesticide_available: bool = feed_inventory.count_item(PESTICIDE.item_id) > int(held.items.get(String(PESTICIDE.item_id), 0))
	var herbicide_available: bool = feed_inventory.count_item(HERBICIDE.item_id) > int(held.items.get(String(HERBICIDE.item_id), 0))
	if fertilizer_item != null:
		world.apiary.sync()
	for cell: Vector2i in _cached_crop_cells:
		var crop: Crop = world.farming.get_crop(cell)
		if crop == null or not world.land.state.is_unlocked(cell) or held.cells.has(cell):
			continue
		if crop.conditions.weeds and feed_inventory.count_item(HERBICIDE.item_id) == 0 and not missing.has("No herbicide in supply storage. Buy it at the seed shop, Supplies tab."):
			missing.append("No herbicide in supply storage. Buy it at the seed shop, Supplies tab.")
		if crop.conditions.pests and feed_inventory.count_item(PESTICIDE.item_id) == 0 and not missing.has("No pesticide in supply storage. Buy it at the seed shop, Supplies tab."):
			missing.append("No pesticide in supply storage. Buy it at the seed shop, Supplies tab.")
		if (crop.conditions.pests and pesticide_available) or (crop.conditions.weeds and herbicide_available):
			var pests: bool = crop.conditions.pests and pesticide_available
			var care: Dictionary = _task("treat_pests" if pests else "treat_weeds", "%d_%d" % [cell.x, cell.y], world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell)), 0)
			care["cell"] = [cell.x, cell.y]
			care["item"] = String(PESTICIDE.item_id if pests else HERBICIDE.item_id)
			care["crop"] = String(crop.definition.crop_id)
			care["planted_at"] = crop.planted_at
			tasks.append(care)
			continue
		var kind: String = ""
		if crop.is_mature() and crop.conditions.affected() and world.workers.crop_automation.wait_for_care:
			crop_care_waiting = true
			continue
		if crop.is_mature():
			if _capacity(output_inventory, crop.definition.harvest_item, capacities, crop.harvest_tier()) >= world.farming.harvest_amount(cell):
				kind = "harvest"
			else:
				storage_waiting[row.role] = true
		elif not crop.is_mature() and world.farming.can_water(cell):
			kind = "water_crop"
		if not kind.is_empty():
			var task: Dictionary = _task(kind, "%d_%d" % [cell.x, cell.y], world.farming.farmland.to_global(world.farming.farmland.map_to_local(cell)), 0 if kind == "harvest" else 1)
			task["cell"] = [cell.x, cell.y]
			tasks.append(task)
		if fertilizer_item != null:
			var fertilizer: Dictionary = world.workers.crop_policy.fertilizer_task(cell, crop, fertilizer_item, false, row.id)
			if not fertilizer.is_empty():
				tasks.append(fertilizer)
	tasks.append_array(ranch_candidates(row, feed_inventory, held))
	if _ranch_missing:
		missing.append("No compatible feed in supply storage. Buy feed at the animal shop.")
	if not _sick_animals.is_empty() and feed_inventory.count_item(ANIMAL_MEDICINE.item_id) == 0:
		missing.append("No animal medicine in supply storage. Buy it at the animal shop.")
	if not missing.is_empty():
		world.workers.waiting_reasons[String(row.id)] = "\n".join(missing)
	for node: Node in world.get_tree().get_nodes_in_group(&"item_pickups"):
		var pile: ItemPickup = node as ItemPickup
		if pile == null or not world.is_ancestor_of(pile) or pile.is_queued_for_deletion() or pile.is_attracting() or pile.item == null or pile.item.item_type != ItemDefinition.ItemType.PRODUCE or pile.amount <= 0:
			continue
		if _capacity(output_inventory, pile.item, capacities) <= 0:
			storage_waiting[row.role] = true
			continue
		if pile.persistent_id.is_empty():
			pile.persistent_id = StringName("pile_" + Crypto.new().generate_random_bytes(12).hex_encode())
		tasks.append(_task("pickup", String(pile.persistent_id), pile.global_position, 3 if world.workers.crop_automation.auto_plant else 2))
	# Never search plots that cannot beat an available higher-priority job.
	for job: Dictionary in tasks:
		var cell_free: bool = not job.has("cell") or not held.cells.has(Vector2i(int(job.cell[0]), int(job.cell[1])))
		if int(job.priority) < 4 and cell_free and not held.targets.has(WorkerRole.target_key(job)) and float(world.workers.blocked_targets.get(String(row.id) + ":" + String(job.id), 0)) <= now:
			return tasks
	var opening: Dictionary = world.workers.crop_policy.planting_task(row)
	if not opening.is_empty():
		tasks.append(opening)
	return tasks

func ranch_candidates(row: Dictionary, feed_inventory: InventoryComponent, held: Dictionary = {}) -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	if held.is_empty():
		held = world.workers.reservations(String(row.id))
	if _ranch_dirty or _ranch_inventory != feed_inventory:
		_ranch_demands.clear()
		_sick_animals.clear()
		_ranch_missing = false
		_animals_by_id.clear()
		_ranch_inventory = feed_inventory
		for pen: AnimalPen in pens():
			for node: Node in pen.get_children():
				if node is AnimalActor:
					_animals_by_id[String((node as AnimalActor).persistent_id)] = weakref(node)
				if node is AnimalActor and not (node as AnimalActor).is_dead() and (node as AnimalActor).health.sick:
					_sick_animals.append(weakref(node))
				if node is AnimalTrough:
					var trough: AnimalTrough = node as AnimalTrough
					if trough.kind == AnimalTrough.Kind.FOOD and trough.stock == 0 and not trough.can_refill_to_full(feed_inventory):
						_ranch_missing = true
					var kind: String = "feed" if trough.can_refill_to_full(feed_inventory) else ""
					if kind.is_empty() and trough.kind == AnimalTrough.Kind.WATER and trough.stock <= trough.capacity - trough.water_per_use:
						kind = "water_trough"
					if not kind.is_empty():
						_ranch_demands.append({"trough": weakref(trough), "pen": weakref(pen), "kind": kind})
		_ranch_dirty = false
	if feed_inventory.count_item(ANIMAL_MEDICINE.item_id) > int(held.items.get(String(ANIMAL_MEDICINE.item_id), 0)):
		var worker: WorkerActor = world.workers.actor_for(String(row.id))
		if worker != null:
			for reference: WeakRef in _sick_animals:
				var animal: AnimalActor = reference.get_ref() as AnimalActor
				if not is_instance_valid(animal) or animal.is_queued_for_deletion() or animal.is_dead() or not animal.health.sick or held.targets.has("animal:" + String(animal.persistent_id)):
					continue
				var point: Vector2 = animal_access_point(worker, animal)
				if not point.is_finite():
					world.workers.waiting_reasons[String(row.id)] = "Cannot reach the sick animal. Clear a path to its pen."
					continue
				var care: Dictionary = _task("cure_animal", String(animal.persistent_id), point, 0)
				care["item"] = String(ANIMAL_MEDICINE.item_id)
				tasks.append(care)
	for demand: Dictionary in _ranch_demands:
		var trough: AnimalTrough = demand.trough.get_ref() as AnimalTrough
		var pen: AnimalPen = demand.pen.get_ref() as AnimalPen
		if not is_instance_valid(trough) or not is_instance_valid(pen):
			continue
		if held.targets.has("station:" + String(trough.persistent_id)):
			continue
		var kind: String = String(demand.kind)
		if kind == "water_trough" and int(row.water_units) == 0:
			kind = "fetch_water"
		var candidate: Variant = _trough_point(row, pen, trough)
		if candidate == null:
			continue
		var point: Vector2 = home("ranch", String(pen.persistent_id)) if kind == "fetch_water" else candidate as Vector2
		tasks.append(_task(kind, String(trough.persistent_id), point, 0 if trough.stock == 0 else 1))
	return tasks

func animal_for(id: String) -> AnimalActor:
	var ref: WeakRef = _animals_by_id.get(id) as WeakRef
	var animal: AnimalActor = ref.get_ref() as AnimalActor if ref != null else null
	if is_instance_valid(animal) and not animal.is_queued_for_deletion():
		return animal
	for pen: AnimalPen in pens():
		for child: Node in pen.get_children():
			if child is AnimalActor and String((child as AnimalActor).persistent_id) == id:
				_animals_by_id[id] = weakref(child)
				return child as AnimalActor
	return null

func animal_line_clear(worker: WorkerActor, animal: AnimalActor, point: Vector2) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(point, animal.global_position, 1, [worker.get_rid(), animal.get_rid()])
	return worker.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func animal_access_point(worker: WorkerActor, animal: AnimalActor) -> Vector2:
	var toward: Vector2 = (worker.global_position - animal.global_position).normalized()
	if toward.is_zero_approx():
		toward = Vector2.DOWN
	# Bounded local checks; never rebuild a world grid for each sick animal.
	for rotation: float in [0.0, PI * 0.5, -PI * 0.5, PI]:
		var point: Vector2 = animal.global_position + toward.rotated(rotation) * 24.0
		if _stroll_clear(point, worker) and animal_line_clear(worker, animal, point):
			return point
	return Vector2.INF

func refresh_animal_task(row: Dictionary, offline: bool) -> bool:
	var job: Dictionary = row.task
	var animal: AnimalActor = animal_for(String(job.id))
	var worker: WorkerActor = world.workers.actor_for(String(row.id))
	if animal == null or animal.is_dead() or not animal.health.sick or worker == null:
		return false
	var now: float = world.farming.time_manager.now()
	if not job.has("tracking_started_at"):
		job["tracking_started_at"] = now
	if now - float(job.tracking_started_at) > 45.0 and not offline:
		world.workers.blocked_targets[String(row.id) + ":" + String(job.id)] = now + 30.0
		world.workers.waiting_reasons[String(row.id)] = "Cannot reach the sick animal. Clear a path to its pen."
		return false
	if offline or WorkerRole.point(job.point).distance_to(animal.global_position) <= 32.0:
		return true
	var point: Vector2 = animal_access_point(worker, animal)
	if not point.is_finite():
		world.workers.blocked_targets[String(row.id) + ":" + String(job.id)] = now + 30.0
		return false
	job.point = WorkerRole.pair(point)
	job.base_point = job.point.duplicate()
	job.erase("arrived_at")
	job.work_at = now + worker.global_position.distance_to(point) / worker.movement.speed
	job.finish_at = float(job.work_at) + world.workers.task_duration(job, worker)
	return true

func _capacity(inventory: InventoryComponent, item: ItemDefinition, cache: Dictionary, tier: int = 0) -> int:
	if item == null:
		return 0
	var key: String = String(item.item_id) + ":" + str(tier)
	if not cache.has(key):
		cache[key] = inventory.capacity_for(item, tier)
	return int(cache[key])

func commit(row: Dictionary, _feed_inventory: InventoryComponent, task: Dictionary) -> bool:
	invalidate_ranch()
	if task.kind in ["treat_pests", "treat_weeds", "cure_animal"]:
		return _commit_care(row, task)
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
			# Legacy corner-waypoint cursor is kept for save compatibility only.
			# Free strolls use ID + position, and extra checkpoint scans may
			# interrupt idle walks. They must not mutate this unused cursor.
			return true
		"water_crop":
			var cell: Vector2i = Vector2i(int(task.cell[0]), int(task.cell[1]))
			return world.farming.apply_area(&"water", [cell], null, -1, null, world.workers.actor_for(row.id)).changed == 1
		"fetch_water":
			row.water_units = 30
			return true
		"feed", "water_trough":
			for pen: AnimalPen in pens():
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

func _commit_care(row: Dictionary, task: Dictionary) -> bool:
	if world.storages.busy or not world.workers.running(row):
		return false
	var bag: InventoryComponent = world.storages.inventory("farm_supply_storage")
	var item: ItemDefinition = ANIMAL_MEDICINE if task.kind == "cure_animal" else PESTICIDE if task.kind == "treat_pests" else HERBICIDE
	if String(task.get("item", "")) != String(item.item_id) or bag.count_item(item.item_id) < 1:
		return false
	var animal: AnimalActor
	var cell: Vector2i = Vector2i.ZERO
	if task.kind == "cure_animal":
		animal = animal_for(String(task.id))
		if animal == null or animal.is_dead() or not animal.health.sick or animal.global_position.distance_to(WorkerRole.point(row.position)) > 32.0:
			return false
		var worker: WorkerActor = world.workers.actor_for(String(row.id))
		if worker == null or not animal_line_clear(worker, animal, WorkerRole.point(row.position)):
			return false
	else:
		cell = Vector2i(int(task.cell[0]), int(task.cell[1]))
		var crop: Crop = world.farming.get_crop(cell)
		if crop == null or String(crop.definition.crop_id) != String(task.get("crop", "")) or crop.planted_at != float(task.get("planted_at", -1)) or not world.farming.care_error(cell, task.kind == "treat_pests").is_empty():
			return false
	world.storages.busy = true
	var snapshot: Array[Dictionary] = world.storages._snapshot(bag)
	var success: bool = false
	if bag.remove(item.item_id, 1, false) == 1:
		success = animal.cure_disease() if animal != null else world.farming.treat_crop(cell, task.kind == "treat_pests")
		if success:
			bag.changed.emit()
		else:
			bag.replace_slots(snapshot, false)
	world.storages.busy = false
	if success and animal != null and present_care_effects:
		animal.add_child(HealingEffect.new())
		animal.add_child(CareBubble.new())
	return success

func _commit_output(row: Dictionary, output_inventory: InventoryComponent, task: Dictionary) -> bool:
	match String(task.kind):
		"fruit":
			var tree: FruitTree = world.trees.trees.get(Vector2i(int(task.cell[0]), int(task.cell[1]))) as FruitTree
			return tree != null and tree.harvest(output_inventory)
		"harvest":
			var crop: Crop = world.farming.get_crop(Vector2i(int(task.cell[0]), int(task.cell[1])))
			if crop != null and crop.conditions.affected() and world.workers.crop_automation.wait_for_care:
				return false
			return world.farming.harvest(Vector2i(int(task.cell[0]), int(task.cell[1])), output_inventory)
		"pickup":
			for node: Node in world.get_tree().get_nodes_in_group(&"item_pickups"):
				var pile: ItemPickup = node as ItemPickup
				if pile != null and not pile.is_queued_for_deletion() and pile.amount > 0 and world.is_ancestor_of(pile) and String(pile.persistent_id) == task.id and not pile.is_attracting() and zone_contains(row, pile.global_position):
					return pile.item != null and world.storages.definition("produce_warehouse").accepts(pile.item) and pile.collect(output_inventory) > 0
	return false

func next_wake(row: Dictionary, feed_inventory: InventoryComponent, now: float) -> float:
	if _wake_at == now and _wake_inventory == feed_inventory:
		return _wake_value
	var next: float = world.weather.schedule.dawn_at(world.weather.schedule.day_at(now) + 1)
	var capacities: Dictionary = {}
	var inventory: InventoryComponent = world.workers.output_inventory()
	for tree: PerennialTree in world.trees.trees.values():
		if tree is FruitTree and tree.growth_started_at >= 0 and _capacity(inventory, (tree as FruitTree).harvest_item(), capacities) >= (tree as FruitTree).harvest_amount():
			var remaining: float = maxf(0, tree.matures_at - now) + maxf(0, tree.definition.fruit_cycle_seconds - (tree as FruitTree).fruit_work) * 0.75
			if remaining > 0.01:
				next = minf(next, now + remaining)
	var evaporation: float = world.weather.schedule.evaporation_rate(now)
	for cell: Vector2i in world.farming.crop_cells():
		var crop: Crop = world.farming.get_crop(cell)
		if crop.matures_at > now:
			next = minf(next, crop.matures_at)
		if world.farming._moisture.has(cell):
			next = minf(next, now + maxf(1, float(world.farming._moisture[cell]) / evaporation))
	next = minf(next, _ranch_boundary(row, feed_inventory, now))
	_wake_at = now
	_wake_inventory = feed_inventory
	_wake_value = maxf(now + 0.25, next)
	return _wake_value

func _ranch_boundary(_record: Dictionary, bag: InventoryComponent, now: float) -> float:
	var next: float = world.weather.schedule.next_boundary(now)
	for pen: AnimalPen in pens():
		next = minf(next, _ranch_pen_boundary(pen, bag, now))
	return next

func _ranch_pen_boundary(pen: AnimalPen, bag: InventoryComponent, now: float) -> float:
	var next: float = world.weather.schedule.next_boundary(now)
	var herd: Array[Dictionary] = []
	var supplies: Array[Dictionary] = []
	var stations: Dictionary = {}
	for child: Node in pen.get_children():
		if child is AnimalActor:
			var actor: AnimalActor = child as AnimalActor
			if actor.is_dead():
				continue
			if not actor.health.sick and actor.health.next_onset_at > now:
				next = minf(next, actor.health.next_onset_at)
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
		# refill_to_full can retain a partial package. Food therefore becomes
		# eligible at the first missing visible unit, including with no reserve.
		var units: int = trough.water_per_use if trough.kind == AnimalTrough.Kind.WATER else 1
		if trough.kind == AnimalTrough.Kind.WATER or trough.feed_reserve > 0 or (trough.feed_item != null and bag.count_item(trough.feed_item.item_id) > 0):
			next = minf(next, now + maxf(0.25, (float(supply.stock) - float(trough.capacity - units)) / rate))
	return next

## A short, swept-clear idle walk. No map-wide path search for idle wandering.
## The rng is re-seeded per call from worker id + position so the single-jump
## and stepwise simulations propose identical candidates from the same state,
## regardless of when the scan lands on the timeline.
func world_stroll_point(row: Dictionary, actor: WorkerActor) -> Vector2:
	if actor == null:
		return Vector2.INF
	var camera: Camera2D = world.player.camera
	var bounds: Rect2 = Rect2(float(camera.limit_left), float(camera.limit_top), float(camera.limit_right - camera.limit_left), float(camera.limit_bottom - camera.limit_top)).grow(-24.0)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return Vector2.INF
	var origin: Vector2 = WorkerRole.point(row.position)
	stroll_rng.seed = hash("%s|%.3f|%.3f" % [String(row.id), origin.x, origin.y])
	var now: float = world.farming.time_manager.now()
	for attempt: int in range(STROLL_ATTEMPTS):
		var center: Vector2 = Vector2(clampf(origin.x, bounds.position.x, bounds.end.x), clampf(origin.y, bounds.position.y, bounds.end.y))
		var angle: float = stroll_rng.randf_range(0.0, TAU)
		var point: Vector2 = center + Vector2.from_angle(angle) * stroll_rng.randf_range(STROLL_MIN_DISTANCE, STROLL_MAX_DISTANCE)
		point = Vector2(clampf(point.x, bounds.position.x, bounds.end.x), clampf(point.y, bounds.position.y, bounds.end.y))
		if actor.global_position.distance_to(point) < STROLL_MIN_DISTANCE:
			continue
		if float(world.workers.blocked_targets.get("%s:patrol:%d_%d" % [String(row.id), roundi(point.x), roundi(point.y)], 0.0)) > now:
			continue
		if not _stroll_clear(point, actor):
			continue
		# An idle walk must have a safe direct connection; work jobs can use A*.
		if not _stroll_segment_clear(point, actor):
			continue
		return point
	return Vector2.INF

func _stroll_clear(point: Vector2, actor: WorkerActor) -> bool:
	var shape: CollisionShape2D = actor.collision
	if shape == null or shape.shape == null:
		return true
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = shape.global_transform
	query.transform.origin += point - actor.global_position
	query.collision_mask = actor.collision_mask
	query.exclude = [actor.get_rid()]
	query.margin = 0.25
	return actor.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _stroll_segment_clear(point: Vector2, actor: WorkerActor) -> bool:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = actor.collision.shape
	query.transform = actor.collision.global_transform
	query.collision_mask = actor.collision_mask
	query.exclude = [actor.get_rid()]
	query.margin = 0.25
	query.motion = point - actor.global_position
	return actor.get_world_2d().direct_space_state.cast_motion(query)[0] >= 0.9999

func rest_seconds(row: Dictionary) -> float:
	var origin: Vector2 = WorkerRole.point(row.position)
	stroll_rng.seed = hash("%s|rest|%.3f|%.3f" % [String(row.id), origin.x, origin.y])
	return stroll_rng.randf_range(2.0, 3.0)

func patrol_point(row: Dictionary) -> Vector2:
	var stroll: Vector2 = world_stroll_point(row, world.workers.actor_for(String(row.id)))
	if stroll.is_finite():
		return stroll
	# A failed stroll search means rest here, never an unverified distant corner.
	return WorkerRole.point(row.position)
