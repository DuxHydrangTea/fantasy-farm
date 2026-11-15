@tool
extends StaticBody2D
## Chọn và cập nhật hình ảnh biến thể công trình trong editor và khi chạy game.
## Setter của variant cập nhật sprite nếu node hình ảnh đã sẵn sàng.

## Các biến thể hình ảnh được cấu hình cho công trình.
enum Variant {
	BLACK,
	BLUE,
	RED,
}

## Bảng ánh xạ biến thể sang texture và thông tin frame tương ứng.
const VARIANTS = {
	Variant.BLACK: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Inn/Inn_Black.png"), "frame": 0},
	Variant.BLUE: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Inn/Inn_Blue.png"), "frame": 0},
	Variant.RED: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Inn/Inn_Red.png"), "frame": 0},
}

## Biến thể hình ảnh đang chọn; thay đổi sẽ cập nhật sprite.
@export var variant: Variant = Variant.BLACK:
	set(value):
		variant = value
		_update_sprite()


func _ready() -> void:
	_update_sprite()


func _update_sprite() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = VARIANTS[variant]["texture"]
		sprite.frame = VARIANTS[variant]["frame"]
