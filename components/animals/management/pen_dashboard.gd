class_name PenDashboard
extends TradeMenu
## Read-only roster plus the existing capacity upgrade command.
var board: PenBoard
@onready var panel: PanelContainer = %Panel
@onready var heading: Label = %Heading
@onready var overview: Label = %Overview
@onready var grid: GridContainer = %AnimalGrid
@onready var scroll: ScrollContainer = %AnimalScroll
@onready var upgrade_box: VBoxContainer = %UpgradeBox
@onready var upgrade_info: Label = %UpgradeInfo
@onready var upgrade_button: Button = %UpgradeButton
@onready var upgrade_feedback: Label = %UpgradeFeedback
@onready var empty: Label = %Empty
@onready var balance_label: Label = %Balance
@onready var food_meter: ProgressBar = %FoodMeter
@onready var water_meter: ProgressBar = %WaterMeter
var _upgrade_offer: Dictionary = {}
var _upgrade_cooldown_until: int = 0
var cards: Dictionary[int, AnimalCard] = {}
var _compact: bool = false

func _ready() -> void:
	root = %Root
	close_button = %Close
	super._ready()
	visit_started.connect(_visit)
	models_changed.connect(refresh)
	root.resized.connect(_fit)
	upgrade_button.pressed.connect(_purchase_upgrade)
	AnimalCard._style_bar(food_meter, Color("89a76c"))
	AnimalCard._style_bar(water_meter, Color("65a0b8"))
	var timer: Timer = Timer.new()
	timer.wait_time = 0.25
	timer.timeout.connect(refresh)
	add_child(timer)
	timer.start()
	_fit()

func _fit() -> void:
	_compact = root.size.x < 800 or root.size.y < 500 or MobileLayout.is_touch(get_viewport())
	panel.custom_minimum_size = Vector2(minf(1100, maxf(0, root.size.x - 32)), minf(660, maxf(0, root.size.y - 16)))
	(%Body as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 12)
	(%Main as HBoxContainer).add_theme_constant_override("separation", 8 if _compact else 16)
	upgrade_box.custom_minimum_size.x = 188 if _compact else 300
	(%BuildingIcon as TextureRect).visible = not _compact and (%BuildingIcon as TextureRect).texture != null
	(%UpgradeTitle as Label).visible = not _compact
	(%Hint as Label).visible = not _compact
	heading.add_theme_font_size_override("font_size", 20 if _compact else 26)
	balance_label.add_theme_font_size_override("font_size", 16 if _compact else 18)
	upgrade_info.add_theme_font_size_override("font_size", 14 if _compact else 18)
	(%CapacityNext as Label).add_theme_font_size_override("font_size", 18 if _compact else 28)
	upgrade_button.add_theme_font_size_override("font_size", 14 if _compact else 18)
	var titles: Array[Label] = [%PopulationTitle, %FoodTitle, %WaterTitle]
	var values: Array[Label] = [%PopulationValue, %FoodValue, %WaterValue]
	for label: Label in titles:
		label.add_theme_font_size_override("font_size", 12 if _compact else 18)
	for label: Label in values:
		label.add_theme_font_size_override("font_size", 14 if _compact else 18)
	var width: float = panel.custom_minimum_size.x - 32 - (upgrade_box.custom_minimum_size.x + 34 if upgrade_box.visible else 0.0) - 16
	grid.columns = clampi(floori((width + 8) / (140 if _compact else 280)), 1, 4)
	for card: AnimalCard in cards.values():
		card.set_compact(_compact)

func _coins(value: int) -> String:
	return tr("{coins} coins").format({"coins": GameText.grouped_integer(value)})

func _refresh_summary(animals: Array[AnimalActor]) -> void:
	balance_label.text = _coins(customer.wallet.balance)
	(%PopulationTitle as Label).text = tr("Animals")
	(%PopulationValue as Label).text = "%d / %d" % [animals.size(), board.pen.capacity]
	for kind: AnimalTrough.Kind in [AnimalTrough.Kind.FOOD, AnimalTrough.Kind.WATER]:
		var title_label: Label = %FoodTitle if kind == AnimalTrough.Kind.FOOD else %WaterTitle
		var value_label: Label = %FoodValue if kind == AnimalTrough.Kind.FOOD else %WaterValue
		var data: Dictionary = PenStatus.troughs(board.pen, kind)
		var meter: ProgressBar = food_meter if kind == AnimalTrough.Kind.FOOD else water_meter
		title_label.text = tr("Food troughs") if kind == AnimalTrough.Kind.FOOD else tr("Water troughs")
		value_label.text = _level(kind)
		meter.visible = int(data.capacity) > 0
		meter.value = float(data.percent)
		(meter.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color("c78d3b") if meter.value < 30 else (Color("89a76c") if kind == AnimalTrough.Kind.FOOD else Color("65a0b8"))

func _set_building_icon() -> void:
	if not is_instance_valid(board.world):
		(%BuildingIcon as TextureRect).texture = null
		return
	var building: Node = board.world.get_node_or_null("Coop" if board.pen.accepted_species == [AnimalTypes.Species.CHICKEN] else "Barn")
	var sprite: Sprite2D = building.get_node_or_null("Sprite2D") as Sprite2D if building != null else null
	var icon: TextureRect = %BuildingIcon
	if sprite != null and not board.pen is PondPen:
		var texture: AtlasTexture = AtlasTexture.new()
		texture.atlas = sprite.texture
		var frame_size: Vector2 = sprite.texture.get_size() / Vector2(sprite.hframes, sprite.vframes)
		texture.region = Rect2(Vector2(sprite.frame_coords) * frame_size, frame_size)
		icon.texture = texture
	else:
		icon.texture = null

func _visit() -> void:
	upgrade_feedback.text = ""
	_set_building_icon()
	scroll.scroll_vertical = 0
	refresh()
	close_button.grab_focus()

func _level(kind: AnimalTrough.Kind) -> String:
	var result: Dictionary = PenStatus.troughs(board.pen, kind)
	return "%d%%" % floori(float(result.percent)) if result.capacity > 0 else tr("No troughs")

func refresh() -> void:
	if not is_open:
		return
	if not is_instance_valid(board.pen) or not board.pen.is_inside_tree() or board.pen.is_queued_for_deletion():
		close(false)
		return
	_refresh_upgrade()
	var animals: Array[AnimalActor] = PenStatus.members(board.pen)
	heading.text = PenStatus.title(board.pen)
	close_button.text = "×"
	_refresh_summary(animals)
	overview.text = tr("Animals: {count}/{capacity} · Food troughs: {food} · Water troughs: {water}").format({"count": animals.size(), "capacity": board.pen.capacity, "food": _level(AnimalTrough.Kind.FOOD), "water": _level(AnimalTrough.Kind.WATER)})
	empty.text = tr("No animals in this pen yet. Buy animals from the supply merchant.")
	empty.visible = animals.is_empty()
	var present: Dictionary = {}
	var short_ids: Dictionary = {}
	for actor: AnimalActor in animals:
		var id: String = PenStatus.short_id(actor)
		short_ids[id] = int(short_ids.get(id, 0)) + 1
	for actor: AnimalActor in animals:
		var key: int = actor.get_instance_id()
		present[key] = true
		if not cards.has(key):
			var card: AnimalCard = preload("res://scenes/animals/animal_card.tscn").instantiate() as AnimalCard
			card.set_compact(_compact)
			card.animal = actor
			cards[key] = card
			grid.add_child(card)
		var id: String = PenStatus.short_id(actor)
		cards[key].display_id = String(actor.persistent_id) if int(short_ids[id]) > 1 else id
		cards[key].refresh()
	for key: int in cards.keys():
		if not present.has(key):
			var card: AnimalCard = cards[key]
			grid.remove_child(card)
			card.queue_free()
			cards.erase(key)
	_fit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()

func _refresh_upgrade() -> void:
	var service: PenUpgradeService = board.world.pen_upgrades if is_instance_valid(board.world) else null
	upgrade_box.visible = service != null and service.managed(board.pen)
	(%Divider as VSeparator).visible = upgrade_box.visible
	if not upgrade_box.visible:
		return
	_upgrade_offer = service.quote(board.pen)
	var level: int = service.state.level(board.pen.persistent_id)
	upgrade_info.text = tr("Pen level {level}/6 · Capacity {capacity}/30").format({"level": level, "capacity": board.pen.capacity})
	upgrade_button.disabled = not bool(_upgrade_offer.ok) or Time.get_ticks_msec() < _upgrade_cooldown_until
	var maximum: bool = level == PenUpgradeState.MAX_LEVEL
	(%CapacityNext as Label).text = str(board.pen.capacity) if maximum else "%d → %d" % [board.pen.capacity, int(_upgrade_offer.get("next_capacity", board.pen.capacity + 5))]
	(%UpgradeCost as Label).text = "—" if maximum else _coins(int(_upgrade_offer.get("price", 0)))
	upgrade_button.text = tr("Maximum level") if maximum else tr("Unlock 5 spaces")
	(%UpgradeDescription as Label).text = tr("Maximum capacity reached: 30 animals.") if maximum else tr("Unlock 5 additional animal spaces.")
	if not _upgrade_offer.ok and not maximum:
		(%UpgradeDescription as Label).text = tr(str(_upgrade_offer.get("error", "")))
	upgrade_button.tooltip_text = (%UpgradeDescription as Label).text
	upgrade_feedback.visible = not upgrade_feedback.text.is_empty()

func _purchase_upgrade() -> void:
	if not is_open or Time.get_ticks_msec() < _upgrade_cooldown_until or not bool(_upgrade_offer.get("ok", false)):
		return
	var result: Dictionary = board.world.pen_upgrades.purchase(board.pen, int(_upgrade_offer.level), int(_upgrade_offer.price))
	if result.ok:
		_upgrade_cooldown_until = Time.get_ticks_msec() + 500
	upgrade_feedback.text = tr("Pen expanded to {capacity} spaces.").format({"capacity": result.capacity}) if result.ok else tr(str(result.error))
	refresh()
