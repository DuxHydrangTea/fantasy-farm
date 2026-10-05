@tool
extends StaticBody2D

enum Variant {
	LIMESTONE_BLACK,
	LIMESTONE_BLUE,
	LIMESTONE_RED,
	STONE_BASE_BLACK,
	STONE_BASE_BLUE,
	STONE_BASE_RED,
	STONE_GREEN_BLACK,
	STONE_GREEN_BLUE,
	STONE_GREEN_RED,
	STONE_RED_BLACK,
	STONE_RED_BLUE,
	STONE_RED_RED,
	WOOD_BASE_BLACK,
	WOOD_BASE_BLUE,
	WOOD_BASE_RED,
	WOOD_GREEN_BLACK,
	WOOD_GREEN_BLUE,
	WOOD_GREEN_RED,
	WOOD_RED_BLACK,
	WOOD_RED_BLUE,
	WOOD_RED_RED,
}

const VARIANT_TEXTURES = {
	Variant.LIMESTONE_BLACK: preload("res://assets/Buildings/Buildings/Houses/Limestone/House_3_Limestone_Base_Black.png"),
	Variant.LIMESTONE_BLUE: preload("res://assets/Buildings/Buildings/Houses/Limestone/House_3_Limestone_Base_Blue.png"),
	Variant.LIMESTONE_RED: preload("res://assets/Buildings/Buildings/Houses/Limestone/House_3_Limestone_Base_Red.png"),
	Variant.STONE_BASE_BLACK: preload("res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Base_Black.png"),
	Variant.STONE_BASE_BLUE: preload("res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Base_Blue.png"),
	Variant.STONE_BASE_RED: preload("res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Base_Red.png"),
	Variant.STONE_GREEN_BLACK: preload("res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Green_Black.png"),
	Variant.STONE_GREEN_BLUE: preload("res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Green_Blue.png"),
	Variant.STONE_GREEN_RED: preload("res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Green_Red.png"),
	Variant.STONE_RED_BLACK: preload("res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Red_Black.png"),
	Variant.STONE_RED_BLUE: preload("res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Red_Blue.png"),
	Variant.STONE_RED_RED: preload("res://assets/Buildings/Buildings/Houses/Stone/House_3_Stone_Red_Red.png"),
	Variant.WOOD_BASE_BLACK: preload("res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Base_Black.png"),
	Variant.WOOD_BASE_BLUE: preload("res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Base_Blue.png"),
	Variant.WOOD_BASE_RED: preload("res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Base_Red.png"),
	Variant.WOOD_GREEN_BLACK: preload("res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Green_Black.png"),
	Variant.WOOD_GREEN_BLUE: preload("res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Green_Blue.png"),
	Variant.WOOD_GREEN_RED: preload("res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Green_Red.png"),
	Variant.WOOD_RED_BLACK: preload("res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Red_Black.png"),
	Variant.WOOD_RED_BLUE: preload("res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Red_Blue.png"),
	Variant.WOOD_RED_RED: preload("res://assets/Buildings/Buildings/Houses/Wood/House_3_Wood_Red_Red.png"),
}

@export var variant: Variant = Variant.LIMESTONE_BLACK:
	set(value):
		variant = value
		_update_texture()


func _ready() -> void:
	_update_texture()


func _update_texture() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = VARIANT_TEXTURES[variant]
