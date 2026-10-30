@tool
class_name CoopAppearance
extends StaticBody2D

@export var sprite: Sprite2D
@export var appearance_override: Texture2D:
	set(value):
		appearance_override = value
		_update_sprite()

enum Variant {
	BASE_BLACK_FRAME_1,
	BASE_BLACK_FRAME_2,
	BASE_BLACK_FRAME_3,
	BASE_BLUE_FRAME_1,
	BASE_BLUE_FRAME_2,
	BASE_BLUE_FRAME_3,
	BASE_RED_FRAME_1,
	BASE_RED_FRAME_2,
	BASE_RED_FRAME_3,
	GREEN_BLACK_FRAME_1,
	GREEN_BLACK_FRAME_2,
	GREEN_BLACK_FRAME_3,
	GREEN_BLUE_FRAME_1,
	GREEN_BLUE_FRAME_2,
	GREEN_BLUE_FRAME_3,
	GREEN_RED_FRAME_1,
	GREEN_RED_FRAME_2,
	GREEN_RED_FRAME_3,
	RED_BLACK_FRAME_1,
	RED_BLACK_FRAME_2,
	RED_BLACK_FRAME_3,
	RED_BLUE_FRAME_1,
	RED_BLUE_FRAME_2,
	RED_BLUE_FRAME_3,
	RED_RED_FRAME_1,
	RED_RED_FRAME_2,
	RED_RED_FRAME_3,
}

const VARIANTS = {
	Variant.BASE_BLACK_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Base_Black.png"), "frame": 0},
	Variant.BASE_BLACK_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Base_Black.png"), "frame": 1},
	Variant.BASE_BLACK_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Base_Black.png"), "frame": 2},
	Variant.BASE_BLUE_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Base_Blue.png"), "frame": 0},
	Variant.BASE_BLUE_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Base_Blue.png"), "frame": 1},
	Variant.BASE_BLUE_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Base_Blue.png"), "frame": 2},
	Variant.BASE_RED_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Base_Red.png"), "frame": 0},
	Variant.BASE_RED_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Base_Red.png"), "frame": 1},
	Variant.BASE_RED_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Base_Red.png"), "frame": 2},
	Variant.GREEN_BLACK_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Green_Black.png"), "frame": 0},
	Variant.GREEN_BLACK_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Green_Black.png"), "frame": 1},
	Variant.GREEN_BLACK_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Green_Black.png"), "frame": 2},
	Variant.GREEN_BLUE_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Green_Blue.png"), "frame": 0},
	Variant.GREEN_BLUE_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Green_Blue.png"), "frame": 1},
	Variant.GREEN_BLUE_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Green_Blue.png"), "frame": 2},
	Variant.GREEN_RED_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Green_Red.png"), "frame": 0},
	Variant.GREEN_RED_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Green_Red.png"), "frame": 1},
	Variant.GREEN_RED_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Green_Red.png"), "frame": 2},
	Variant.RED_BLACK_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Red_Black.png"), "frame": 0},
	Variant.RED_BLACK_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Red_Black.png"), "frame": 1},
	Variant.RED_BLACK_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Red_Black.png"), "frame": 2},
	Variant.RED_BLUE_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Red_Blue.png"), "frame": 0},
	Variant.RED_BLUE_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Red_Blue.png"), "frame": 1},
	Variant.RED_BLUE_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Red_Blue.png"), "frame": 2},
	Variant.RED_RED_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Red_Red.png"), "frame": 0},
	Variant.RED_RED_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Red_Red.png"), "frame": 1},
	Variant.RED_RED_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Coop/Coop_Red_Red.png"), "frame": 2},
}

@export var variant: Variant = Variant.BASE_BLACK_FRAME_1:
	set(value):
		variant = value
		_update_sprite()


func _ready() -> void:
	_update_sprite()


func _update_sprite() -> void:
	var target: Sprite2D = sprite if sprite != null else get_node_or_null("Sprite2D") as Sprite2D
	if target == null:
		return
	if appearance_override != null:
		target.frame = 0
		target.hframes = 1
		target.texture = appearance_override
	else:
		target.hframes = 3
		target.texture = VARIANTS[variant]["texture"]
		target.frame = VARIANTS[variant]["frame"]
