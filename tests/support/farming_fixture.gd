extends RefCounted

const WORLD: PackedScene = preload("res://world/main_world.tscn")

static func create_field() -> Node2D:
	var world: Node = WORLD.instantiate()
	var field: Node2D = Node2D.new()
	# Keep every tile layer, including unfinished layers without a TileSet.
	for child: Node in world.get_children():
		if not child is TileMapLayer and child.name != &"FarmingController":
			continue
		child.owner = null
		world.remove_child(child)
		field.add_child(child)
	world.free()
	var farmland: TileMapLayer = field.get_node("FarmLand")
	farmland.tile_set = farmland.tile_set.duplicate(true)
	farmland.clear()
	field.get_node("DrySoil").clear()
	field.get_node("WetSoil").clear()
	var controller: Node = field.get_node("FarmingController")
	controller.farmland = farmland
	controller.dry_soil = field.get_node("DrySoil")
	controller.wet_soil = field.get_node("WetSoil")
	return field

static func mark_cell(field: Node2D, cell: Vector2i) -> void:
	var farmland: TileMapLayer = field.get_node("FarmLand")
	farmland.set_cell(cell, 0, Vector2i(1, 6))
