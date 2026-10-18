extends Node2D

@export var farmable_ground_layer: TileMapLayer

func _ready() -> void:
	assert(farmable_ground_layer != null, "Farmable Ground Layer chưa được gán!")
	assert(farmable_ground_layer.tile_set != null, "Farm Ground Layer không hề có tile set!")

func is_tillable_ground(cell: Vector2i) -> bool:
	var tile_data: TileData = farmable_ground_layer.get_cell_tile_data(cell)
	if tile_data == null:
		return false
	
	if not tile_data.has_custom_data("can_till"):
		return false
		
	return bool(tile_data.get_custom_data("can_till"))
