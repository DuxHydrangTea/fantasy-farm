class_name CropDefinition
extends Resource

@export var crop_id: StringName
@export var stage_textures: Array[Texture2D] = []
@export_range(1.0, 86400.0) var growth_seconds: float = 1200.0
@export var harvest_item: ItemDefinition
@export_range(0, 99) var harvest_amount: int = 1

func is_valid() -> bool:
	if growth_seconds <= 0.0:
		return false
	
	if stage_textures.size() != 4:
		return false
		
	for texture in stage_textures:
		if texture == null:
			return false
			
	return true		
	
func has_valid_harvest() -> bool:
	if harvest_item == null:
		return false
	
	if harvest_item.item_type != ItemDefinition.ItemType.PRODUCE:
		return false
		
	if harvest_amount <= 0:
		return false
	
	return true
