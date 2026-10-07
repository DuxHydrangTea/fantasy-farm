@tool
class_name FarmPlot
extends Node2D

@export var dry_texture: Texture2D
@export var wet_texture: Texture2D
@onready var soil_sprite: Sprite2D = $SoilSprite
var wet_duration: float = 5.0
var plot_id: StringName
var wet_remaining: float = 0.0 #seconds
var _focused: bool = false
const PLOT_RECT: Rect2 = Rect2(-8, -16,16,16)

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
		
	assert(dry_texture != null, "Chưa gán dry_texture")
	assert(wet_texture != null, "Chưa gán wet_texture")
	
	_refresh_soil()
	set_process(true)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	wet_remaining = maxf(0.0, wet_remaining - _delta)
	
	if not is_wet():
		_refresh_soil()
		set_process(false)

func _refresh_soil() -> void:
	soil_sprite.texture = wet_texture if is_wet() else dry_texture
	
func is_wet() -> bool:
	return wet_remaining > 0.0
	
func water() -> bool:
	if Engine.is_editor_hint() or is_wet():
		return false
		
	wet_remaining = wet_duration
	_refresh_soil()
	set_process(true)
	return true
	
func contains_world_point(world_position: Vector2) -> bool: 
	return PLOT_RECT.has_point(to_local(world_position))
	
func set_focused(value: bool) -> void:
	if _focused == value:
		return
	
	_focused = value
	queue_redraw()
	
func _draw() -> void:
	if not _focused:
		return
	
	var border := PLOT_RECT.grow(-0.5)
	draw_rect(border, Color("#ffe006"), false, 1.0)
	
