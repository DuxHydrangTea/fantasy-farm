class_name AnimationComponent
extends Node

signal action_finished

@export var anim_sprite: AnimatedSprite2D
@export var initial_anim: StringName = &"idle_down"
@export var default_anim: StringName = &"idle_down"
@export var _suffix_facing: String = &"down"
@export var _is_moving: bool = false

func _ready() -> void:
	assert(anim_sprite != null, "Node AnimationSprited2D cần được gán!")
	assert(initial_anim != &"", "Hoạt ảnh khởi đầu chưa có!")
	anim_sprite.animation_finished.connect(_on_animation_finished)
	play(initial_anim)

func stop() -> void:
	pass

func play(anim_name: StringName) -> void:
	if not anim_sprite.sprite_frames.has_animation(anim_name):
		push_warning("Hoạt ảnh %s này không tồn tại!" % anim_name)
		return
	anim_sprite.play(anim_name)

func set_facing(dir: Vector2) -> void:
	anim_sprite.flip_h = dir == Vector2.LEFT
	
	if dir == Vector2.UP:
		_suffix_facing = "up"
	elif dir == Vector2.DOWN:
		_suffix_facing = "down"
	else:
		_suffix_facing = "right"
	
	_update_animation()

func set_is_moving(is_moving: bool) -> void:
	if _is_moving == is_moving:
		return
		
	_is_moving = is_moving
	_update_animation()

func _update_animation() -> void:
	var action: String = "walk" if _is_moving else "idle"
	var action_name: StringName = StringName(action + "_" + _suffix_facing )
	play(action_name)

func play_action(action: StringName) -> bool:
	var anim_name: StringName = StringName(
		String(action) + "_" + _suffix_facing
	)
	
	if not anim_sprite.sprite_frames.has_animation(anim_name):
		push_warning("Thiếu animation hành động: %s" % anim_name)
		return false
		
	if anim_sprite.sprite_frames.get_animation_loop(anim_name):
		push_warning("Animation hành động phải tắt Loop: %s" % anim_name)
		return false
	
	anim_sprite.stop()
	play(anim_name)
	return true

func _on_animation_finished() -> void:
	action_finished.emit()
