class_name TargetPreview
extends Node2D

@export var grid_layer: TileMapLayer
@export var feet_anchor: Marker2D
@export var facing_component: FacingComponent
@export var world_grid: WorldGrid

var target_cell: Vector2i = Vector2i.ZERO
var _tool_action: StringName = &"tool"
var _planting_available: bool = false

func _ready() -> void:
	assert(grid_layer != null, "Chưa gán lớp lưới")
	assert(grid_layer.tile_set != null, "Tile layer chưa có tile sett!")
	assert(feet_anchor != null, "Chưa gán Feet Anchor")
	assert(facing_component != null, "Chưa gán Facing Component")
	assert(world_grid != null, "Chưa gán World Grid")


func _process(_delta: float) -> void:
	target_cell = get_target_cell()
	var local_center: Vector2 = grid_layer.map_to_local(target_cell)
	global_position = grid_layer.to_global(local_center)
	var action: StringName = world_grid.resolve_action(_tool_action, target_cell)
	var allowed: bool = world_grid.can_use_tool(action, target_cell)
	
	if action == &"plant":
		allowed = allowed and _planting_available
	modulate = Color.LIME_GREEN if allowed else Color.RED
	
func get_target_cell() -> Vector2i:
	var local_feet: Vector2 = grid_layer.to_local(feet_anchor.global_position)
	var current_cell: Vector2i = grid_layer.local_to_map(local_feet)
	var facing_offset: Vector2i = Vector2i(facing_component.facing_direction)
	return current_cell + facing_offset
	
func _draw() -> void:
	if grid_layer == null or grid_layer.tile_set == null:
		return
	
	var size: Vector2 = Vector2(grid_layer.tile_set.tile_size)
	draw_rect(Rect2(-size * 0.5, size), Color.YELLOW, false, 1.0)

func set_tool_action(action: StringName) -> void:
	_tool_action = action

func set_planting_available(value: bool) -> void:
	_planting_available = value
