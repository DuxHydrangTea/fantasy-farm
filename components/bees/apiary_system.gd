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
const Assignment = preload("res://components/bees/pollination_assignment.gd")
var _owner_signature: Array = []
var _owners: Dictionary = {}
var _flowers_dirty: bool = true
var _source_revision: int = 0
var _nearby_signature: Array = []
var _nearby: Array[Crop] = []
var _crop_points: Dictionary = {}
var _source_nodes: Array[Node2D] = []
var _source_cells: Array[Vector2i] = []
var _source_rows: Array[Dictionary] = []
var _assigned_sources: Array[Dictionary] = []
var _assigned_signature: Array = []
var _assigned_from: float = INF
var _assigned_until: float = -INF
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
	farming.crop_planted.connect(invalidate_sources)
	farming.crop_harvested.connect(invalidate_sources)

func sync() -> void:
	if clock != null:
		advance(clock.now())

func invalidate_sources(_cell: Vector2i = Vector2i.ZERO, _crop: Crop = null) -> void:
	_flowers_dirty = true
	_source_revision += 1

func _flowers() -> Array[Dictionary]:
	if not _flowers_dirty:
		for index: int in range(_source_nodes.size()):
			var node: Node2D = _source_nodes[index]
			if not is_instance_valid(node):
				_flowers_dirty = true
				return _flowers()
			var source: Dictionary = _source_rows[index]
			if node is Crop:
				source.ready_at = (node as Crop).matures_at
				source.point = farming.farmland.to_global(farming.farmland.map_to_local(_source_cells[index]))
			else:
				var pot: FlowerPot = node as FlowerPot
				source.ready_at = pot.matures_at
				source.point = pot.global_position
		return _source_rows
	_flowers_dirty = false
	_source_nodes.clear()
	_source_cells.clear()
	var result: Array[Dictionary] = []
	for garden: FlowerGarden in gardens:
		if garden.starter_content_locked:
			continue
		for pot: FlowerPot in garden.pots.values():
			if pot.definition != null and pot.growth_started_at >= 0:
				_source_nodes.append(pot)
				_source_cells.append(pot.cell)
				result.append({"type":String(pot.definition.flower_id),"name":pot.definition.display_name,"point":pot.global_position,"ready_at":pot.matures_at,"garden":String(garden.persistent_id),"cell":pot.cell})
	for cell: Vector2i in farming.crop_cells():
		var crop: Crop = farming.get_crop(cell)
		if crop != null and crop.definition.crop_id == &"sunflower":
			_source_nodes.append(crop)
			_source_cells.append(cell)
			result.append({"type":"sunflower","name":"Sunflower","point":farming.farmland.to_global(farming.farmland.map_to_local(cell)),"ready_at":crop.matures_at})
	_source_rows = result
	return result

func _nearby_crops(radius_squared: float) -> Array[Crop]:
	var points: Array[Vector2] = []
	for hive: Beehive in hives:
		points.append(hive.global_position)
	var signature: Array = [_source_revision, points, radius_squared, farming.farmland.global_transform]
	if signature == _nearby_signature:
		return _nearby
	_nearby_signature = signature
	_nearby.clear()
	_crop_points.clear()
	for cell: Vector2i in farming.crop_cells():
		var crop: Crop = farming.get_crop(cell)
		if crop == null:
			continue
		var point: Vector2 = farming.farmland.to_global(farming.farmland.map_to_local(cell))
		for origin: Vector2 in points:
			if origin.distance_squared_to(point) <= radius_squared:
				_nearby.append(crop)
				_crop_points[crop] = point
				break
	return _nearby

func effective_radius(timestamp: float) -> float:
	return definition.radius * (farming.weather.radius_multiplier(timestamp) if farming.weather != null else 1.0)

func raining(timestamp: float) -> bool:
	return farming.weather != null and farming.weather.weather_at(timestamp) == WeatherManager.Weather.RAIN

func _assign(sources: Array[Dictionary], timestamp: float) -> void:
	_weather_at = timestamp
	var rain: bool = raining(timestamp)
	var radius_squared: float = pow(effective_radius(timestamp), 2)
	var fixed_garden: FlowerGarden = world.honey_garden.garden() if world.honey_garden != null and world.honey_garden.migrated else null
	var geometry: Array[Dictionary] = []
	for hive: Beehive in hives:
		geometry.append({"id": String(hive.persistent_id), "point": hive.global_position, "repaired": hive.repaired, "slot": hive.garden_slot, "garden": hive.garden_id})
	var signature: Array = [geometry, radius_squared, String(fixed_garden.persistent_id) if fixed_garden != null else ""]
	var batches: Array = []
	for hive: Beehive in hives:
		batches.append(hive.production.legacy_batch)
	var assigned_signature: Array = [signature, rain, batches, definition.pollen_speed, definition.sunflower_speed, definition.floral_speed]
	if timestamp >= _assigned_from and timestamp < _assigned_until and sources == _assigned_sources and assigned_signature == _assigned_signature:
		return
	_assigned_from = timestamp
	_assigned_until = INF
	_assigned_sources = sources.duplicate(true)
	_assigned_signature = assigned_signature
	for source: Dictionary in sources:
		if float(source.ready_at) > timestamp + 0.000001:
			_assigned_until = minf(_assigned_until, float(source.ready_at) - 0.000001)
	for hive: Beehive in hives:
		hive.pollination.sources.clear()
	if signature != _owner_signature or _owners.size() > sources.size() * 2 + 16:
		_owner_signature = signature
		_owners.clear()
	for source: Dictionary in sources:
		if rain:
			break
		if float(source.ready_at) > timestamp + 0.000001:
			continue
		var garden: String = String(source.get("garden", ""))
		var cell: Vector2i = source.get("cell", Vector2i(-99, -99))
		var key: Array = [source.point, garden, cell]
		if not _owners.has(key):
			var fixed_slot: int = world.honey_garden.owner_slot(cell) if fixed_garden != null and garden == String(fixed_garden.persistent_id) else -1
			_owners[key] = Assignment.choose(source.point, garden, fixed_slot, geometry, radius_squared)
		var nearest: int = int(_owners[key])
		if nearest >= 0:
			hives[nearest].pollination.sources.append(source)
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
		var radius_squared: float = pow(effective_radius(cursor), 2)
		# Unboosted, distant crops cannot alter pollen. Sunflower bloom
		# boundaries are already in sources; other distant deadlines are no-ops.
		for crop: Crop in _nearby_crops(radius_squared):
			if not is_instance_valid(crop) or crop.matures_at <= cursor + 0.000001:
				continue
			var point: Vector2 = _crop_points[crop]
			var boosted: bool = _point_is_pollinated(point, radius_squared)
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
	var radius_squared: float = pow(effective_radius(_weather_at), 2)
	return _point_is_pollinated(point, radius_squared)

func _point_is_pollinated(point: Vector2, radius_squared: float) -> bool:
	for hive: Beehive in hives:
		if hive.pollination.active() and hive.global_position.distance_squared_to(point) <= radius_squared:
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
	invalidate_sources()
	_source_nodes.clear()
	_source_cells.clear()
	_source_rows.clear()
	_owners.clear()
	_owner_signature.clear()
	_assigned_sources.clear()
	_assigned_signature.clear()
	_assigned_from = INF
	_assigned_until = -INF
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
