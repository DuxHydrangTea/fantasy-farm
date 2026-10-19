extends Node

const Crop = preload("res://components/crop.gd")
const CropDefinitionResource = preload("res://scripts/crop_definition.gd")
const Item = preload("res://scripts/item_definition.gd")
const Inventory = preload("res://components/inventory_component.gd")
const Clock = preload("res://components/time_manager.gd")
const CROP_SCENE: PackedScene = preload("res://scenes/crops/crop.tscn")

signal soil_changed(cell: Vector2i, previous: int, current: int)
signal crop_planted(cell: Vector2i, crop: Node2D)
signal crop_harvested(cell: Vector2i)

enum Soil { UNTILLED, DRY, WET }

@export var farmland: TileMapLayer
@export var dry_soil: TileMapLayer
@export var wet_soil: TileMapLayer
@export var dry_terrain_set: int = 0
@export var dry_terrain: int = 0
@export var wet_terrain_set: int = 0
@export var wet_terrain: int = 0
@export_flags_2d_physics var obstacle_mask: int = 1
@export var time_manager: Clock
var _crops: Dictionary[Vector2i, Crop] = {}

# Runtime occupation, for future crops/placed objects without a physics body.
var _occupied: Dictionary[Vector2i, bool] = {}

func _ready() -> void:
	add_to_group("farming_controller")
	if time_manager == null:
		time_manager = get_node_or_null("/root/TimeManager") as Clock
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

func plant(cell: Vector2i, inventory: Inventory, slot_index: int, actor: PhysicsBody2D = null) -> bool:
	if inventory == null or time_manager == null or not can_plant(cell, actor):
		return false
	var stack: Dictionary = inventory.slot(slot_index)
	var seed: Item = stack.item as Item
	if seed == null or stack.count < 1 or seed.item_type != Item.ItemType.SEED:
		return false
	var definition: CropDefinitionResource = seed.crop as CropDefinitionResource
	if definition == null or not definition.is_valid():
		return false
	var crop: Crop = CROP_SCENE.instantiate() as Crop
	get_parent().add_child(crop)
	# The sprite frame is 16x32; anchor its bottom at the bottom of the soil cell.
	var center: Vector2 = farmland.map_to_local(cell) + Vector2(0, farmland.tile_set.tile_size.y * 0.5)
	crop.global_transform = farmland.global_transform * Transform2D(0.0, center)
	crop.configure(definition, time_manager.now())
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

func harvest(cell: Vector2i, inventory: Inventory) -> bool:
	if inventory == null or not can_harvest(cell):
		return false
	var crop: Crop = get_crop(cell)
	var produce: Item = crop.definition.harvest_item as Item
	if inventory.capacity_for(produce) < crop.definition.harvest_amount:
		return false
	inventory.add(produce, crop.definition.harvest_amount)
	_crops.erase(cell)
	crop.queue_free()
	crop_harvested.emit(cell)
	return true

func _refresh_crops(timestamp: float) -> void:
	for crop: Crop in _crops.values():
		if is_instance_valid(crop) and not crop.is_mature():
			crop.refresh(timestamp)

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

func restore_crop(cell: Vector2i, definition: CropDefinitionResource, planted: float, deadline: float, progress: float, now: float) -> void:
	var crop: Crop = CROP_SCENE.instantiate() as Crop
	get_parent().add_child(crop)
	var center: Vector2 = farmland.map_to_local(cell) + Vector2(0, farmland.tile_set.tile_size.y * 0.5)
	crop.global_transform = farmland.global_transform * Transform2D(0.0, center)
	crop.restore_progress(definition, planted, deadline, progress, now)
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
