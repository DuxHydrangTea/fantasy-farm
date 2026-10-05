@tool
extends StaticBody2D

enum Variant {
	DEFAULT,
}

const VARIANTS = {
	Variant.DEFAULT: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Windmill/Windmill.png"), "frame": 0},
}

@export var variant: Variant = Variant.DEFAULT:
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
