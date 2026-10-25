class_name FarmingController
extends Node
@export var ground: TileMapLayer

const CROP_SCENE: PackedScene = preload("res://scenes/crops/crop.tscn")

signal soil_changed(cell: Vector2i, previous: int, current: int)
signal action_committed(condition: StringName, amount: int)
signal crop_planted(cell: Vector2i, crop: Node2D)
signal crop_harvested(cell: Vector2i)
signal harvest_yielded(item: ItemDefinition, amount: int, at: Vector2, inventory: InventoryComponent)

enum Soil { UNTILLED, DRY, WET }

@export var farmland: TileMapLayer
@export var dry_soil: TileMapLayer
@export var wet_soil: TileMapLayer
@export var dry_terrain_set: int = 0
@export var dry_terrain: int = 0
@export var wet_terrain_set: int = 0
@export var wet_terrain: int = 0
@export_flags_2d_physics var obstacle_mask: int = 1
@export var time_manager: FarmClock
var apiary: ApiarySystem
var weather: WeatherSchedule
const SOIL_MOISTURE_SECONDS: float = 21600.0
var _moisture: Dictionary[Vector2i, float] = {}
var land: LandExpansionState
var _crops: Dictionary[Vector2i, Crop] = {}
var _growth: GrowthSchedule = GrowthSchedule.new()
var _harvesting: bool = false
var _area_busy: bool = false

func has_planted_crops() -> bool:
	return not _crops.is_empty()

# Runtime occupation, for future crops/placed objects without a physics body.
var _occupied: Dictionary[Vector2i, bool] = {}

func _ready() -> void:
	add_to_group("farming_controller")
	if time_manager == null:
		time_manager = TimeManager
	if time_manager != null:
		time_manager.tick.connect(_refresh_crops)

func world_to_cell(world_position: Vector2) -> Vector2i:
	return farmland.local_to_map(farmland.to_local(world_position))

func get_soil_state(cell: Vector2i) -> Soil:
	if _has_terrain(wet_soil, cell, wet_terrain_set, wet_terrain):
		return Soil.WET
	if _has_terrain(dry_soil, cell, dry_terrain_set, dry_terrain):
		return Soil.DRY
	return Soil.UNTILLED

func can_till(cell: Vector2i, actor: PhysicsBody2D = null) -> bool:
	return _allowed(cell, &"can_till", actor) and get_soil_state(cell) == Soil.UNTILLED

func can_water(cell: Vector2i, actor: PhysicsBody2D = null) -> bool:
	return _allowed(cell, &"can_water", actor) and get_soil_state(cell) == Soil.DRY

func can_plant(cell: Vector2i, actor: PhysicsBody2D = null) -> bool:
	return get_crop(cell) == null and _allowed(cell, &"can_plant", actor) and get_soil_state(cell) != Soil.UNTILLED

func get_crop(cell: Vector2i) -> Crop:
	var crop: Crop = _crops.get(cell) as Crop
	return crop if is_instance_valid(crop) else null

func plant(cell: Vector2i, inventory: InventoryComponent, slot_index: int, actor: PhysicsBody2D = null) -> bool:
	if _area_busy or inventory == null or time_manager == null or not can_plant(cell, actor):
		return false
	var stack: Dictionary = inventory.slot(slot_index)
	var seed: ItemDefinition = stack.item as ItemDefinition
	if seed == null or stack.count < 1 or seed.item_type != ItemDefinition.ItemType.SEED:
		return false
	var definition: CropDefinition = seed.crop as CropDefinition
	if definition == null or not definition.is_valid():
		return false
	if apiary != null:
		apiary.sync()
	var crop: Crop = CROP_SCENE.instantiate() as Crop
	crop.time_manager = time_manager
	get_parent().add_child(crop)
	# The sprite frame is 16x32; anchor its bottom at the bottom of the soil cell.
	var center: Vector2 = farmland.map_to_local(cell) + Vector2(0, farmland.tile_set.tile_size.y * 0.5)
	crop.global_transform = farmland.global_transform * Transform2D(0.0, center)
	crop.configure(definition, time_manager.now())
	crop.play_sprout()
	_schedule_crop(crop)
	_crops[cell] = crop
	inventory.remove_from_slot(slot_index, 1)
	crop_planted.emit(cell, crop)
	action_committed.emit(&"plant", 1)
	return true

func can_harvest(cell: Vector2i) -> bool:
	var crop: Crop = get_crop(cell)
	if crop == null or time_manager == null or (land != null and not land.is_unlocked(cell)):
		return false
	if apiary != null:
		apiary.sync()
	crop.refresh(time_manager.now())
	return crop.is_mature() and crop.definition.has_valid_harvest()

# THỨ TỰ THU HOẠCH — phần bảo toàn dữ liệu, cần giữ dù thay hiệu ứng hay UI.
# 1) Xác nhận cây chín và túi đủ chỗ cho toàn bộ yield trước khi xóa cây.
# 2) Khóa _harvesting trước inventory.add, vì changed có thể gọi lại harvest ngay trong lệnh add.
# 3) Cộng đồ đúng một lần, gỡ cây khỏi dữ liệu/lịch lớn, rồi phát sự kiện cho phần hình ảnh.
# Nếu bỏ kiểm tra sức chứa, có thể mất cây khi chưa nhận đủ nông sản; nếu bỏ khóa, có thể nhân đôi.
# Cây mờ đi và icon bay về sau đó chỉ là trình bày, không được cộng thêm phần thưởng ở cuối hiệu ứng.
func harvest(cell: Vector2i, inventory: InventoryComponent) -> bool:
	if _harvesting or inventory == null or not can_harvest(cell):
		return false
	var crop: Crop = get_crop(cell)
	var produce: ItemDefinition = crop.definition.harvest_item as ItemDefinition
	if inventory.capacity_for(produce) < crop.definition.harvest_amount:
		inventory.report_capacity_blocked(produce, crop.definition.harvest_amount)
		return false
	var requested: int = crop.definition.harvest_amount
	var origin: Vector2 = farmland.to_global(farmland.map_to_local(cell))
	_harvesting = true
	var accepted: int = inventory.add(produce, requested)
	if accepted == 0:
		_harvesting = false
		return false
	_crops.erase(cell)
	_growth.cancel(crop)
	crop.retire_after_harvest()
	crop_harvested.emit(cell)
	harvest_yielded.emit(produce, accepted, origin, inventory)
	action_committed.emit(&"harvest", 1)
	_harvesting = false
	return true

func _refresh_crops(timestamp: float) -> void:
	if apiary != null:
		apiary.advance(timestamp)
	for crop: Crop in _growth.take_due(timestamp):
		crop.refresh(timestamp)
		_schedule_crop(crop)

# 4 hình tương ứng stage 0..3, nên các mốc chuyển là 1/3, 2/3 và 3/3 thời gian lớn.
# Deadline kế tiếp = planted_at + (stage + 1)/3 * tổng thời gian; sau mỗi mốc mới đặt lịch tiếp.
# Không cần chạy refresh trên mọi cây mỗi tick. Nếu đổi số stage, phải đổi cả công thức này
# và cách tính stage trong Crop.refresh, nếu không lịch và hình ảnh sẽ lệch nhau.
func _schedule_crop(crop: Crop) -> void:
	if not crop.is_mature():
		_growth.schedule(crop, crop.planted_at + float(crop.stage + 1) / 3.0 * (crop.matures_at - crop.planted_at))

func unschedule_crop(crop: Crop) -> void:
	_growth.cancel(crop)

func reschedule_crop(crop: Crop) -> void:
	_growth.cancel(crop)
	_schedule_crop(crop)

func crop_cells() -> Array[Vector2i]:
	return _crops.keys()

func capture_soil() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if farmland == null or farmland.tile_set == null:
		return result
	var wet_cells: Dictionary[Vector2i, bool] = {}
	if wet_soil != null and wet_soil.tile_set != null:
		for point: Vector2i in wet_soil.get_used_cells():
			var data: TileData = wet_soil.get_cell_tile_data(point)
			if data != null and data.terrain_set == wet_terrain_set and data.terrain == wet_terrain:
				var cell: Vector2i = world_to_cell(wet_soil.to_global(wet_soil.map_to_local(point)))
				if not wet_cells.has(cell):
					wet_cells[cell] = true
					result.append({"cell": [cell.x, cell.y], "state": Soil.WET, "moisture": _moisture.get(cell, SOIL_MOISTURE_SECONDS)})
	if dry_soil != null and dry_soil.tile_set != null:
		var dry_cells: Dictionary[Vector2i, bool] = {}
		for point: Vector2i in dry_soil.get_used_cells():
			var data: TileData = dry_soil.get_cell_tile_data(point)
			if data != null and data.terrain_set == dry_terrain_set and data.terrain == dry_terrain:
				var cell: Vector2i = world_to_cell(dry_soil.to_global(dry_soil.map_to_local(point)))
				if not wet_cells.has(cell) and not dry_cells.has(cell):
					dry_cells[cell] = true
					result.append({"cell": [cell.x, cell.y], "state": Soil.DRY, "moisture": 0.0})
	return result

func can_restore_soil() -> bool:
	return _valid_terrain(dry_soil, dry_terrain_set, dry_terrain) and _valid_terrain(wet_soil, wet_terrain_set, wet_terrain)

func restore_soil(records: Array) -> void:
	# Retiring visuals have already left the logical crop dictionary.
	for child: Node in get_parent().get_children():
		if child is Crop and child.is_retiring():
			child.free()
	_growth.clear()
	for crop: Crop in _crops.values():
		if is_instance_valid(crop):
			crop.free()
	_crops.clear()
	dry_soil.clear()
	wet_soil.clear()
	_moisture.clear()
	var dry: Array[Vector2i] = []
	var wet: Array[Vector2i] = []
	for record: Dictionary in records:
		var cell: Vector2i = Vector2i(int(record.cell[0]), int(record.cell[1]))
		dry.append(_layer_cell(dry_soil, cell))
		if int(record.state) == Soil.WET:
			_moisture[cell] = float(record.get("moisture", SOIL_MOISTURE_SECONDS))
			wet.append(_layer_cell(wet_soil, cell))
	if not dry.is_empty():
		dry_soil.set_cells_terrain_connect(dry, dry_terrain_set, dry_terrain, false)
	if not wet.is_empty():
		wet_soil.set_cells_terrain_connect(wet, wet_terrain_set, wet_terrain, false)

func restore_crop(cell: Vector2i, definition: CropDefinition, planted: float, deadline: float, progress: float, now: float, fertilized: bool = false, pollination_reduction: float = 0.0) -> void:
	var crop: Crop = CROP_SCENE.instantiate() as Crop
	crop.time_manager = time_manager
	get_parent().add_child(crop)
	var center: Vector2 = farmland.map_to_local(cell) + Vector2(0, farmland.tile_set.tile_size.y * 0.5)
	crop.global_transform = farmland.global_transform * Transform2D(0.0, center)
	crop.restore_progress(definition, planted, deadline, progress, now, fertilized, pollination_reduction)
	_schedule_crop(crop)
	_crops[cell] = crop

func cell_is_occupied(cell: Vector2i) -> bool:
	return _occupied.has(cell)

func set_cell_occupied(cell: Vector2i, occupied: bool) -> void:
	if occupied:
		_occupied[cell] = true
	else:
		_occupied.erase(cell)

func till(cell: Vector2i, actor: PhysicsBody2D = null) -> bool:
	if _area_busy or not _valid_terrain(dry_soil, dry_terrain_set, dry_terrain) or not can_till(cell, actor):
		return false
	dry_soil.set_cells_terrain_connect([_layer_cell(dry_soil, cell)], dry_terrain_set, dry_terrain, false)
	if get_soil_state(cell) != Soil.DRY:
		return false
	soil_changed.emit(cell, Soil.UNTILLED, Soil.DRY)
	action_committed.emit(&"till", 1)
	return true

func water(cell: Vector2i, actor: PhysicsBody2D = null) -> bool:
	if _area_busy:
		return false
	var farm_world: FarmWorld = get_parent() as FarmWorld
	if farm_world != null and farm_world.weather != null:
		farm_world.weather.advance(time_manager.now())
	if not _valid_terrain(wet_soil, wet_terrain_set, wet_terrain) or not can_water(cell, actor):
		return false
	# Keep the continuous tilled bed below wet patches, avoiding gaps at dry/wet seams.
	wet_soil.set_cells_terrain_connect([_layer_cell(wet_soil, cell)], wet_terrain_set, wet_terrain, false)
	if get_soil_state(cell) != Soil.WET:
		return false
	var crop: Crop = get_crop(cell)
	if crop != null:
		crop.react(4.0)
	_moisture[cell] = SOIL_MOISTURE_SECONDS
	soil_changed.emit(cell, Soil.DRY, Soil.WET)
	if crop != null:
		action_committed.emit(&"water_crop", 1)
	return true

func _layer_cell(layer: TileMapLayer, cell: Vector2i) -> Vector2i:
	return layer.local_to_map(layer.to_local(farmland.to_global(farmland.map_to_local(cell))))

func is_area_busy() -> bool:
	return _area_busy

func apply_area(action: StringName, targets: Array[Vector2i], inventory: InventoryComponent = null, slot: int = -1, seed: ItemDefinition = null, actor: PhysicsBody2D = null) -> Dictionary:
	var result: Dictionary = {"changed": 0, "seed_spent": 0}
	if _area_busy or targets.is_empty() or targets.size() > ToolUpgradeState.MAX_LEVEL * ToolUpgradeState.MAX_LEVEL or FarmingAreaPolicy.tool_for(action).is_empty() or time_manager == null:
		return result
	if (action == &"tool" and not _valid_terrain(dry_soil, dry_terrain_set, dry_terrain)) or (action == &"water" and not _valid_terrain(wet_soil, wet_terrain_set, wet_terrain)):
		return result
	if action == &"plant" and (inventory == null or seed == null or inventory.slot(slot).item != seed):
		return result
	_area_busy = true
	if action == &"water" and get_parent() is FarmWorld:
		(get_parent() as FarmWorld).weather.advance(time_manager.now())
	if action == &"plant" and apiary != null:
		apiary.sync()
	var selected: Array[Vector2i] = []
	var unique: Array[Vector2i] = []
	for cell: Vector2i in targets:
		if not unique.has(cell):
			unique.append(cell)
	for row: Dictionary in FarmingAreaPolicy.evaluate(self, action, unique, inventory, slot, actor):
		if row.ready and not selected.has(row.cell):
			selected.append(row.cell)
	if selected.is_empty():
		_area_busy = false
		return result
	var committed: Array[Vector2i] = []
	var crops: Array[Crop] = []
	var watered_crops: int = 0
	var timestamp: float = time_manager.now()
	if action == &"plant":
		# No observer sees spent seeds without the complete crop batch in the model.
		for cell: Vector2i in selected:
			var crop: Crop = CROP_SCENE.instantiate() as Crop
			crop.time_manager = time_manager
			get_parent().add_child(crop)
			var center: Vector2 = farmland.map_to_local(cell) + Vector2(0, farmland.tile_set.tile_size.y * 0.5)
			crop.global_transform = farmland.global_transform * Transform2D(0.0, center)
			crop.configure(seed.crop as CropDefinition, timestamp)
			_schedule_crop(crop)
			_crops[cell] = crop
			crop.play_sprout()
			crops.append(crop)
			committed.append(cell)
		result.seed_spent = inventory.remove_from_slot(slot, committed.size(), false)
	else:
		var layer: TileMapLayer = dry_soil if action == &"tool" else wet_soil
		var layer_cells: Array[Vector2i] = []
		for cell: Vector2i in selected:
			layer_cells.append(_layer_cell(layer, cell))
		layer.set_cells_terrain_connect(layer_cells, dry_terrain_set if action == &"tool" else wet_terrain_set, dry_terrain if action == &"tool" else wet_terrain, false)
		for cell: Vector2i in selected:
			if get_soil_state(cell) != (Soil.DRY if action == &"tool" else Soil.WET):
				continue
			committed.append(cell)
			if action == &"water":
				_moisture[cell] = SOIL_MOISTURE_SECONDS
				var crop: Crop = get_crop(cell)
				if crop != null:
					crop.react(4.0)
					watered_crops += 1
	result.changed = committed.size()
	if action == &"plant":
		inventory.changed.emit()
		for i: int in range(committed.size()):
			crop_planted.emit(committed[i], crops[i])
	elif not committed.is_empty():
		for cell: Vector2i in committed:
			soil_changed.emit(cell, Soil.UNTILLED if action == &"tool" else Soil.DRY, Soil.DRY if action == &"tool" else Soil.WET)
	if not committed.is_empty() and action != &"water":
		action_committed.emit(&"till" if action == &"tool" else &"plant", committed.size())
	if watered_crops > 0:
		action_committed.emit(&"water_crop", watered_crops)
	_area_busy = false
	return result

func _has_terrain(layer: TileMapLayer, cell: Vector2i, set_id: int, terrain_id: int) -> bool:
	if farmland == null or farmland.tile_set == null or layer == null or layer.tile_set == null:
		return false
	var data: TileData = layer.get_cell_tile_data(_layer_cell(layer, cell))
	return data != null and data.terrain_set == set_id and data.terrain == terrain_id

func _valid_terrain(layer: TileMapLayer, set_id: int, terrain_id: int) -> bool:
	return layer != null and layer.tile_set != null and set_id >= 0 and set_id < layer.tile_set.get_terrain_sets_count() and terrain_id >= 0 and terrain_id < layer.tile_set.get_terrains_count(set_id)

# Quyền can_till/can_water/can_plant là ba quyền độc lập; thiếu dữ liệu mặc định là không được.
# Kiểm tra thêm overlay có blocks_farming và vật cản physics để ô cỏ hợp lệ không cho trồng
# xuyên qua công trình/cây cối ở lớp khác. Nếu chỉ xét tile nền, có thể cuốc dưới nhà/hàng rào.
# query.exclude bỏ chính player khi kiểm tra, nếu không chân player cũng có thể chặn thao tác.
func _allowed(cell: Vector2i, permission: StringName, actor: PhysicsBody2D) -> bool:
	if farmland == null or farmland.tile_set == null or _occupied.has(cell) or (land != null and not land.is_unlocked(cell)):
		return false
	var data: TileData = farmland.get_cell_tile_data(cell)
	# Missing permission is deliberately denied; borders/unmarked grass stay protected.
	if data == null or not data.has_custom_data(permission) or data.get_custom_data(permission) != true:
		return false
	var center: Vector2 = farmland.to_global(farmland.map_to_local(cell))
	for child: Node in get_parent().get_children():
		var layer: TileMapLayer = child as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		var tile: TileData = layer.get_cell_tile_data(layer.local_to_map(layer.to_local(center)))
		if tile != null and tile.has_custom_data("blocks_farming") and tile.get_custom_data("blocks_farming") == true:
			return false
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(farmland.tile_set.tile_size) * 0.8
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(farmland.global_transform.x, farmland.global_transform.y, center)
	query.collision_mask = obstacle_mask
	query.collide_with_areas = false
	if actor != null:
		query.exclude = [actor.get_rid()]
	return farmland.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func fertilizer_error(cell: Vector2i, actor: PhysicsBody2D = null) -> String:
	var crop: Crop = get_crop(cell)
	if crop == null or time_manager == null:
		return "No crop to fertilize."
	if not _allowed(cell, &"can_plant", actor):
		return "This plot is unavailable."
	if apiary != null:
		apiary.sync()
	return crop.fertilizer_error(time_manager.now())

func fertilize(cell: Vector2i, actor: PhysicsBody2D = null) -> bool:
	if not fertilizer_error(cell, actor).is_empty():
		return false
	var crop: Crop = get_crop(cell)
	if not crop.apply_fertilizer(time_manager.now()):
		return false
	_schedule_crop(crop)
	return true

## Batch only already-open planting cells; rain never touches locked weeds/borders.
func rain_water() -> void:
	var dry: Array[Vector2i] = []
	var wet: Array[Vector2i] = []
	var changed: Array[Vector2i] = []
	for y: int in range(LandExpansionState.REGION.position.y, LandExpansionState.REGION.end.y):
		for x: int in range(LandExpansionState.REGION.position.x, LandExpansionState.REGION.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if land != null and not land.is_unlocked(cell):
				continue
			var tile: TileData = farmland.get_cell_tile_data(cell)
			if tile == null or not tile.get_custom_data("can_water"):
				continue
			if get_soil_state(cell) != Soil.WET:
				changed.append(cell)
			dry.append(_layer_cell(dry_soil, cell))
			wet.append(_layer_cell(wet_soil, cell))
			_moisture[cell] = SOIL_MOISTURE_SECONDS
	if not dry.is_empty():
		dry_soil.set_cells_terrain_connect(dry, dry_terrain_set, dry_terrain, false)
		wet_soil.set_cells_terrain_connect(wet, wet_terrain_set, wet_terrain, false)
	for cell: Vector2i in changed:
		soil_changed.emit(cell, Soil.DRY, Soil.WET)

func evaporate_soil(seconds: float) -> void:
	if seconds <= 0.0:
		return
	var expired: Array[Vector2i] = []
	for cell: Vector2i in _moisture.keys():
		_moisture[cell] = maxf(0.0, _moisture[cell] - seconds)
		if _moisture[cell] <= 0.0:
			expired.append(cell)
	for cell: Vector2i in expired:
		_moisture.erase(cell)
		wet_soil.erase_cell(_layer_cell(wet_soil, cell))
		soil_changed.emit(cell, Soil.WET, Soil.DRY)
	# Rebuild wet edges once, not for every dried tile.
	if not expired.is_empty():
		var remaining: Array[Vector2i] = wet_soil.get_used_cells()
		if not remaining.is_empty():
			wet_soil.set_cells_terrain_connect(remaining, wet_terrain_set, wet_terrain, false)
