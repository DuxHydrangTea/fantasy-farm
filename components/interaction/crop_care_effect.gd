extends Node2D
## Hiệu ứng biểu tượng sâu hoặc cỏ bay lên và mờ đi sau khi chăm sóc cây.

## Texture biểu tượng cỏ dại.
const WEEDS: Texture2D = preload("res://assets/Ui/status_bubbles/weeds.png")
## Texture biểu tượng sâu bệnh.
const PESTS: Texture2D = preload("res://assets/Ui/status_bubbles/worm.png")
## Chọn biểu tượng sâu bệnh thay vì cỏ dại.
var pests: bool = false
## Vị trí bắt đầu trong tọa độ node cha.
var start_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	name = "CropCareEffect"
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = start_position
	var icon: Sprite2D = Sprite2D.new()
	icon.name = "Icon"
	icon.texture = PESTS if pests else WEEDS
	add_child(icon)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 24.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 1.2).set_delay(0.25)
	tween.chain().tween_callback(queue_free)
