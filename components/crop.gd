class_name Crop
extends Node2D

signal matured
var definition: CropDefinition
var planted_at: float = 0.0
var matures_at: float = 0.0
var progress: float = 0.0
var stage: int = 0
var time_manager: FarmClock
@export var sprite: Sprite2D
@export var progress_bar: ProgressBar
@export var progress_frame: Control
var _status_focused: bool = false
var _retiring: bool = false
var _motion: Tween
var _rest_position: Vector2
var _rest_scale: Vector2
var _rest_rotation: float = 0.0
var _bend: float = 0.0:
	set(value):
		_bend = value
		_apply_pose()
var _stretch: Vector2 = Vector2.ONE:
	set(value):
		_stretch = value
		_apply_pose()

func _ready() -> void:
	progress_frame.hide()
	_rest_position = sprite.position
	_rest_scale = sprite.scale
	_rest_rotation = sprite.rotation
	sprite.material = preload("res://resources/effects/crop_wind.tres")

func set_status_focused(value: bool) -> void:
	if _retiring:
		progress_frame.hide()
		return
	if value and not _status_focused:
		react(2.5)
	_status_focused = value
	if value and time_manager != null:
		refresh(time_manager.now())
	progress_frame.visible = value and definition != null

func _apply_pose() -> void:
	if sprite == null:
		return
	# Sprite's original center is above the root: rotate/scale around the stem.
	sprite.position = (_rest_position * _stretch).rotated(_bend)
	sprite.rotation = _rest_rotation + _bend
	sprite.scale = _rest_scale * _stretch

func _start_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_bend = 0.0
	_stretch = Vector2.ONE
	_motion = create_tween()

func react(degrees: float = 5.0, direction: float = 1.0) -> void:
	if _retiring or not is_inside_tree():
		return
	_start_motion()
	var angle: float = deg_to_rad(degrees) * (-1.0 if direction < 0.0 else 1.0)
	_motion.tween_property(self, "_bend", angle, 0.07).set_trans(Tween.TRANS_SINE)
	_motion.tween_property(self, "_bend", -angle * 0.6, 0.09)
	_motion.tween_property(self, "_bend", angle * 0.25, 0.09)
	_motion.tween_property(self, "_bend", 0.0, 0.12)

func play_sprout() -> void:
	_start_motion()
	_stretch = Vector2(0.65, 0.65)
	_motion.tween_property(self, "_stretch", Vector2(0.9, 1.1), 0.13)
	_motion.tween_property(self, "_stretch", Vector2.ONE, 0.12)

func retire_after_harvest() -> void:
	_start_motion()
	_retiring = true
	add_to_group(&"harvest_effects")
	progress_frame.hide()
	_motion.set_parallel(true)
	_motion.tween_property(self, "_stretch", Vector2(1.15, 0.45), 0.16)
	_motion.tween_property(sprite, "modulate:a", 0.0, 0.16)
	_motion.chain().tween_callback(queue_free)

func is_retiring() -> bool:
	return _retiring

func get_status_sprite() -> Node2D:
	return sprite

func configure(crop: CropDefinition, timestamp: float) -> void:
	definition = crop
	planted_at = timestamp
	matures_at = timestamp + crop.growth_seconds
	refresh(timestamp)

func refresh(timestamp: float) -> void:
	if definition == null:
		return
	var was_ready: bool = is_mature()
	progress = maxf(progress, clampf((timestamp - planted_at) / (matures_at - planted_at), 0.0, 1.0))
	# Stage four is ready for harvest, reached exactly at the deadline.
	stage = mini(3, int(floor(progress * 3.0)))
	var texture: Texture2D = definition.stage_textures[stage]
	if sprite.texture != texture:
		sprite.texture = texture
		# Stage frames include transparent headroom; follow the visible leaves.
		var image: Image = texture.get_image()
		if image != null:
			var visible_top: float = sprite.position.y - texture.get_height() * 0.5 + image.get_used_rect().position.y
			progress_frame.position.y = visible_top - progress_frame.size.y - 2.0
	progress_bar.value = progress
	progress_bar.modulate = Color(1.0, 0.85, 0.35) if is_mature() else Color.WHITE
	if not was_ready and is_mature():
		matured.emit()

func is_mature() -> bool:
	return progress >= 1.0

func restore_progress(crop: CropDefinition, planted: float, deadline: float, earned: float, timestamp: float) -> void:
	definition = crop
	planted_at = planted
	matures_at = deadline
	progress = earned
	refresh(timestamp)
