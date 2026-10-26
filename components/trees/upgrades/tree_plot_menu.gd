class_name TreePlotMenu
extends TradeMenu
var board: TreePlotBoard
var panel: PanelContainer
var heading: Label
var overview: Label
var information: Label
var feedback: Label
var upgrade_button: Button
var scroll: ScrollContainer
var _offer: Dictionary = {}
var _cooldown_until: int = 0

func _ready() -> void:
	layer = 27
	root = Control.new()
	root.theme = preload("res://resources/ui/game_theme.tres")
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.06, 0.8)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	root.add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	heading = _label(body, 22)
	overview = _label(body, 18)
	information = _label(body, 16)
	upgrade_button = Button.new()
	upgrade_button.custom_minimum_size.y = 48
	upgrade_button.add_theme_font_size_override("font_size", 16)
	upgrade_button.pressed.connect(_purchase)
	body.add_child(upgrade_button)
	feedback = _label(body, 16)
	close_button = Button.new()
	close_button.custom_minimum_size.y = 48
	body.add_child(close_button)
	super._ready()
	visit_started.connect(_visit)
	models_changed.connect(refresh)
	root.resized.connect(_fit)
	var timer: Timer = Timer.new()
	timer.wait_time = 0.25
	timer.timeout.connect(refresh)
	add_child(timer)
	timer.start()
	_fit()

func _label(parent: Node, font_size: int) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _fit() -> void:
	panel.size = Vector2(minf(560, root.size.x - 16), minf(420, root.size.y - 16))
	panel.position = ((root.size - panel.size) * 0.5).round()

func _visit() -> void:
	feedback.text = ""
	scroll.scroll_vertical = 0
	refresh()
	close_button.grab_focus()

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
	overview.text = tr("Unlocked: {capacity}/153 · Planted: {planted} · Free: {free}").format({"capacity":capacity, "planted":planted, "free":maxi(0, capacity - planted)})
	information.text = tr("Each upgrade unlocks the next column of 9 plots, from left to right. Unlocked plots stay open after trees are removed.")
	information.text += "\n" + tr("Coins: {coins}").format({"coins":GameText.grouped_integer(customer.wallet.balance)})
	close_button.text = tr("Close")
	upgrade_button.disabled = not bool(_offer.ok) or Time.get_ticks_msec() < _cooldown_until
	if service.state.level(board.kind) == TreePlotUpgradeState.MAX_LEVEL:
		upgrade_button.text = tr("Maximum capacity reached: 153 tree plots.")
	else:
		upgrade_button.text = tr("Unlock 9 plots · {price} coins").format({"price":GameText.grouped_integer(int(_offer.get("price", 0)))})
		information.text += "\n" + tr("Next upgrade: {current} → {next} plots").format({"current":capacity, "next":capacity + 9})
		if _offer.get("code") == "insufficient_coins":
			information.text += "\n" + tr("Need {missing} more coins").format({"missing":GameText.grouped_integer(int(_offer.missing))})
		elif not _offer.ok:
			information.text += "\n" + tr(str(_offer.error))
	feedback.visible = not feedback.text.is_empty()

func _purchase() -> void:
	if not is_open or Time.get_ticks_msec() < _cooldown_until or not bool(_offer.get("ok", false)):
		return
	var result: Dictionary = board.world.tree_plot_upgrades.purchase(board.kind, int(_offer.level), int(_offer.price))
	if result.ok:
		_cooldown_until = Time.get_ticks_msec() + 500
	feedback.text = tr("Expanded to {capacity} tree plots.").format({"capacity":result.capacity}) if result.ok else tr(str(result.error))
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()
