extends Node2D
## One world-space bubble per subject, with all active conditions in a stable row.
## The node's origin is the tail tip; callers anchor it above the visible head.
const STATUS_KEYS: Array[StringName] = [&"weeds", &"pests", &"sick", &"hungry", &"thirsty"]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/Ui/status_bubbles/weeds.png"),
	preload("res://assets/Ui/status_bubbles/worm.png"),
	preload("res://assets/Ui/status_bubbles/sick.png"),
	preload("res://assets/Ui/status_bubbles/hungry.png"),
	preload("res://assets/Ui/status_bubbles/thirsty.png"),
]
const PANELS: Array[Texture2D] = [
	preload("res://assets/Ui/status_bubbles/bubble_1.png"),
	preload("res://assets/Ui/status_bubbles/bubble_2.png"),
	preload("res://assets/Ui/status_bubbles/bubble_3.png"),
	preload("res://assets/Ui/status_bubbles/bubble_4.png"),
	preload("res://assets/Ui/status_bubbles/bubble_5.png"),
]
var active_statuses: Array[StringName] = []
var _icons: Array[Sprite2D] = []
var _visual: Node2D
var _background: Sprite2D
var _entrance: Tween
var _mask: int = -1

func visual_rect() -> Rect2:
	if not visible or _background == null or _background.texture == null:
		return Rect2()
	return _visual.transform * Rect2(_background.position, _background.texture.get_size())

func _ensure_visuals() -> void:
	if _visual != null:
		return
	z_index = 8
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visual = Node2D.new()
	_visual.name = "BubbleVisual"
	add_child(_visual)
	_background = Sprite2D.new()
	_background.name = "BubblePanel"
	_background.centered = false
	_visual.add_child(_background)
	for index: int in range(TEXTURES.size()):
		var icon: Sprite2D = Sprite2D.new()
		icon.name = String(STATUS_KEYS[index])
		icon.texture = TEXTURES[index]
		icon.centered = false
		_visual.add_child(icon)
		_icons.append(icon)

func set_statuses(pests: bool, weeds: bool, sick: bool, hungry: bool = false, thirsty: bool = false) -> void:
	var flags: Array[bool] = [weeds, pests, sick, hungry, thirsty]
	var next_mask: int = 0
	for index: int in range(flags.size()):
		if flags[index]:
			next_mask |= 1 << index
	if next_mask == _mask:
		return # Clock/hover refreshes must never restart the popup animation.
	var was_empty: bool = _mask <= 0
	_mask = next_mask
	_ensure_visuals()
	active_statuses.clear()
	for index: int in range(flags.size()):
		_icons[index].visible = flags[index]
		if flags[index]:
			active_statuses.append(STATUS_KEYS[index])
	visible = not active_statuses.is_empty()
	if _entrance != null and _entrance.is_valid():
		_entrance.kill()
	_visual.scale = Vector2.ONE
	if not visible:
		return
	var width: float = 12.0 + active_statuses.size() * 16.0 + (active_statuses.size() - 1) * 4.0
	_background.texture = PANELS[active_statuses.size() - 1]
	_background.position = Vector2(-width * 0.5, -27.0)
	var slot: int = 0
	for index: int in range(flags.size()):
		if flags[index]:
			_icons[index].position = Vector2(-width * 0.5 + 6.0 + slot * 20.0, -24.0)
			slot += 1
	if was_empty and is_inside_tree():
		_visual.scale = Vector2(0.85, 0.85)
		_entrance = create_tween()
		_entrance.tween_property(_visual, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_entrance.tween_property(_visual, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
