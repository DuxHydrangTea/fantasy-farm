class_name CropVisual
extends Node2D

@export var crop_definition: CropDefinition
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	assert(crop_definition != null, "CropDefinition chưa được gán")
	assert(crop_definition.is_valid(), "CropDefinition không hợp lệ")
	set_stage(0)
	

func set_stage(stage: int = 0) -> void:
	assert(
		stage >= 0 and stage < crop_definition.stage_textures.size(),
		"Trạng thái của Crop không tồn tại"
	)
	sprite.texture = crop_definition.stage_textures[stage]
