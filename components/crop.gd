class_name Crop
extends Node2D
## Shared stage textures have identical opaque bounds across crop instances.
static var _visible_tops: Dictionary[Texture2D, float] = {}
static var _quality_material: ParticleProcessMaterial
static var _quality_texture: ImageTexture
static var _silver_texture: ImageTexture

signal matured
var definition: CropDefinition
var planted_at: float = 0.0
var matures_at: float = 0.0
var progress: float = 0.0
var stage: int = 0
var watered: bool = false
var root_boost: bool = false
var quality_particles: GPUParticles2D
var _displayed_quality: int = 0
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
	if quality_particles != null:
		quality_particles.emitting = false
		quality_particles.hide()
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
	var tier: int = harvest_tier() if not _retiring else 0
	if tier == _displayed_quality:
		return
	_displayed_quality = tier
	if tier == 0:
		if quality_particles != null:
			quality_particles.emitting = false
			quality_particles.hide()
		return
	if quality_particles == null:
		_create_quality_particles()
	quality_particles.modulate = Color(1.0, 0.78, 0.25, 0.7) if tier == 2 else Color(0.82, 0.86, 0.91, 0.65)
	quality_particles.texture = _quality_texture if tier == 2 else _silver_texture
	quality_particles.show()
	quality_particles.restart()
	quality_particles.emitting = true

func _create_quality_particles() -> void:
	if _quality_material == null:
		_quality_material = ParticleProcessMaterial.new()
		_quality_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		_quality_material.emission_box_extents = Vector3(11, 4, 0)
		_quality_material.direction = Vector3(0, -1, 0)
		_quality_material.spread = 25.0
		_quality_material.gravity = Vector3(0, -3, 0)
		_quality_material.initial_velocity_min = 5.0
		_quality_material.initial_velocity_max = 10.0
		_quality_material.scale_min = 0.55
		_quality_material.scale_max = 1.0
		_quality_material.particle_flag_disable_z = true
		var fade: Gradient = Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0))
		fade.add_point(0.25, Color.WHITE)
		fade.set_color(2, Color(1, 1, 1, 0))
		var ramp: GradientTexture1D = GradientTexture1D.new()
		ramp.gradient = fade
		_quality_material.color_ramp = ramp
		var image: Image = Image.create(5, 5, false, Image.FORMAT_RGBA8)
		for point: Vector2i in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(2, 3), Vector2i(2, 4)]:
			image.set_pixel(point.x, point.y, Color.WHITE)
		_quality_texture = ImageTexture.create_from_image(image)
		var dot: Image = Image.create(3, 3, false, Image.FORMAT_RGBA8)
		for point: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
			dot.set_pixel(point.x, point.y, Color.WHITE)
		_silver_texture = ImageTexture.create_from_image(dot)
	quality_particles = GPUParticles2D.new()
	quality_particles.name = "QualityParticles"
	quality_particles.emitting = false
	quality_particles.amount = 3
	quality_particles.lifetime = 1.5
	quality_particles.randomness = 0.7
	quality_particles.preprocess = 1.5
	quality_particles.position = Vector2(0, -8)
	quality_particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	quality_particles.texture = _quality_texture
	quality_particles.process_material = _quality_material
	add_child(quality_particles)
