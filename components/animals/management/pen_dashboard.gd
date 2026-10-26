class_name PenDashboard
extends TradeMenu
## Explicit pen management, using the shared menu lock and touch scrolling.
var board: PenBoard
var panel: PanelContainer
var heading: Label
var overview: Label
var grid: GridContainer
var scroll: ScrollContainer
var upgrade_box: VBoxContainer
var upgrade_info: Label
var upgrade_button: Button
var upgrade_feedback: Label
var _upgrade_offer: Dictionary = {}
var _upgrade_cooldown_until: int = 0
var empty: Label
var cards: Dictionary[int, AnimalCard] = {}

func _ready() -> void:
	layer = 27
	_build()
	super._ready()
	visit_started.connect(_visit)
	root.resized.connect(_fit)
	panel.minimum_size_changed.connect(_fit.call_deferred)
	var timer: Timer = Timer.new()
	timer.wait_time = 0.25
	timer.timeout.connect(refresh)
	add_child(timer)
	timer.start()
	_fit()

func _build() -> void:
	root = Control.new()
	root.theme = preload("res://resources/ui/game_theme.tres")
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.06, 0.8)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	var style: StyleBox = root.theme.get_stylebox(&"panel", &"PanelContainer").duplicate() as StyleBox
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(edge, 12)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	body.add_child(header)
	heading = _label(header, 20)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = Button.new()
	close_button.custom_minimum_size = Vector2(64, 48)
	close_button.add_theme_font_size_override("font_size", 16)
	header.add_child(close_button)
	overview = _label(body, 16)
	upgrade_box = VBoxContainer.new()
	body.add_child(upgrade_box)
	upgrade_info = _label(upgrade_box, 16)
	upgrade_button = Button.new()
	upgrade_button.custom_minimum_size.y = 48
	upgrade_button.add_theme_font_size_override("font_size", 16)
	upgrade_button.pressed.connect(_purchase_upgrade)
	upgrade_box.add_child(upgrade_button)
	upgrade_feedback = _label(upgrade_box, 14)
	empty = _label(body, 16)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

func _label(parent: Node, font_size: int) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _fit() -> void:
	var available: Vector2 = Vector2(minf(1040, root.size.x - 16), minf(760, root.size.y - 16))
	grid.columns = maxi(1, floori((available.x - 32) / 236))
	panel.size = available
	panel.position = (root.size - panel.size) * 0.5

func _visit() -> void:
	upgrade_feedback.text = ""
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
	close_button.text = tr("Close")
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
			var card: AnimalCard = AnimalCard.new()
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
	var service: PenUpgradeService = board.world.pen_upgrades
	upgrade_box.visible = service != null and service.managed(board.pen)
	if not upgrade_box.visible:
		return
	_upgrade_offer = service.quote(board.pen)
	var level: int = service.state.level(board.pen.persistent_id)
	upgrade_info.text = tr("Pen level {level}/6 · Capacity {capacity}/30").format({"level":level, "capacity":board.pen.capacity})
	upgrade_button.disabled = not bool(_upgrade_offer.ok) or Time.get_ticks_msec() < _upgrade_cooldown_until
	if level == PenUpgradeState.MAX_LEVEL:
		upgrade_button.text = tr("Maximum capacity reached: 30 animals.")
	elif _upgrade_offer.has("price"):
		upgrade_button.text = tr("Unlock 5 spaces · {price} coins").format({"price":_upgrade_offer.price})
		upgrade_info.text += "\n" + tr("Next upgrade: {current} → {next} spaces").format({"current":board.pen.capacity, "next":_upgrade_offer.next_capacity})
		if _upgrade_offer.get("code") == "insufficient_coins":
			upgrade_info.text += " · " + tr("Need {missing} more coins").format({"missing":_upgrade_offer.missing})
	elif not _upgrade_offer.ok:
		upgrade_button.text = tr(str(_upgrade_offer.error))
	if not _upgrade_offer.ok and _upgrade_offer.get("code") in ["busy", "unavailable"]:
		upgrade_info.text += "\n" + tr(str(_upgrade_offer.error))
	upgrade_feedback.visible = not upgrade_feedback.text.is_empty()

func _purchase_upgrade() -> void:
	if not is_open or Time.get_ticks_msec() < _upgrade_cooldown_until or not bool(_upgrade_offer.get("ok", false)):
		return
	var result: Dictionary = board.world.pen_upgrades.purchase(board.pen, int(_upgrade_offer.level), int(_upgrade_offer.price))
	if result.ok:
		_upgrade_cooldown_until = Time.get_ticks_msec() + 500
	upgrade_feedback.text = tr("Pen expanded to {capacity} spaces.").format({"capacity":result.capacity}) if result.ok else tr(str(result.error))
	refresh()
