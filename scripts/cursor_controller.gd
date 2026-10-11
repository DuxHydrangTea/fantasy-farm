extends Node

const POINTING_CURSOR: Texture2D =  preload(
	"res://assets/Ui/Mouse sprites/Catpaw pointing Mouse icon.png"
)


func _ready() -> void:
	Input.set_custom_mouse_cursor(
		POINTING_CURSOR,
		Input.CURSOR_POINTING_HAND,
		Vector2(16, 3)
	)
