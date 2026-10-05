class_name AnimationComponent
extends Node

@export var animated_sprite: AnimatedSprite2D
@export var fallback_animation: StringName = &"idle_down"
@export var flip_left: bool = true

signal action_finished(action: String)

const DIR_VECTORS: Dictionary[StringName, Vector2] = {
	&"down": Vector2.DOWN,
	&"up": Vector2.UP,
	&"left": Vector2.LEFT,
	&"right": Vector2.RIGHT,
}

var facing_direction: StringName = &"down"
var current_action: String = ""
var _warned: Dictionary[StringName, bool] = {}
var facing_vector: Vector2:
	get:
		return DIR_VECTORS[facing_direction]

func _ready() -> void:
	assert(animated_sprite != null, "AnimationComponent: chua gan animted_sprite")
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
func play(action: String, force_restart: bool = false) -> void:
	if animated_sprite.sprite_frames == null:
		return
	current_action = action
	
	var flip := false
	var dir := facing_direction
	
	if dir == &"left" and flip_left:
		dir = &"right"
		flip = true
		
	var animation_name := StringName("%s_%s" % [action, dir])
	
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		_warn_once(animation_name)
		animation_name = fallback_animation
		flip = false
	
	animated_sprite.flip_h = flip
	
	if animated_sprite.animation == animation_name and animated_sprite.is_playing() and not force_restart:
		return

	if force_restart:
		animated_sprite.stop()
	
	animated_sprite.play(animation_name)

func _warn_once(animation_name: StringName):
	if _warned.has(animation_name):
		return
	_warned[animation_name] = true
	push_warning("AnimationComponent (%s): thiếu animation '%s'" % [owner.name, animation_name])

func _on_animation_finished():
	action_finished.emit(current_action)

func update_facing_direction(dir: Vector2) -> bool:
	if dir.is_zero_approx():
		return false
		
	var old := facing_direction
	var horizontal: StringName = &"right" if dir.x > 0 else &"left"
	var vertical: StringName = &"down" if dir.y > 0 else &"up"
	
	if absf(dir.x) > absf(dir.y):
		facing_direction = horizontal
	elif absf(dir.y) > absf(dir.x):
		facing_direction = vertical
	elif facing_direction != horizontal and facing_direction != vertical:
		facing_direction = horizontal
	
	return facing_direction != old

func face(dir: Vector2) ->void:
	if update_facing_direction(dir) and current_action:
		play(current_action)
