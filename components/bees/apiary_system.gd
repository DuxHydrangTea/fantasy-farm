class_name ApiarySystem
extends Node
## Farm-scoped clock orchestration. Sweep bloom/deadline boundaries, including offline.
var farming: FarmingController
var world: FarmWorld
var clock: FarmClock
var definition: BeehiveDefinition = preload("res://resources/bees/beehive.tres")
var hives: Array[Beehive] = []
var gardens: Array[FlowerGarden] = []
var last_at: float = 0.0
var loading: bool = true
var _advancing: bool = false
var _placing: bool = false
var _boosted: Array[Crop] = []
var _weather_at: float = 0.0

func _ready() -> void:
	clock = farming.time_manager
	for node: Node in get_tree().get_nodes_in_group(&"flower_gardens"):
		if world.is_ancestor_of(node):
			var garden: FlowerGarden = node as FlowerGarden
			garden.apiary = self
			gardens.append(garden)
	last_at = clock.now()
	loading = false
	clock.tick.connect(advance)

func sync() -> void:
	if clock != null:
		advance(clock.now())

func _flowers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for garden: FlowerGarden in gardens:
		if garden.starter_content_locked:
			continue
		for pot: FlowerPot in garden.pots.values():
			if pot.definition != null and pot.growth_started_at >= 0:
				result.append({"type":String(pot.definition.flower_id),"name":pot.definition.display_name,"point":pot.global_position,"ready_at":pot.matures_at,"garden":String(garden.persistent_id),"cell":pot.cell})
	for cell: Vector2i in farming.crop_cells():
		var crop: Crop = farming.get_crop(cell)
		if crop != null and crop.definition.crop_id == &"sunflower":
			result.append({"type":"sunflower","name":"Sunflower","point":farming.farmland.to_global(farming.farmland.map_to_local(cell)),"ready_at":crop.matures_at})
	return result

func effective_radius(timestamp: float) -> float:
	return definition.radius * (farming.weather.radius_multiplier(timestamp) if farming.weather != null else 1.0)

func raining(timestamp: float) -> bool:
	return farming.weather != null and farming.weather.weather_at(timestamp) == WeatherManager.Weather.RAIN

func _assign(sources: Array[Dictionary], timestamp: float) -> void:
	_weather_at = timestamp
	for hive: Beehive in hives:
		hive.pollination.sources.clear()
	for source: Dictionary in sources:
		if raining(timestamp):
			break
		if float(source.ready_at) > timestamp + 0.000001:
			continue
		var nearest: Beehive
		var distance: float = INF
		for hive: Beehive in hives:
			if not hive.repaired:
				continue
			var fixed_slot: int = world.honey_garden.owner_slot(source.get("cell",Vector2i(-99,-99))) if world.honey_garden != null and world.honey_garden.migrated and source.get("garden", "") == String(world.honey_garden.garden().persistent_id) else -1
			if fixed_slot >= 0 or hive.garden_slot >= 0:
				if fixed_slot == hive.garden_slot and source.get("garden", "") == hive.garden_id:
					nearest = hive
					break
				continue
			var candidate: float = hive.global_position.distance_squared_to(source.point)
			if candidate <= effective_radius(timestamp)*effective_radius(timestamp) and (candidate < distance or (is_equal_approx(candidate,distance) and (nearest == null or String(hive.persistent_id) < String(nearest.persistent_id)))):
				nearest = hive
				distance = candidate
		if nearest != null:
			nearest.pollination.sources.append(source)
	for hive: Beehive in hives:
		hive.pollination.resolve(hive.global_position, definition, hive.production.legacy_batch)

func advance(timestamp: float) -> void:
	if loading or _advancing:
		return
	if world != null and world.honey_garden != null:
		world.honey_garden.prepare_waiting()
	if world != null and world.trees != null:
		world.trees.advance(timestamp)
	_advancing = true
	timestamp = maxf(timestamp,last_at)
	if hives.is_empty():
		last_at = timestamp
		_advancing = false
		return
	var cursor: float = last_at
	while cursor < timestamp - 0.000001:
		var sources: Array[Dictionary] = _flowers()
		_assign(sources,cursor)
		var boundary: float = minf(timestamp, farming.weather.next_boundary(cursor)) if farming.weather != null else timestamp
		for source: Dictionary in sources:
			if float(source.ready_at) > cursor + 0.000001:
				boundary = minf(boundary,float(source.ready_at))
		var accelerated: Array[Crop] = []
		for cell: Vector2i in farming.crop_cells():
			var crop: Crop = farming.get_crop(cell)
			if crop == null or crop.matures_at <= cursor + 0.000001:
				continue
			var point: Vector2 = farming.farmland.to_global(farming.farmland.map_to_local(cell))
			var boosted: bool = crop_is_pollinated(point)
			if boosted:
				accelerated.append(crop)
			var rate: float = 1.0 + definition.crop_bonus if boosted else 1.0
			# A planted crop can become a sunflower source midway through this interval.
			boundary = minf(boundary,cursor + (crop.matures_at-cursor)/rate)
		_update_boosted(accelerated,cursor)
		var elapsed: float = maxf(0.0,boundary-cursor)
		for hive: Beehive in hives:
			if hive.repaired:
				var windy: bool = farming.weather != null and farming.weather.weather_at(cursor) == WeatherManager.Weather.WINDY
				var speed: float = 1.25 if hive.garden_slot >= 0 and windy else 1.0
				var recipe: String = world.honey_garden.recipe_for(hive,sources,cursor) if hive.garden_slot >= 0 else "mixed"
				hive.production.advance(elapsed * speed, hive.pollination.source_id, recipe)
			hive.refresh_visual()
		for crop: Crop in accelerated:
			crop.pollination_reduction += elapsed * definition.crop_bonus
			crop.matures_at -= elapsed * definition.crop_bonus
		cursor = boundary
		last_at = cursor
		for crop: Crop in accelerated:
			crop.refresh(cursor)
		if elapsed <= 0.000001:
			break
	last_at = timestamp
	_assign(_flowers(),timestamp)
	for hive: Beehive in hives:
		hive.range_display.garden_grid = hive.garden_slot >= 0
		if hive.garden_slot >= 0:
			hive.range_display.garden_cell = HoneyGardenSystem.CENTERS[hive.garden_slot]
			hive.range_display.garden = world.honey_garden.garden()
		hive.range_display.radius = effective_radius(timestamp)
		hive.range_display.queue_redraw()
		hive.bees.set_sheltered(raining(timestamp) or not hive.repaired)
	_advancing = false

func _update_boosted(next: Array[Crop], timestamp: float) -> void:
	for crop: Crop in _boosted:
		if is_instance_valid(crop) and not crop.is_retiring() and not next.has(crop):
			crop.refresh(timestamp)
			farming.reschedule_crop(crop)
	for crop: Crop in next:
		if not _boosted.has(crop):
			farming.unschedule_crop(crop)
	_boosted = next

func crop_is_pollinated(point: Vector2) -> bool:
	for hive: Beehive in hives:
		if hive.pollination.active() and hive.global_position.distance_squared_to(point) <= effective_radius(_weather_at)*effective_radius(_weather_at):
			return true
	return false

func snap_position(point: Vector2) -> Vector2:
	return farming.farmland.to_global(farming.farmland.map_to_local(farming.world_to_cell(point)))

func placement_error(point: Vector2, columns: int = -1, restoring: bool = false, legacy_garden: bool = false) -> String:
	if not restoring and world.honey_garden != null and world.honey_garden.garden() != null and Rect2(Vector2.ZERO,FlowerGarden.SIZE).has_point(world.honey_garden.garden().to_local(point)):
		return "Use the three fixed garden hives."
	var cell: Vector2i = farming.world_to_cell(point)
	var count: int = columns if columns >= 0 else farming.land.unlocked_columns if farming.land != null else 48
	if not LandExpansionState.cell_is_open(cell,count):
		return "Unlock this land before placing a hive."
	var ground: TileMapLayer = farming.ground
	if ground == null or ground.get_cell_source_id(ground.local_to_map(ground.to_local(point))) < 0:
		return "Place the hive on solid ground."
	if not restoring and farming.cell_is_occupied(cell):
		return "This space is blocked."
	if not restoring and farming.get_crop(cell) != null:
		return "This plot already has a crop."
	for node: Node in world.get_children():
		if node is PondPen and (node as PondPen).is_water(point):
			return "Place the hive on solid ground."
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(15,15)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0,point)
	query.collision_mask = 1 if restoring else 7
	if restoring:
		var excluded: Array[RID] = []
		for hive: Beehive in hives:
			excluded.append(hive.get_rid())
		if legacy_garden and world.honey_garden != null and world.honey_garden.garden() != null and Rect2(Vector2.ZERO,FlowerGarden.SIZE).has_point(world.honey_garden.garden().to_local(point)):
			# Old garden flowers are relocated only after the complete layout plan passes.
			# They must not make a pending legacy save impossible to load first.
			for pot: FlowerPot in world.honey_garden.garden().pots.values():
				excluded.append(pot.get_rid())
		query.exclude = excluded
	if not world.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():
		return "This space is blocked."
	for hive: Beehive in hives:
		if not restoring and hive.global_position.distance_to(point) < 16:
			return "This space is blocked."
	return ""

func place(point: Vector2, player: FarmPlayer, slot: int) -> Dictionary:
	if _placing or loading or player == null or player.selection.is_menu_open() or player.state.current_state in [StateComponent.State.TOOL,StateComponent.State.WATER]:
		return {"ok":false,"error":"Hive placement is unavailable."}
	point = snap_position(point)
	var error: String = placement_error(point)
	if not error.is_empty():
		return {"ok":false,"error":error}
	if player.global_position.distance_to(point) > 96.0:
		return {"ok":false,"error":"Move closer to place the hive."}
	var bag: InventoryComponent = player.selection.inventory
	if slot != player.selection.selected_index or bag.slot(slot).item != definition.hive_item or bag.slot(slot).count < 1:
		return {"ok":false,"error":"Select a beehive from your bag."}
	_placing = true
	sync()
	var hive: Beehive = create_hive(point,StringName("hive_"+Crypto.new().generate_random_bytes(16).hex_encode()))
	bag.remove_from_slot(slot,1)
	advance(last_at)
	_placing = false
	player.state.navigation.invalidate_cache()
	return {"ok":true,"hive":hive}

func create_hive(point: Vector2, id: StringName) -> Beehive:
	var hive: Beehive = Beehive.new()
	hive.definition = definition
	hive.apiary = self
	hive.persistent_id = id
	world.add_child(hive)
	hive.global_position = point
	hives.append(hive)
	farming.set_cell_occupied(farming.world_to_cell(point),true)
	return hive

func begin_restore() -> void:
	loading = true
	for hive: Beehive in hives:
		farming.set_cell_occupied(farming.world_to_cell(hive.global_position),false)
		hive.free()
	hives.clear()
	_boosted.clear()

func restore(rows: Array, saved_at: float, now: float) -> void:
	for row: Dictionary in rows:
		var hive: Beehive = create_hive(world.to_global(Vector2(row.position[0],row.position[1])),StringName(row.id))
		hive.garden_id = row.get("garden_id", "")
		hive.garden_slot = int(row.get("garden_slot", -1))
		hive.repaired = row.get("repaired", true)
		hive.production.garden_mode = hive.garden_slot >= 0
		hive.production.batch_recipe = row.get("batch_recipe", "")
		hive.production.work = float(row.work)
		hive.production.contributions = row.contributions.duplicate()
		hive.production.legacy_batch = bool(row.legacy_batch)
		hive.production.ready_item = hive.production.expected_item() if row.ready_item != "" else null
		hive.refresh_visual()
	last_at = saved_at
	loading = false
	advance(maxf(saved_at,now))
