class_name VisualMotionComponent
extends Node
## Tạo chuyển động trình bày cho Sprite2D, AnimatedSprite2D hoặc Node2D hình ảnh.
## Pivot nằm trong tọa độ node cha của hình ảnh. Transform ban đầu được giữ
## để khôi phục sau hiệu ứng và không dùng node vật lý làm target.

## Phát tên hiệu ứng khi bắt đầu.
signal effect_started(effect: StringName)
## Phát tên hiệu ứng khi tween hoàn thành.
signal effect_finished(effect: StringName)

## Node hình ảnh chịu hiệu ứng.
@export var target: Node2D
## Tâm xoay và co giãn trong tọa độ cha của target.
@export var pivot: Vector2 = Vector2.ZERO
## Material gió tùy chọn, được khôi phục material cũ khi component rời cây.
@export var wind_material: ShaderMaterial
## Góc nghiêng phản ứng mặc định, tính bằng độ.
@export_range(0.0, 45.0, 0.5) var reaction_degrees: float = 5.0
## Góc phản ứng khi bắt đầu được tập trung, tính bằng độ.
@export_range(0.0, 45.0, 0.5) var focus_degrees: float = 2.5
## Thời gian phản ứng, tính bằng giây.
@export_range(0.01, 2.0, 0.01) var reaction_duration: float = 0.37
## Thời gian xuất hiện, tính bằng giây.
@export_range(0.01, 2.0, 0.01) var appear_duration: float = 0.25
## Thời gian biến mất, tính bằng giây.
@export_range(0.01, 2.0, 0.01) var disappear_duration: float = 0.16
## Tỉ lệ ban đầu của hiệu ứng xuất hiện.
@export var appear_scale: Vector2 = Vector2(0.65, 0.65)
## Tỉ lệ vượt quá trước khi trở về bình thường.
@export var appear_overshoot: Vector2 = Vector2(0.9, 1.1)
## Tỉ lệ cuối của hiệu ứng biến mất.
@export var disappear_scale: Vector2 = Vector2(1.15, 0.45)

var _motion: Tween
var _rest_transform: Transform2D
var _rest_alpha: float = 1.0
var _rest_material: Material
var _focused: bool = false
var _disappearing: bool = false
var _captured: bool = false
var _bend: float = 0.0:
	set(value):
		_bend = value
		_apply_pose()
var _stretch: Vector2 = Vector2.ONE:
	set(value):
		_stretch = value
		_apply_pose()

func _ready() -> void:
	assert(target != null and not target is CollisionObject2D, "Assign a visual Node2D to VisualMotionComponent")
	_rest_transform = target.transform
	_rest_alpha = target.modulate.a
	_rest_material = target.material
	_captured = true
	if wind_material != null:
		target.material = wind_material

func _apply_pose() -> void:
	if not _captured or not is_instance_valid(target):
		return
	# Compose around a parent-space pivot, preserving the entire rest transform.
	# This also handles an already rotated, scaled, skewed or mirrored visual.
	var effect: Transform2D = Transform2D(_bend, _stretch, 0.0, Vector2.ZERO)
	target.transform = Transform2D(0.0, pivot) * effect * Transform2D(0.0, -pivot) * _rest_transform

func _kill_motion() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null

func _restore_pose() -> void:
	_bend = 0.0
	_stretch = Vector2.ONE
	if _captured and is_instance_valid(target):
		target.transform = _rest_transform
		target.modulate.a = _rest_alpha

## Dừng tween, khôi phục tư thế ban đầu và xóa trạng thái tập trung, biến mất.
func reset() -> void:
	_kill_motion()
	_restore_pose()
	_focused = false
	_disappearing = false

## Cho biết tween hiệu ứng hiện còn đang chạy.
func is_animating() -> bool:
	return _motion != null and _motion.is_valid() and _motion.is_running()

func _can_animate() -> bool:
	return _captured and is_inside_tree() and is_instance_valid(target) and target.is_inside_tree() and not _disappearing

func _start_motion() -> void:
	_kill_motion()
	_restore_pose()
	_motion = create_tween()

func _complete(effect: StringName) -> void:
	_motion = null
	effect_finished.emit(effect)

## Đặt trạng thái tập trung; khi chuyển từ không tập trung sang tập trung thì rung nhẹ.
func set_focused(value: bool) -> void:
	var entered: bool = value and not _focused
	_focused = value
	if entered:
		react(focus_degrees)

## Phát hiệu ứng nghiêng qua lại quanh pivot.
## Góc âm dùng góc mặc định; dấu của direction chọn hướng nghiêng ban đầu.
func react(degrees: float = -1.0, direction: float = 1.0) -> void:
	if not _can_animate():
		return
	_start_motion()
	var strength: float = reaction_degrees if degrees < 0.0 else degrees
	var angle: float = deg_to_rad(strength) * (-1.0 if direction < 0.0 else 1.0)
	_motion.tween_property(self, "_bend", angle, reaction_duration * 7.0 / 37.0).set_trans(Tween.TRANS_SINE)
	_motion.tween_property(self, "_bend", -angle * 0.6, reaction_duration * 9.0 / 37.0)
	_motion.tween_property(self, "_bend", angle * 0.25, reaction_duration * 9.0 / 37.0)
	_motion.tween_property(self, "_bend", 0.0, reaction_duration * 12.0 / 37.0)
	_motion.tween_callback(_complete.bind(&"react"))
	effect_started.emit(&"react")

## Phát hiệu ứng co giãn xuất hiện và signal bắt đầu, kết thúc.
func play_appear() -> void:
	if not _can_animate():
		return
	_start_motion()
	_stretch = appear_scale
	_motion.tween_property(self, "_stretch", appear_overshoot, appear_duration * 0.52)
	_motion.tween_property(self, "_stretch", Vector2.ONE, appear_duration * 0.48)
	_motion.tween_callback(_complete.bind(&"appear"))
	effect_started.emit(&"appear")

## Phát hiệu ứng co giãn và mờ dần, sau đó phát signal hoàn thành.
func play_disappear() -> void:
	if not _can_animate():
		return
	_start_motion()
	_disappearing = true
	_motion.set_parallel(true)
	_motion.tween_property(self, "_stretch", disappear_scale, disappear_duration)
	_motion.tween_property(target, "modulate:a", 0.0, disappear_duration)
	_motion.chain().tween_callback(_complete.bind(&"disappear"))
	effect_started.emit(&"disappear")

func _exit_tree() -> void:
	reset()
	if is_instance_valid(target) and wind_material != null and target.material == wind_material:
		target.material = _rest_material
