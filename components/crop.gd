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

# Đây là hiệu ứng có thể tắt; dữ liệu cây không phụ thuộc vào độ nghiêng.
# Sprite có tâm nằm phía trên gốc. Xoay riêng rotation sẽ làm cây quay quanh bụng ảnh,
# nên phải xoay cả vector từ gốc tới tâm, đồng thời co giãn vector đó cùng với sprite.
# Nhờ vậy chân vẫn neo ở ô đất. Root/collision/timestamp không được di chuyển theo hiệu ứng.
func _apply_pose() -> void:
	if sprite == null:
		return
	# Sprite's original center is above the root: rotate/scale around the stem.
	sprite.position = (_rest_position * _stretch).rotated(_bend)
	sprite.rotation = _rest_rotation + _bend
	sprite.scale = _rest_scale * _stretch

# Chỉ giữ một Tween phản ứng và hoàn nguyên pose trước khi tạo nhịp mới.
# Nếu cộng dồn Tween mỗi lần focus/tưới, nhiều Tween cùng ghi một thuộc tính làm cây giật,
# nghiêng quá mức hoặc không trở về dáng cũ. Có thể bỏ toàn bộ hiệu ứng, nhưng không nên
# giữ hiệu ứng mà bỏ bước hủy/khôi phục này.
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

# Cây đã được gỡ khỏi danh sách gameplay trước khi gọi hàm này; Node còn lại 0,16 giây
# chỉ để co/mờ. _retiring ngăn thanh tiến độ bị focus làm hiện lại trên cây đang biến mất.
# Có thể queue_free ngay thay cho nhịp mờ mà không thay phần thưởng; không được trì hoãn
# việc gỡ cây khỏi dữ liệu tới cuối Tween, vì lúc đó có thể tương tác/thu hoạch lần nữa.
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
