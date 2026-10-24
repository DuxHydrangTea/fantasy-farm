class_name AnimalCard
extends PanelContainer
## An independent animated portrait; it never runs or changes world animal AI.
var animal: AnimalActor
var caption: Label
var food: ProgressBar
var water: ProgressBar
var food_text: Label
var water_text: Label
var produce: Label
var preview: AnimatedSprite2D
var portrait: Control
var display_id: String
var _text: AnimalStatusText = AnimalStatusText.new()

func _ready() -> void:
	custom_minimum_size.x = 228
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBox = get_theme_stylebox(&"panel").duplicate() as StyleBox
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(edge, 10)
	add_theme_stylebox_override("panel", style)
	var body: VBoxContainer = VBoxContainer.new()
	add_child(body)
	portrait = Control.new()
	portrait.custom_minimum_size.y = 80
	portrait.clip_contents = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(portrait)
	preview = AnimatedSprite2D.new()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.add_child(preview)
	portrait.resized.connect(_place_portrait)
	caption = _label(body)
	food_text = _label(body)
	food = _bar(body, Color("8ab65e"))
	water_text = _label(body)
	water = _bar(body, Color("65b8de"))
	produce = _label(body)
	refresh()

func _label(parent: Node) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _bar(parent: Node, color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size.y = 12
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color("654f39")
	bar.add_theme_stylebox_override("background", background)
	parent.add_child(bar)
	return bar

func _place_portrait() -> void:
	preview.position = portrait.size * 0.5

func refresh() -> void:
	if not _text.is_available(animal):
		return
	caption.text = tr(animal.definition.display_name) + " · #" + display_id
	caption.tooltip_text = String(animal.persistent_id)
	food.value = animal.needs.satiety
	water.value = animal.needs.hydration
	food_text.text = tr("Satiety: {percent}%").format({"percent": floori(food.value)})
	water_text.text = tr("Hydration: {percent}%").format({"percent": floori(water.value)})
	produce.text = _text.produce(animal) + "\n" + _text.production_state(animal)
	if animal.production.stored_amount > 0 and animal.production.definition != null and animal.production.definition.collection_mode == AnimalProductionDefinition.CollectionMode.DIRECT_COLLECTION:
		produce.text += "\n" + tr("Ready to collect: {amount}").format({"amount": animal.production.stored_amount})
	tooltip_text = _text.maturity(animal) + "\n" + _text.lifetime(animal)
	var frames: SpriteFrames = animal.sprite.sprite_frames
	if preview.sprite_frames == frames:
		return
	preview.sprite_frames = frames
	if frames == null:
		return
	var idle: StringName = &"idle_down"
	if not frames.has_animation(idle):
		for action: StringName in frames.get_animation_names():
			if String(action).begins_with("idle"):
				idle = action
				break
	if not frames.has_animation(idle) or frames.get_frame_count(idle) == 0:
		return
	var texture: Texture2D = frames.get_frame_texture(idle, 0)
	var bounds: Rect2 = Rect2(texture.get_image().get_used_rect())
	var factor: float = minf(2.5, minf(160.0 / maxf(bounds.size.x, 1), 72.0 / maxf(bounds.size.y, 1)))
	preview.scale = Vector2.ONE * factor
	preview.offset = texture.get_size() * 0.5 - bounds.get_center()
	preview.play(idle)
	preview.frame = posmod(String(animal.persistent_id).hash(), frames.get_frame_count(idle))
	_place_portrait()
