class_name ItemGainPopup
extends Node2D
## Disposable world-space feedback: text and actual item icon, never input.
var item: ItemDefinition
var amount: int = 0
var message: String = ""
var age: float = 0.0
var label: Label
var icon: TextureRect
var row: HBoxContainer
var _origin: Vector2
var _delay: float = 0.0

func _ready() -> void:
	add_to_group(&"item_gain_popups")
	z_as_relative = false
	z_index = 100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	add_child(row)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", preload("res://resources/ui/game_font.tres"))
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
	label.add_theme_constant_override("outline_size", 3)
	row.add_child(label)
	icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.resized.connect(_center_row)
	_origin = position
	_refresh()

func add_amount(count: int) -> void:
	amount += count
	_refresh()

func place_world(at: Vector2) -> void:
	global_position = at
	global_scale = Vector2.ONE
	_origin = position

func shift_up(distance: float) -> void:
	_origin.y -= distance
	position.y -= distance

func start_after(seconds: float) -> void:
	_delay = maxf(0.0, seconds)
	visible = _delay == 0.0

func _refresh() -> void:
	if label != null:
		label.text = tr(message) if not message.is_empty() else "+%d ×" % amount
		icon.texture = item.icon if item != null else null
		icon.visible = message.is_empty()
		if not message.is_empty():
			icon.custom_minimum_size = Vector2.ZERO
			label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))

func _center_row() -> void:
	row.position = Vector2(-row.size.x * 0.5, -row.size.y)

# Đây chỉ là chuyển động chữ/icon: delay nhường chỗ cho nông sản bật ra trước.
# age/lifetime được chuẩn hóa để chữ đi lên một quãng hữu hạn rồi hết vòng đời.
# Scale vượt nhẹ 1 rồi trở về 1 tạo cảm giác nảy; alpha chỉ giảm ở đoạn cuối để có thời gian đọc.
# Các mốc 0,1/0,12/0,65/0,3 giây là thẩm mỹ, có thể chỉnh; phải giữ queue_free để popup cũ
# không tích lũy Node. Bỏ hiệu ứng không được làm thay đổi số đồ trong inventory.
func _process(delta: float) -> void:
	if _delay > 0.0:
		_delay -= delta
		if _delay > 0.0:
			return
		show()
	age += delta
	position = _origin + Vector2(0, -22.0 * minf(age / 0.9, 1.0))
	# A short overshoot gives the reward a bounce before drifting and fading.
	var bounce: float = lerpf(0.6, 1.15, age / 0.1) if age < 0.1 else lerpf(1.15, 1.0, minf((age - 0.1) / 0.12, 1.0))
	row.scale = Vector2.ONE * bounce
	row.pivot_offset = Vector2(row.size.x * 0.5, row.size.y)
	modulate.a = 1.0 - clampf((age - 0.65) / 0.3, 0.0, 1.0)
	if age >= 0.95:
		queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
