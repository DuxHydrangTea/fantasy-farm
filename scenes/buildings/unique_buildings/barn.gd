@tool
extends StaticBody2D

@export var appearance_override: Texture2D:
	set(value):
		appearance_override = value
		_update_sprite()

enum Variant {
	BASE_BLACK,
	BASE_BLUE,
	BASE_RED,
	GREEN_BLACK,
	GREEN_BLUE,
	GREEN_RED,
	RED_BLACK,
	RED_BLUE,
	RED_RED,
}

const VARIANTS = {
	Variant.BASE_BLACK: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Base_Black.png"), "frame": 0},
	Variant.BASE_BLUE: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Base_Blue.png"), "frame": 0},
	Variant.BASE_RED: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Base_Red.png"), "frame": 0},
	Variant.GREEN_BLACK: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Green_Black.png"), "frame": 0},
	Variant.GREEN_BLUE: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Green_Blue.png"), "frame": 0},
	Variant.GREEN_RED: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Green_Red.png"), "frame": 0},
	Variant.RED_BLACK: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Red_Black.png"), "frame": 0},
	Variant.RED_BLUE: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Red_Blue.png"), "frame": 0},
	Variant.RED_RED: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Barn/Barn_Red_Red.png"), "frame": 0},
}

@export var variant: Variant = Variant.BASE_BLACK:
	set(value):
		variant = value
		_update_sprite()


func _ready() -> void:
	_update_sprite()


func _update_sprite() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		if appearance_override != null:
			sprite.frame = 0
			sprite.texture = appearance_override
		else:
			sprite.texture = VARIANTS[variant]["texture"]
			sprite.frame = VARIANTS[variant]["frame"]
