extends Node2D
## A single, refreshable success bubble per subject. Never listens to restored needs.
var remaining: float = 2.0
var feedback_icon: Texture2D
var text_key: String = "Feeling healthy!"
var _label: Label
var _icon: TextureRect
var _panel: PanelContainer
var _visual: Node2D

static func present(animal: AnimalActor, texture: Texture2D, message: String = "Feeling healthy!") -> Node2D:
	if not is_instance_valid(animal) or animal._retired or animal.is_dead() or animal.is_queued_for_deletion():
		return null
	for child: Node in animal.get_children():
		if child.get_meta(&"animal_care_feedback", false) and not child.is_queued_for_deletion():
			child.call("refresh_feedback", texture, message)
			return child as Node2D
	var bubble: Node2D = load("res://components/animals/animal_care_bubble.gd").new() as Node2D
	bubble.set("feedback_icon", texture)
	bubble.set("text_key", message)
	animal.add_child(bubble)
	return bubble

func _ready() -> void:
	name = "CareBubble"
	set_meta(&"animal_care_feedback", true)
	z_index = 21
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_visual = Node2D.new()
	_visual.name = "BubbleVisual"
	add_child(_visual)
	_panel = PanelContainer.new()
	_panel.name = "BubblePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_panel)
	FarmUI.speech(_panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	_panel.add_child(row)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	_label = Label.new()
	_label.name = "Text"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	row.resized.connect(_layout)
	_panel.resized.connect(_layout)
	refresh_feedback(feedback_icon, text_key)
	_visual.scale = Vector2(0.85, 0.85)
	var entrance: Tween = create_tween()
	entrance.tween_property(_visual, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	entrance.tween_property(_visual, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_anchor()

func refresh_feedback(texture: Texture2D, message: String) -> void:
	feedback_icon = texture
	text_key = message
	remaining = 2.0
	modulate.a = 1.0
	if _label != null:
		_label.text = tr(text_key)
		_icon.texture = feedback_icon
		_icon.visible = feedback_icon != null
		_panel.reset_size()
		_layout()

func _layout() -> void:
	_panel.position = Vector2(-_panel.size.x * 0.5, -_panel.size.y - 5)

func _anchor() -> void:
	var animal: AnimalActor = get_parent() as AnimalActor
	if animal != null and animal.health_badges != null:
		position.y = animal.health_badges.position.y - (29.0 if animal.health_badges.visible else 0.0)

func _process(delta: float) -> void:
	_anchor()
	remaining -= delta
	modulate.a = clampf(remaining / 0.3, 0.0, 1.0)
	if remaining <= 0.0:
		queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh_feedback(feedback_icon, text_key)
