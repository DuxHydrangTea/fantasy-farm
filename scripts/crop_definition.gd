class_name CropDefinition
extends Resource

@export var crop_id: StringName
@export var stage_textures: Array[Texture2D] = []
@export_range(1.0, 86400.0) var growth_seconds: float = 1200.0
