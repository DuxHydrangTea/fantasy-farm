class_name TreePlotMenu
extends TradeMenu
var board: TreePlotBoard
@onready var panel: PanelContainer = %Panel
@onready var heading: Label = %Heading
@onready var overview: Label = %Overview
@onready var information: Label = %Information
@onready var feedback: Label = %Feedback
@onready var upgrade_button: Button = %UpgradeButton
@onready var scroll: ScrollContainer = %InfoScroll
@onready var plot_preview: TreePlotPreview = %PlotPreview
@onready var balance_label: Label = %Balance
var _offer: Dictionary = {}
var _cooldown_until: int = 0
var _compact: bool = false

func _ready() -> void:
	root = %Root
	close_button = %Close
	super._ready()
	visit_started.connect(_visit)
	models_changed.connect(refresh)
	root.resized.connect(_fit)
	upgrade_button.pressed.connect(_purchase)
	var timer: Timer = Timer.new()
	timer.wait_time = 0.25
	timer.timeout.connect(refresh)
	add_child(timer)
	timer.start()
	_fit()

func _fit() -> void:
	_compact = root.size.x < 800 or root.size.y < 500 or MobileLayout.is_touch(get_viewport())
	panel.custom_minimum_size = Vector2(minf(1000, maxf(0, root.size.x - 32)), minf(560, maxf(0, root.size.y - 16)))
	(%Body as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 12)
	(%Main as HBoxContainer).add_theme_constant_override("separation", 8 if _compact else 16)
	(%UpgradeBox as VBoxContainer).custom_minimum_size.x = 216 if _compact else 300
	(%MapCaption as Label).visible = not _compact
	(%Hint as Label).visible = not _compact
	(%ExpansionTitle as Label).visible = not _compact
	plot_preview.custom_minimum_size.y = 64 if _compact else 200
	heading.add_theme_font_size_override("font_size", 20 if _compact else 26)
	balance_label.add_theme_font_size_override("font_size", 16 if _compact else 18)
	information.add_theme_font_size_override("font_size", 14 if _compact else 18)
	(%NextCapacity as Label).add_theme_font_size_override("font_size", 22 if _compact else 30)
	upgrade_button.add_theme_font_size_override("font_size", 14 if _compact else 18)
	var titles: Array[Label] = [%UnlockedTitle, %PlantedTitle, %FreeTitle]
	var values: Array[Label] = [%UnlockedValue, %PlantedValue, %FreeValue]
	for label: Label in titles:
		label.add_theme_font_size_override("font_size", 12 if _compact else 18)
	for label: Label in values:
		label.add_theme_font_size_override("font_size", 16 if _compact else 24)

func _visit() -> void:
	feedback.text = ""
	scroll.scroll_vertical = 0
	plot_preview.world = board.world
	plot_preview.kind = board.kind
	refresh()
	close_button.grab_focus()

func _coins(value: int) -> String:
	return tr("{coins} coins").format({"coins": GameText.grouped_integer(value)})

func refresh() -> void:
	if not is_open:
		return
	var service: TreePlotUpgradeService = board.world.tree_plot_upgrades
	_offer = service.quote(board.kind)
	var capacity: int = service.state.capacity(board.kind)
	var planted: int = 0
	for tree: PerennialTree in board.world.trees.trees.values():
		if tree.definition.kind == board.kind:
			planted += 1
	heading.text = tr("Fruit tree plots") if board.kind == TreeDefinition.Kind.FRUIT else tr("Timber tree plots")
	balance_label.text = _coins(customer.wallet.balance)
	overview.text = tr("Unlocked: {capacity}/153 · Planted: {planted} · Free: {free}").format({"capacity": capacity, "planted": planted, "free": maxi(0, capacity - planted)})
	(%UnlockedValue as Label).text = "%d / 153" % capacity
	(%PlantedValue as Label).text = str(planted)
	(%FreeValue as Label).text = str(maxi(0, capacity - planted))
	plot_preview.capacity = capacity
	plot_preview.queue_redraw()
	var maximum: bool = service.state.level(board.kind) == TreePlotUpgradeState.MAX_LEVEL
	(%NextCapacity as Label).text = tr("Maximum capacity reached: 153 tree plots.") if maximum else "%d → %d" % [capacity, capacity + 9]
	(%Cost as Label).text = "—" if maximum else _coins(int(_offer.get("price", 0)))
	information.text = tr("Unlock one column of 9 plots.")
	upgrade_button.disabled = not bool(_offer.ok) or Time.get_ticks_msec() < _cooldown_until
	upgrade_button.text = tr("Maximum level") if maximum else tr("Unlock 9 plots")
	if not _offer.ok and not maximum:
		information.text += "\n" + tr(str(_offer.get("error", "")))
	upgrade_button.tooltip_text = information.text
	feedback.visible = not feedback.text.is_empty()
	_fit()

func _purchase() -> void:
	if not is_open or Time.get_ticks_msec() < _cooldown_until or not bool(_offer.get("ok", false)):
		return
	var result: Dictionary = board.world.tree_plot_upgrades.purchase(board.kind, int(_offer.level), int(_offer.price))
	if result.ok:
		_cooldown_until = Time.get_ticks_msec() + 500
	feedback.text = tr("Expanded to {capacity} tree plots.").format({"capacity": result.capacity}) if result.ok else tr(str(result.error))
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()
