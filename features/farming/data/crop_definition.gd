class_name CropDefinition
extends Resource

@export var crop_id: StringName = &""
@export var display_name: String = ""
@export var stage_textures: Array[Texture2D] = []
@export_range(1, 365, 1) var growth_days: int = 4

@export_group("Harvest")
@export var harvest_item: ItemDefinition
@export var harvest_amount: int = 10

@export_group("Planting")
@export var seed_item: ItemDefinition

func is_valid() -> bool:
	if crop_id == &"" or display_name == "":
		return false

	if harvest_item == null or not harvest_item.is_valid():
		return false
	
	if harvest_amount <= 0 or growth_days <= 0:
		return false
	
	if seed_item == null or not seed_item.is_valid():
		return false
	
	if stage_textures.size() != 4:
		return false
	
	for texture: Texture2D in stage_textures:
		if texture == null:
			return false
	
	return true
