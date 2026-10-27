class_name AnimalCard
extends PanelContainer
## Independent animated portrait; this view never mutates world animals.
var animal: AnimalActor
@onready var caption: Label = %Caption
@onready var food: ProgressBar = %FoodBar
@onready var water: ProgressBar = %WaterBar
@onready var food_text: Label = %FoodText
@onready var water_text: Label = %WaterText
@onready var produce: Label = %Produce
@onready var preview: AnimatedSprite2D = %Preview
@onready var portrait: Control = %Portrait
var display_id: String
var _compact: bool = false
var _text: AnimalStatusText = AnimalStatusText.new()

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBox = preload("res://resources/ui/cozy_hud/slot_normal.tres").duplicate() as StyleBox
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(edge, 10)
	add_theme_stylebox_override("panel", style)
	_style_bar(food, Color("89a76c"))
	_style_bar(water, Color("65a0b8"))
	portrait.resized.connect(_place_portrait)
	set_compact(_compact)
	refresh()

static func _style_bar(bar: ProgressBar, color: Color) -> void:
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color("ddc59e")
	background.border_color = Color("795238")
	background.border_width_left = 1
	background.border_width_right = 1
	background.border_width_top = 1
	background.border_width_bottom = 1
	bar.add_theme_stylebox_override("background", background)

func set_compact(value: bool) -> void:
	_compact = value
	if not is_node_ready():
		return
	custom_minimum_size.x = 132 if value else 272
	portrait.custom_minimum_size = Vector2(32, 48) if value else Vector2(72, 72)
	caption.add_theme_font_size_override("font_size", 14 if value else 18)
	(%Stage as Label).add_theme_font_size_override("font_size", 12 if value else 16)
	for label: Label in [food_text, water_text, produce]:
		label.add_theme_font_size_override("font_size", 12 if value else 16)
	food_text.custom_minimum_size.x = 64 if value else 96
	water_text.custom_minimum_size.x = 64 if value else 96
	(%Body as VBoxContainer).add_theme_constant_override("separation", 4 if value else 8)
	_place_portrait()

func _place_portrait() -> void:
	preview.position = portrait.size * 0.5
	if preview.sprite_frames == null or preview.animation.is_empty():
		return
	var texture: Texture2D = preview.sprite_frames.get_frame_texture(preview.animation, 0)
	if texture == null:
		return
	var bounds: Rect2 = Rect2(texture.get_image().get_used_rect())
	var factor: float = minf(5.0, minf(portrait.size.x / maxf(bounds.size.x, 1), portrait.size.y / maxf(bounds.size.y, 1)))
	preview.scale = Vector2.ONE * factor
	preview.offset = texture.get_size() * 0.5 - bounds.get_center()

func refresh() -> void:
	if not _text.is_available(animal):
		return
	caption.text = tr(animal.definition.display_name) + " · #" + display_id
	caption.tooltip_text = String(animal.persistent_id)
	(%Stage as Label).text = tr("Adult") if animal.growth.is_adult() else tr("Young")
	food.value = animal.needs.satiety
	water.value = animal.needs.hydration
	food_text.text = tr("Satiety: {percent}%").format({"percent": floori(food.value)})
	water_text.text = tr("Hydration: {percent}%").format({"percent": floori(water.value)})
	(food.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color("c78d3b") if food.value < 30 else Color("89a76c")
	(water.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color("c78d3b") if water.value < 30 else Color("65a0b8")
	produce.text = _text.produce(animal) + "\n" + _text.production_state(animal)
	if animal.production.stored_amount > 0 and animal.production.definition != null and animal.production.definition.collection_mode == AnimalProductionDefinition.CollectionMode.DIRECT_COLLECTION:
		produce.text += "\n" + tr("Ready to collect: {amount}").format({"amount": animal.production.stored_amount})
	tooltip_text = _text.maturity(animal) + "\n" + _text.lifetime(animal)
	if _compact:
		produce.text += "\n" + _text.maturity(animal) + "\n" + _text.lifetime(animal)
	produce.tooltip_text = tooltip_text
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
	preview.play(idle)
	preview.frame = posmod(String(animal.persistent_id).hash(), frames.get_frame_count(idle))
	_place_portrait()
