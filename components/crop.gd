class_name Crop
extends Node2D
## Shared stage textures have identical opaque bounds across crop instances.
static var _visible_tops: Dictionary[Texture2D, float] = {}

signal matured
var definition: CropDefinition
var planted_at: float = 0.0
var matures_at: float = 0.0
var progress: float = 0.0
var stage: int = 0
var watered: bool = false
var root_boost: bool = false
var quality_label: Label
var fertilized: bool = false
var pollination_reduction: float = 0.0
var time_manager: FarmClock
@export var sprite: Sprite2D
@export var progress_bar: ProgressBar
@export var progress_frame: Control
@export var motion: VisualMotionComponent
var _retiring: bool = false

func _ready() -> void:
	progress_frame.hide()
	quality_label = Label.new()
	quality_label.name = "HarvestQuality"
	quality_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quality_label.add_theme_font_size_override("font_size", 8)
	quality_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	quality_label.add_theme_constant_override("shadow_offset_x", 1)
	quality_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(quality_label)
	_update_quality()
	if is_instance_valid(motion):
		motion.effect_finished.connect(_on_motion_finished)

func set_status_focused(value: bool) -> void:
	if _retiring:
		progress_frame.hide()
		return
	if is_instance_valid(motion):
		motion.set_focused(value)
	if value and time_manager != null:
		refresh(time_manager.now())
	progress_frame.visible = value and definition != null
	_update_quality()

func react(degrees: float = 5.0, direction: float = 1.0) -> void:
	if not _retiring and is_instance_valid(motion):
		motion.react(degrees, direction)

func play_sprout() -> void:
	if not _retiring and is_instance_valid(motion):
		motion.play_appear()

# Gameplay removes the crop before this cosmetic animation begins.
# The component reports completion; only the crop owns its lifetime.
func retire_after_harvest() -> void:
	_retiring = true
	if quality_label != null:
		quality_label.hide()
	add_to_group(&"harvest_effects")
	progress_frame.hide()
	if is_instance_valid(motion):
		motion.play_disappear()
	else:
		queue_free()

func _on_motion_finished(effect: StringName) -> void:
	if _retiring and effect == &"disappear":
		queue_free()

func is_retiring() -> bool:
	return _retiring

func get_status_sprite() -> Node2D:
	return sprite

func configure(crop: CropDefinition, timestamp: float) -> void:
	progress = 0.0
	stage = 0
	watered = false
	root_boost = false
	fertilized = false
	pollination_reduction = 0.0
	definition = crop
	planted_at = timestamp
	matures_at = timestamp + crop.growth_seconds
	refresh(timestamp)

# Tiến độ = (giờ hiện tại - lúc trồng) / (hạn chín - lúc trồng), kẹp trong [0,1].
# Lấy max với tiến độ đã có để thời gian lùi không làm cây non lại; timestamp cho phép
# nhảy thẳng đến kết quả sau offline, không cần giả lập từng frame đã bỏ lỡ.
# stage = floor(progress * 3) cho 4 stage 0..3: stage cuối chỉ đạt khi progress = 1.
# Nhân 4 ở đây sẽ cho hình chín từ 75% thời gian dù luật thu hoạch vẫn yêu cầu 100%.
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
		if not _visible_tops.has(texture):
			var image: Image = texture.get_image()
			if image != null:
				_visible_tops[texture] = float(image.get_used_rect().position.y)
		if _visible_tops.has(texture):
			var visible_top: float = sprite.position.y - texture.get_height() * 0.5 + _visible_tops[texture]
			progress_frame.position.y = visible_top - progress_frame.size.y - 2.0
	_update_quality()
	progress_bar.value = progress
	progress_bar.modulate = Color(1.0, 0.85, 0.35) if is_mature() else Color.WHITE
	if not was_ready and is_mature():
		matured.emit()

func is_mature() -> bool:
	return progress >= 1.0

func restore_progress(crop: CropDefinition, planted: float, deadline: float, earned: float, timestamp: float, was_fertilized: bool = false, bee_reduction: float = 0.0, was_watered: bool = false, was_root_boosted: bool = false) -> void:
	definition = crop
	planted_at = planted
	matures_at = deadline
	progress = earned
	fertilized = was_fertilized
	pollination_reduction = bee_reduction
	watered = was_watered
	root_boost = was_root_boosted
	refresh(timestamp)

func fertilizer_error(timestamp: float) -> String:
	if _retiring or definition == null:
		return "No crop to fertilize."
	refresh(timestamp)
	if fertilized:
		return "This crop was already fertilized."
	if progress >= 0.5:
		return "Fertilizer requires growth below 50%."
	return ""

func apply_fertilizer(timestamp: float) -> bool:
	if not fertilizer_error(timestamp).is_empty():
		return false
	fertilized = true
	# Move the original deadline by 20% of the ORIGINAL total duration.
	matures_at -= (matures_at - planted_at + pollination_reduction) * 0.2
	refresh(timestamp)
	react(7.0)
	return true

func harvest_tier() -> int:
	return 2 if watered and root_boost else 1 if watered else 0

func mark_watered() -> void:
	watered = true
	_update_quality()

func root_error() -> String:
	if _retiring or definition == null:
		return "No crop to fertilize."
	if not watered:
		return "Water this crop before applying Root Tonic."
	return "Root Tonic was already applied to this crop." if root_boost else ""

func apply_root() -> bool:
	if not root_error().is_empty():
		return false
	root_boost = true
	_update_quality()
	react(7.0)
	return true

func _update_quality() -> void:
	if quality_label == null:
		return
	var tier: int = harvest_tier()
	quality_label.text = ("* " if root_boost else "") + ItemQuality.label(tier)
	quality_label.modulate = ItemQuality.color(tier)
	quality_label.position = Vector2(-14, progress_frame.position.y - 10)
	quality_label.visible = not _retiring and (progress_frame.visible or root_boost)
