extends Node2D
## Shared cream speech panel and smooth font, anchored above the animal.
var remaining: float = 3.0

func _ready() -> void:
	name = "CareBubble"
	z_index = 21
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var animal: AnimalActor = get_parent() as AnimalActor
	if animal != null and animal.health_badges != null:
		position.y = animal.health_badges.position.y - (29.0 if animal.health_badges.visible else 0.0)
	var visual: Node2D = Node2D.new()
	visual.name = "BubbleVisual"
	add_child(visual)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "BubblePanel"
	visual.add_child(panel)
	FarmUI.speech(panel)
	var label: Label = Label.new()
	label.name = "Text"
	label.text = tr("Feeling healthy!")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	panel.reset_size()
	panel.position = Vector2(-panel.size.x * 0.5, -panel.size.y - 5)
	visual.scale = Vector2(0.85, 0.85)
	var entrance: Tween = create_tween()
	entrance.tween_property(visual, "scale", Vector2(1.06, 1.06), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	entrance.tween_property(visual, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	var animal: AnimalActor = get_parent() as AnimalActor
	if animal != null and animal.health_badges != null:
		position.y = animal.health_badges.position.y - (29.0 if animal.health_badges.visible else 0.0)
	remaining -= delta
	modulate.a = clampf(remaining / 0.3, 0.0, 1.0)
	if remaining <= 0.0:
		queue_free()
