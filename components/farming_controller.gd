class_name FarmingController
extends Node
@export var ground: TileMapLayer

const CROP_SCENE: PackedScene = preload("res://scenes/crops/crop.tscn")

signal soil_changed(cell: Vector2i, previous: int, current: int)
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
var _crops: Dictionary[Vector2i, Crop] = {}
var _growth: GrowthSchedule = GrowthSchedule.new()
var _harvesting: bool = false

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
	if inventory == null or time_manager == null or not can_plant(cell, actor):
		return false
	var stack: Dictionary = inventory.slot(slot_index)
	var seed: ItemDefinition = stack.item as ItemDefinition
	if seed == null or stack.count < 1 or seed.item_type != ItemDefinition.ItemType.SEED:
		return false
	var definition: CropDefinition = seed.crop as CropDefinition
	if definition == null or not definition.is_valid():
		return false
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
	return true

func can_harvest(cell: Vector2i) -> bool:
	var crop: Crop = get_crop(cell)
	if crop == null or time_manager == null:
		return false
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
	_harvesting = false
	return true

func _refresh_crops(timestamp: float) -> void:
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

func crop_cells() -> Array[Vector2i]:
	return _crops.keys()

func capture_soil() -> Array[Dictionary]:
	var cells: Dictionary[Vector2i, bool] = {}
	for layer: TileMapLayer in [dry_soil, wet_soil]:
		for point: Vector2i in layer.get_used_cells():
			cells[world_to_cell(layer.to_global(layer.map_to_local(point)))] = true
	var result: Array[Dictionary] = []
	for cell: Vector2i in cells.keys():
		var state: int = get_soil_state(cell)
		if state != Soil.UNTILLED:
			result.append({"cell": [cell.x, cell.y], "state": state})
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
	var dry: Array[Vector2i] = []
	var wet: Array[Vector2i] = []
	for record: Dictionary in records:
		var cell: Vector2i = Vector2i(int(record.cell[0]), int(record.cell[1]))
		dry.append(_layer_cell(dry_soil, cell))
		if int(record.state) == Soil.WET:
			wet.append(_layer_cell(wet_soil, cell))
	if not dry.is_empty():
		dry_soil.set_cells_terrain_connect(dry, dry_terrain_set, dry_terrain, false)
	if not wet.is_empty():
		wet_soil.set_cells_terrain_connect(wet, wet_terrain_set, wet_terrain, false)

func restore_crop(cell: Vector2i, definition: CropDefinition, planted: float, deadline: float, progress: float, now: float) -> void:
	var crop: Crop = CROP_SCENE.instantiate() as Crop
	crop.time_manager = time_manager
	get_parent().add_child(crop)
	var center: Vector2 = farmland.map_to_local(cell) + Vector2(0, farmland.tile_set.tile_size.y * 0.5)
	crop.global_transform = farmland.global_transform * Transform2D(0.0, center)
	crop.restore_progress(definition, planted, deadline, progress, now)
	_schedule_crop(crop)
	_crops[cell] = crop

func set_cell_occupied(cell: Vector2i, occupied: bool) -> void:
	if occupied:
		_occupied[cell] = true
	else:
		_occupied.erase(cell)

func till(cell: Vector2i, actor: PhysicsBody2D = null) -> bool:
	if not _valid_terrain(dry_soil, dry_terrain_set, dry_terrain) or not can_till(cell, actor):
		return false
	dry_soil.set_cells_terrain_connect([_layer_cell(dry_soil, cell)], dry_terrain_set, dry_terrain, false)
	if get_soil_state(cell) != Soil.DRY:
		return false
	soil_changed.emit(cell, Soil.UNTILLED, Soil.DRY)
	return true

func water(cell: Vector2i, actor: PhysicsBody2D = null) -> bool:
	if not _valid_terrain(wet_soil, wet_terrain_set, wet_terrain) or not can_water(cell, actor):
		return false
	# Keep the continuous tilled bed below wet patches, avoiding gaps at dry/wet seams.
	wet_soil.set_cells_terrain_connect([_layer_cell(wet_soil, cell)], wet_terrain_set, wet_terrain, false)
	if get_soil_state(cell) != Soil.WET:
		return false
	var crop: Crop = get_crop(cell)
	if crop != null:
		crop.react(4.0)
	soil_changed.emit(cell, Soil.DRY, Soil.WET)
	return true

func _layer_cell(layer: TileMapLayer, cell: Vector2i) -> Vector2i:
	return layer.local_to_map(layer.to_local(farmland.to_global(farmland.map_to_local(cell))))

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
	if farmland == null or farmland.tile_set == null or _occupied.has(cell):
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
