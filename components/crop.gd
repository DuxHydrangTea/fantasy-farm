extends Node2D

const Definition = preload("res://scripts/crop_definition.gd")
signal matured
var definition: Definition
var planted_at: float = 0.0
var matures_at: float = 0.0
var progress: float = 0.0
var stage: int = 0
@onready var sprite: Sprite2D = $Sprite
@onready var progress_bar: ProgressBar = $Progress/Bar
@onready var progress_frame: Control = $Progress

func _ready() -> void:
	progress_frame.hide()

func set_status_focused(value: bool) -> void:
	progress_frame.visible = value and definition != null

func get_status_sprite() -> Node2D:
	return sprite

func configure(crop: Definition, timestamp: float) -> void:
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

func restore_progress(crop: Definition, planted: float, deadline: float, earned: float, timestamp: float) -> void:
	definition = crop
	planted_at = planted
	matures_at = deadline
	progress = earned
	refresh(timestamp)
