@tool
extends StaticBody2D

enum Variant {
	GREEN_FRAME_1,
	GREEN_FRAME_2,
	GREEN_FRAME_3,
	GREEN_FRAME_4,
	METAL_FRAME_1,
	METAL_FRAME_2,
	METAL_FRAME_3,
	METAL_FRAME_4,
	WOOD_FRAME_1,
	WOOD_FRAME_2,
	WOOD_FRAME_3,
	WOOD_FRAME_4,
}

const VARIANTS = {
	Variant.GREEN_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Green.png"), "frame": 0},
	Variant.GREEN_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Green.png"), "frame": 1},
	Variant.GREEN_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Green.png"), "frame": 2},
	Variant.GREEN_FRAME_4: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Green.png"), "frame": 3},
	Variant.METAL_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Metal.png"), "frame": 0},
	Variant.METAL_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Metal.png"), "frame": 1},
	Variant.METAL_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Metal.png"), "frame": 2},
	Variant.METAL_FRAME_4: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Metal.png"), "frame": 3},
	Variant.WOOD_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Wood.png"), "frame": 0},
	Variant.WOOD_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Wood.png"), "frame": 1},
	Variant.WOOD_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Wood.png"), "frame": 2},
	Variant.WOOD_FRAME_4: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Greenhouse/GreenHouse_Wood.png"), "frame": 3},
}

@export var variant: Variant = Variant.GREEN_FRAME_1:
	set(value):
		variant = value
		_update_sprite()


func _ready() -> void:
	_update_sprite()


func _update_sprite() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = VARIANTS[variant]["texture"]
		sprite.frame = VARIANTS[variant]["frame"]
