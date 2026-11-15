@tool
extends StaticBody2D
## Chọn và cập nhật hình ảnh biến thể công trình trong editor và khi chạy game.
## Setter của variant cập nhật sprite nếu node hình ảnh đã sẵn sàng.

## Các biến thể hình ảnh được cấu hình cho công trình.
enum Variant {
	BASE_BLACK,
	BASE_BLUE,
	BASE_RED,
	GREEN_BLACK,
	GREEN_BLUE,
	GREEN_RED,
	RED_BLACK,
	RED_BLUE,
	RED_RED,
}

## Bảng ánh xạ biến thể sang texture và thông tin frame tương ứng.
const VARIANTS = {
	Variant.BASE_BLACK: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Shed/Shed_Base_Black.png"), "frame": 0},
	Variant.BASE_BLUE: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Shed/Shed_Base_Blue.png"), "frame": 0},
	Variant.BASE_RED: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Shed/Shed_Base_Red.png"), "frame": 0},
	Variant.GREEN_BLACK: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Shed/Shed_Green_Black.png"), "frame": 0},
	Variant.GREEN_BLUE: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Shed/Shed_Green_Blue.png"), "frame": 0},
	Variant.GREEN_RED: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Shed/Shed_Green_Red.png"), "frame": 0},
	Variant.RED_BLACK: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Shed/Shed_Red_Black.png"), "frame": 0},
	Variant.RED_BLUE: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Shed/Shed_Red_Blue.png"), "frame": 0},
	Variant.RED_RED: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Shed/Shed_Red_Red.png"), "frame": 0},
}

## Biến thể hình ảnh đang chọn; thay đổi sẽ cập nhật sprite.
@export var variant: Variant = Variant.BASE_BLACK:
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
