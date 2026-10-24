class_name PenDashboard
extends TradeMenu
## Explicit pen management, using the shared menu lock and touch scrolling.
var board: PenBoard
var panel: PanelContainer
var heading: Label
var overview: Label
var grid: GridContainer
var scroll: ScrollContainer
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
