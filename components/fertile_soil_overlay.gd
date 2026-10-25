class_name FertileSoilOverlay
extends Node2D
## One batched drawing node for every fertile tile, below actors and crops.
var world: FarmWorld
var _bright: bool = false

func _ready() -> void:
	z_index = -1
	world.land.state.changed.connect(queue_redraw)
	queue_redraw()

func _process(_delta: float) -> void:
	var item: ItemDefinition = world.player.selection.get_selected_item()
	var bright: bool = item != null and item.item_type == ItemDefinition.ItemType.SEED and item.crop is CropDefinition and not world.player.selection.is_menu_open()
	if bright != _bright:
		_bright = bright
		queue_redraw()
	global_transform = world.farming.farmland.global_transform

func _draw() -> void:
	var farm: FarmingController = world.farming
	if farm.farmland == null or farm.farmland.tile_set == null:
		return
	var size: Vector2 = Vector2(farm.farmland.tile_set.tile_size)
	var color: Color = Color(1.0,0.28,0.20,0.95 if _bright else 0.45)
	for y: int in range(LandExpansionState.REGION.position.y,LandExpansionState.REGION.end.y):
		for x: int in range(LandExpansionState.REGION.position.x,LandExpansionState.REGION.end.x):
			var cell: Vector2i = Vector2i(x,y)
			if farm.land.is_unlocked(cell) and farm.fertility.is_fertile(cell):
				var rect: Rect2 = Rect2(farm.farmland.map_to_local(cell)-size*0.5+Vector2.ONE,size-Vector2(2,2))
				draw_rect(rect,color,false,1.0)
				if _bright:
					draw_rect(rect,Color(color,0.10),true)
