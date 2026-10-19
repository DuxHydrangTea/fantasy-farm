@tool
extends "res://components/animals/animal_pen.gd"
## Cardinal 16px routes derived from the actual painted water and static physics.
## Two graphs keep land-only birds out of water without blocking swimming birds.
@export var water_layer_path: NodePath = NodePath("../FarmLand")
@export var water_source: int = 1
@export var water_terrain: int = 1
var navigation_ready: bool = false
var _land: AStarGrid2D
var _amphibious: AStarGrid2D
var _water_layer: TileMapLayer
var _dry_points: Array[Vector2i] = []
var _navigation_frames: int = 2
const CELL: float = 16.0

func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_water_layer = get_node_or_null(water_layer_path) as TileMapLayer

func _physics_process(_delta: float) -> void:
	_navigation_frames -= 1
	if _navigation_frames <= 0:
		rebuild_navigation()
		set_physics_process(false)

func is_water(point: Vector2) -> bool:
	if _water_layer == null:
		_water_layer = get_node_or_null(water_layer_path) as TileMapLayer
	if _water_layer == null:
		return false
	var cell: Vector2i = _water_layer.local_to_map(_water_layer.to_local(point))
	var data: TileData = _water_layer.get_cell_tile_data(cell)
	return _water_layer.get_cell_source_id(cell) == water_source and data != null and data.terrain == water_terrain

func rebuild_after_load() -> void:
	navigation_ready = false
	_navigation_frames = 2
	set_physics_process(true)

func _grid() -> AStarGrid2D:
	var grid: AStarGrid2D = AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(ceili(bounds.size.x / CELL), ceili(bounds.size.y / CELL)))
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = bounds.position + Vector2(CELL, CELL) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	return grid

func rebuild_navigation() -> void:
	_land = _grid()
	_amphibious = _grid()
	_dry_points.clear()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(10, 6)
	for y: int in range(_land.region.size.y):
		for x: int in range(_land.region.size.x):
			var cell: Vector2i = Vector2i(x, y)
			var point: Vector2 = to_global(_land.get_point_position(cell))
			var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
			query.shape = shape
			query.transform = Transform2D(0, point + Vector2(0, -3))
			query.collision_mask = 1
			var blocked: bool = not contains_world(point, 10.0) or not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
			_amphibious.set_point_solid(cell, blocked)
			_land.set_point_solid(cell, blocked or is_water(point))
			if not blocked and not is_water(point):
				_dry_points.append(cell)
	navigation_ready = true

func _cell(point: Vector2) -> Vector2i:
	var local: Vector2 = (to_local(point) - bounds.position) / CELL
	return Vector2i(floori(local.x), floori(local.y))

func _nearest_cell(point: Vector2, grid: AStarGrid2D) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var distance: float = INF
	for y: int in range(grid.region.size.y):
		for x: int in range(grid.region.size.x):
			var cell: Vector2i = Vector2i(x, y)
			if grid.is_point_solid(cell):
				continue
			var candidate: float = to_global(grid.get_point_position(cell)).distance_squared_to(point)
			if candidate < distance:
				distance = candidate
				best = cell
	return best

func route(from: Vector2, to: Vector2, swimming: bool) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if not navigation_ready or not contains_world(to, 10) or (not swimming and is_water(to)):
		return result
	var grid: AStarGrid2D = _amphibious if swimming else _land
	var start: Vector2i = _cell(from)
	var finish: Vector2i = _cell(to)
	if not grid.region.has_point(start) or not grid.region.has_point(finish) or grid.is_point_solid(finish):
		return result
	if grid.is_point_solid(start):
		start = _nearest_cell(from, grid)
	if start.x < 0:
		return result
	var ids: Array[Vector2i] = grid.get_id_path(start, finish)
	for id: Vector2i in ids:
		result.append(to_global(grid.get_point_position(id)))
	if not result.is_empty():
		result.append(to)
	return result

func closest_land(point: Vector2) -> Vector2:
	if navigation_ready:
		var cell: Vector2i = _nearest_cell(point, _land)
		if cell.x >= 0:
			return to_global(_land.get_point_position(cell))
	# Startup/load fallback: known open shore below the top-left gate, away from
	# the fisherman house. Normal movement waits for physics-backed navigation.
	return to_global(Vector2(56, 56))

func land_route(from: Vector2) -> PackedVector2Array:
	var best: PackedVector2Array = PackedVector2Array()
	var distance: float = INF
	if not navigation_ready:
		return best
	for cell: Vector2i in _dry_points:
		var point: Vector2 = to_global(_land.get_point_position(cell))
		var candidate: float = from.distance_squared_to(point)
		if candidate >= distance:
			continue
		var path: PackedVector2Array = route(from, point, true)
		if not path.is_empty():
			best = path
			distance = candidate
	return best
