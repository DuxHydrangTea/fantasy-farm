class_name HarvestBurst
extends Node2D
## Cosmetic only: the harvest transaction already committed exactly once.
## A few representative icons keep high yields cheap and cannot be recollected.
var item: ItemDefinition
var amount: int = 1
var target: WeakRef
var age: float = 0.0
var icons: Array[Sprite2D] = []
var _lands: Array[Vector2] = []
var _last_target: Vector2

func _ready() -> void:
	add_to_group(&"harvest_effects")
	z_as_relative = false
	z_index = 90
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var count: int = clampi(amount, 1, 3)
	for index: int in range(count):
		var icon: Sprite2D = Sprite2D.new()
		icon.texture = item.icon
		icon.scale = Vector2.ONE * 0.75
		add_child(icon)
		icons.append(icon)
		_lands.append(Vector2((index - float(count - 1) * 0.5) * 9.0, -5.0 - index * 2.0))
	_last_target = global_position

# HIỆU ỨNG TÙY CHỌN — có thể bỏ cả Node này, yield đã được commit trước khi nó sinh ra.
# Pha bật: t chạy 0..1, vị trí ngang tăng tuyến tính còn độ cao = -14*sin(pi*t).
# Sin bằng 0 ở hai đầu và đạt đỉnh ở t=0,5, tạo vòng cung đơn giản không cần body vật lý.
# Pha hút: dùng lerp(điểm rơi, đích player hiện tại, t²); t² làm ban đầu chậm rồi nhanh dần.
# Đổi đích global về local của hiệu ứng trước nội suy; trộn hai hệ tọa độ sẽ bay sai khi map dời/scale.
# Mỗi icon lệch 0,035 giây để có nhịp; tối đa 3 icon đại diện, không tạo 400 Node cho yield 400.
# TUYỆT ĐỐI không inventory.add khi bay xong: phần thưởng đã có, cộng lần nữa sẽ nhân đôi.
func _process(delta: float) -> void:
	age += delta
	var actor: Node2D = target.get_ref() as Node2D if target != null else null
	if is_instance_valid(actor) and actor.is_inside_tree():
		_last_target = actor.global_position + Vector2(0, -12)
	var finished: bool = true
	for index: int in range(icons.size()):
		var elapsed: float = maxf(0.0, age - index * 0.035)
		var icon: Sprite2D = icons[index]
		if elapsed < 0.22:
			var phase: float = elapsed / 0.22
			icon.position = _lands[index] * phase + Vector2(0, -14.0 * sin(phase * PI))
			icon.rotation = sin(phase * PI) * (index - 1) * 0.15
			finished = false
		else:
			var phase: float = clampf((elapsed - 0.22) / 0.3, 0.0, 1.0)
			var eased: float = phase * phase
			icon.position = _lands[index].lerp(to_local(_last_target), eased)
			icon.scale = Vector2.ONE * lerpf(0.75, 0.3, eased)
			icon.modulate.a = 1.0 - clampf((phase - 0.8) / 0.2, 0.0, 1.0)
			finished = finished and phase >= 1.0
	if finished or age >= 0.8:
		queue_free()
