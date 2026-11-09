class_name PlayerAudioFeedback
extends Node
## Actual displacement, not input intent: blocked walking and teleports stay silent.
var player: FarmPlayer
var _previous: Vector2
var _distance: float = 0.0

func _ready() -> void:
	_previous = player.global_position
	player.selection.inventory_visibility_changed.connect(_inventory_visibility)

func _inventory_visibility(open: bool) -> void:
	Sound.play(&"ui_open" if open else &"ui_close")

func _physics_process(_delta: float) -> void:
	advance_position(player.global_position)

func advance_position(point: Vector2) -> void:
	var moved: float = _previous.distance_to(point)
	_previous = point
	if player.selection.is_menu_open() or player.state.current_state != StateComponent.State.WALK or moved > 48.0:
		_distance = 0.0
		return
	if moved < 0.01:
		return
	_distance += moved
	if _distance >= 18.0:
		_distance = fmod(_distance, 18.0)
		Sound.play(surface_event(point))

func surface_event(point: Vector2) -> StringName:
	var farm: FarmingController = player.farming_actions.get_farming_controller()
	if farm == null or farm.farmland == null:
		return &"footstep_grass"
	# The player's feet are on the active soil layer. It takes priority over any
	# pavement tile underneath, including transformed/overlapping road layers.
	if farm.get_soil_state(farm.world_to_cell(point)) != FarmingController.Soil.UNTILLED:
		return &"footstep_dirt"
	var soil: bool = false
	# Planting permissions are not materials: FieldBoundaries is a DIRT path.
	# Sample each layer in its own coordinates (layers need not share transforms).
	for node: Node in farm.get_parent().get_children():
		var layer: TileMapLayer = node as TileMapLayer
		if layer == null or layer.tile_set == null or not layer.is_visible_in_tree():
			continue
		var cell: Vector2i = layer.local_to_map(layer.to_local(point))
		var source_id: int = layer.get_cell_source_id(cell)
		if source_id < 0:
			continue
		# Brown FarmLand cells share Grass_Tiles_1 with outer grass. The authored
		# flag identifies that soil tile even after it has been tilled or watered.
		if layer == farm.farmland:
			var tile: TileData = layer.get_cell_tile_data(cell)
			if tile != null and tile.has_custom_data("can_till") and tile.get_custom_data("can_till") == true:
				soil = true
		var source: TileSetAtlasSource = layer.tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		var texture: String = source.texture.resource_path.get_file()
		if texture == "Pavement_Tiles.png":
			return &"footstep_stone"
		if texture in ["FarmLand_Tile.png", "FarmLand_Wet_Tile.png", "FarmLand_Tile_Squared.png", "Path_Decoration.png"]:
			soil = true
	return &"footstep_dirt" if soil else &"footstep_grass"
