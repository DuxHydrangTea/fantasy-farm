@tool
extends StaticBody2D

enum Variant {
	BLACK,
	BLUE,
	RED,
}

const VARIANTS = {
	Variant.BLACK: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Blacksmith_House/Blacksmith_House_Black.png"), "frame": 0},
	Variant.BLUE: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Blacksmith_House/Blacksmith_House_Blue.png"), "frame": 0},
	Variant.RED: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Blacksmith_House/Blacksmith_House_Red.png"), "frame": 0},
}

@export var variant: Variant = Variant.BLACK:
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
