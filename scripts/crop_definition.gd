class_name CropDefinition
extends Resource

@export var crop_id: StringName
@export var stage_textures: Array[Texture2D] = []
@export_range(1.0, 86400.0) var growth_seconds: float = 1200.0

func is_valid() -> bool:
	if growth_seconds <= 0.0:
		return false
	
	if stage_textures.size() != 4:
		return false
		
	for texture in stage_textures:
		if texture == null:
			return false
			
	return true		
