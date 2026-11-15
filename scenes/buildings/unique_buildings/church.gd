@tool
extends StaticBody2D
## Chọn và cập nhật hình ảnh biến thể công trình trong editor và khi chạy game.
## Setter của variant cập nhật sprite nếu node hình ảnh đã sẵn sàng.

## Các biến thể hình ảnh được cấu hình cho công trình.
enum Variant {
	BLACK_FRAME_1,
	BLACK_FRAME_2,
	BLACK_FRAME_3,
	BLACK_FRAME_4,
	BLUE_FRAME_1,
	BLUE_FRAME_2,
	BLUE_FRAME_3,
	BLUE_FRAME_4,
	RED_FRAME_1,
	RED_FRAME_2,
	RED_FRAME_3,
	RED_FRAME_4,
}

## Bảng ánh xạ biến thể sang texture và thông tin frame tương ứng.
const VARIANTS = {
	Variant.BLACK_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Black.png"), "frame": 0},
	Variant.BLACK_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Black.png"), "frame": 1},
	Variant.BLACK_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Black.png"), "frame": 2},
	Variant.BLACK_FRAME_4: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Black.png"), "frame": 3},
	Variant.BLUE_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Blue.png"), "frame": 0},
	Variant.BLUE_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Blue.png"), "frame": 1},
	Variant.BLUE_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Blue.png"), "frame": 2},
	Variant.BLUE_FRAME_4: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Blue.png"), "frame": 3},
	Variant.RED_FRAME_1: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Red.png"), "frame": 0},
	Variant.RED_FRAME_2: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Red.png"), "frame": 1},
	Variant.RED_FRAME_3: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Red.png"), "frame": 2},
	Variant.RED_FRAME_4: {"texture": preload("res://assets/Buildings/Buildings/Unique_Buildings/Church/Church_Red.png"), "frame": 3},
}

## Biến thể hình ảnh đang chọn; thay đổi sẽ cập nhật sprite.
@export var variant: Variant = Variant.BLACK_FRAME_1:
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
