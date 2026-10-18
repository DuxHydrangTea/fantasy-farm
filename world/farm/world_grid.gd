class_name WorldGrid
extends Node

signal crop_harvested(definition: CropDefinition)

@export var ground_layer: TileMapLayer
@export var decor_layer: TileMapLayer
@export var soil_layer: TileMapLayer
@export var wet_soil_layer: TileMapLayer
@export var crop_scene: PackedScene
@export var crops_root: Node2D
@export var day_manager: DayManager

const SOIL_TERRAIN_SET: int = 0
const DRY_SOIL_TERRAIN: int = 0
const WET_SOIL_TERRAIN: int = 0

var _tilled_cells: Dictionary[Vector2i, bool] = {}
var _watered_cells: Dictionary[Vector2i, bool] = {}
var _crops: Dictionary[Vector2i, CropDefinition] = {}
var _crop_visual: Dictionary[Vector2i, CropVisual] = {}
var _growth_days: Dictionary[Vector2i, int] = {}

func _ready() -> void:
	assert(ground_layer != null, "Chưa gán ground_layer!")
	assert(ground_layer.tile_set != null, "Nền cỏ chưa có!")
	assert(decor_layer != null, "Chưa gán decor_layer!")
	assert(decor_layer.tile_set != null, "Nền block tiling chưa có!")
	assert(soil_layer != null, "Chưa gán TilledSoil.")
	assert(soil_layer.tile_set != null, "TilledSoil thiếu TileSet.")
	assert(wet_soil_layer != null, "Chưa gán Tilled Wet Soil.")
	assert(wet_soil_layer.tile_set != null, "Tilled Wet Soil thiếu TileSet.")
	assert(crop_scene != null, "Chưa gán Crop Scene.")
	assert(crops_root != null, "Chưa gán Crops Root.")
	assert(day_manager != null, "Chưa gán DayManager.")
	day_manager.day_changed.connect(_on_day_changed)

func is_tillable_ground(cell: Vector2i) -> bool:
	var tile_data: TileData = ground_layer.get_cell_tile_data(cell)
	if tile_data == null:
		return false
		
	if not tile_data.has_custom_data("can_till"):
		return false
	
	return bool(tile_data.get_custom_data("can_till"))

func is_blocked_by_decor(cell: Vector2i) -> bool:
	var tile_data: TileData = decor_layer.get_cell_tile_data(cell)
	if tile_data == null:
		return false
	
	if not tile_data.has_custom_data("blocks_tilling"):
		return false
		
	return bool(tile_data.get_custom_data("blocks_tilling"))

func can_till(cell: Vector2i) -> bool:
	return (
		is_tillable_ground(cell) 
		and not is_blocked_by_decor(cell)
		and not _tilled_cells.has(cell)
	)

func till(cell: Vector2i) -> bool:
	if not can_till(cell):
		return false
	
	_tilled_cells[cell] = true
	soil_layer.set_cells_terrain_connect(
		[cell],
		SOIL_TERRAIN_SET, DRY_SOIL_TERRAIN, false
	)
	return true

func is_watered(cell: Vector2i) -> bool:
	return _watered_cells.has(cell)

func can_water(cell: Vector2i) -> bool:
	return (
		_tilled_cells.has(cell)
		and not is_watered(cell)
		and not is_blocked_by_decor(cell)
	)

func water(cell: Vector2i) -> bool:
	if not can_water(cell):
		return false
	
	_watered_cells[cell] = true
	wet_soil_layer.set_cells_terrain_connect(
		[cell],
		SOIL_TERRAIN_SET, WET_SOIL_TERRAIN, false
	)

	return true
	

func can_use_tool(action: StringName, cell: Vector2i) -> bool:
	action = resolve_action(action, cell)
	
	match action:
		&"harvest":
			return can_harvest(cell)
		&"tool":
			return can_till(cell)
		&"water":
			return can_water(cell)
		&"plant":
			return can_plant(cell)
		_:
			return false

func can_plant(cell: Vector2i) -> bool:
	return (
		_tilled_cells.has(cell)
		and not _crops.has(cell)
		and not is_blocked_by_decor(cell)
	)
	
func plant(cell: Vector2i, definition: CropDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
		
	if not can_plant(cell):
		return false
		
	var visual: CropVisual = crop_scene.instantiate() as CropVisual
	assert(visual != null, "Visual phải có kiểu CropVisual")
	visual.crop_definition = definition
	
	var local_base: Vector2 = soil_layer.map_to_local(cell)
	local_base.y += float(soil_layer.tile_set.tile_size.y) * 0.5
	visual.position = crops_root.to_local(soil_layer.to_global(local_base))
	
	_crops[cell] = definition
	_growth_days[cell] = 0
	_crop_visual[cell] = visual
	crops_root.add_child(visual)
	return true

func get_crop_stage(cell: Vector2i) -> int:
	var duration_days: int = _crops[cell].growth_days
	var progress: float = float(_growth_days[cell]) / float(duration_days)
	
	if progress >= 1.0:
		return 3
	return mini(floori(progress * 3.0), 2)

func can_harvest(cell: Vector2i) -> bool:
	if not _crops.has(cell):
		return false
	return _growth_days[cell] >= _crops[cell].growth_days
	
func harvest(cell: Vector2i) -> bool:
	if not can_harvest(cell):
		return false
	
	var definition: CropDefinition = _crops[cell]
	_crop_visual[cell].queue_free()
	_crop_visual.erase(cell)
	_crops.erase(cell)
	_growth_days.erase(cell)
	
	crop_harvested.emit(definition)
	return true

func resolve_action(selected_action: StringName, cell: Vector2i) -> StringName:
	if can_harvest(cell):
		return &"harvest"

	return selected_action

func _on_day_changed(_current_day: int) -> void:
	for cell: Vector2i in _crops:
		if not is_watered(cell) or can_harvest(cell):
			continue
		_growth_days[cell] += 1
		_crop_visual[cell].set_stage(get_crop_stage(cell))
	
	_watered_cells.clear()
	wet_soil_layer.clear()
