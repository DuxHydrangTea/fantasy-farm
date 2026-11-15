class_name WorkerActor
extends CharacterBody2D
## Actor vật lý của công nhân với component di chuyển, hoạt ảnh và hành vi.
## Công nhân được thuê dùng WorkerService để quản lý vai trò, giỏ và dòng thời
## gian công việc online/offline. Actor còn hỗ trợ tuần tra thử nghiệm.

## Cấu hình hình ảnh và tốc độ công nhân.
@export var definition: WorkerDefinition
## Mã ổn định của cá thể.
@export var persistent_id: StringName

## Dịch vụ quản lý công nhân được thuê.
var worker_service: WorkerService
## Mã vai trò công việc.
var worker_role: String = ""
## Inventory riêng của công nhân.
var basket: InventoryComponent
## Nhãn số công nhân và trạng thái chú ý.
var badge: Label

## Sprite hoạt ảnh.
var sprite: AnimatedSprite2D
## Hình va chạm.
var collision: CollisionShape2D
## Component di chuyển.
var movement: MovementComponent
## Component hoạt ảnh.
var animation: AnimationComponent
## Component hành vi.
var behaviour: WorkerBehaviourComponent
## Hiệu ứng dụng cụ chăm sóc.
var care_action: Node2D
## Biểu tượng công việc cạnh nhãn.
var task_icon: Sprite2D

func _enter_tree() -> void:
	basket = get_node("Basket") as InventoryComponent
	badge = get_node("Badge") as Label
	badge.resized.connect(_place_badge)
	sprite = get_node("Sprite") as AnimatedSprite2D
	collision = get_node("Collision") as CollisionShape2D
	movement = get_node("Movement") as MovementComponent
	animation = get_node("Animation") as AnimationComponent
	animation.animated_sprite = sprite
	behaviour = get_node("Behaviour") as WorkerBehaviourComponent
	behaviour.movement = movement
	behaviour.animation = animation

func _ready() -> void:
	if persistent_id.is_empty():
		persistent_id = StringName("worker_" + Crypto.new().generate_random_bytes(16).hex_encode())
	add_to_group(&"grass_interactors")
	if definition == null or not definition.is_valid():
		behaviour.set_physics_process(false)
		return
	_apply_definition()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.scale = Vector2(0.45, 0.45)
	var plate: StyleBoxFlat = StyleBoxFlat.new()
	plate.bg_color = Color(0.12, 0.15, 0.12, 0.78)
	plate.content_margin_left = 3
	plate.content_margin_right = 3
	badge.add_theme_stylebox_override("normal", plate)
	task_icon = Sprite2D.new()
	task_icon.name = "TaskIcon"
	task_icon.z_index = 20
	task_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	task_icon.hide()
	add_child(task_icon)
	care_action = preload("res://components/workers/worker_care_action.gd").new()
	care_action.name = "CareAction"
	care_action.z_index = 2
	care_action.hide()
	add_child(care_action)
	animation.play("idle")

func _apply_definition() -> void:
	movement.speed = definition.move_speed
	animation.single_direction_faces_left = definition.faces_left

## Gán bản sao các điểm tuần tra và bắt đầu từ vị trí hiện tại.
func configure_patrol(points: Array[Vector2]) -> void:
	behaviour.patrol_points = points.duplicate()
	behaviour.begin_patrol(global_position)

func _place_badge() -> void:
	var width: float = badge.size.x * badge.scale.x
	var icon_width: float = 10.0 if is_instance_valid(task_icon) and task_icon.visible else 0.0
	badge.position = Vector2(-(width + icon_width) * 0.5, -25.0 - badge.size.y * badge.scale.y)
	if is_instance_valid(task_icon):
		task_icon.position = badge.position + Vector2(width + 5.0, badge.size.y * badge.scale.y * 0.5)

## Cập nhật số, biểu tượng công việc và màu nhấn cho nhãn.
func show_status(number: int, texture: Texture2D, attention: bool) -> void:
	badge.text = "#%d" % number
	badge.modulate = Color("ffd580") if attention else Color.WHITE
	badge.reset_size()
	if task_icon != null:
		task_icon.texture = texture
		task_icon.visible = texture != null
		if texture != null:
			task_icon.scale = Vector2.ONE * (8.0 / maxf(texture.get_width(), texture.get_height()))
	_place_badge()
