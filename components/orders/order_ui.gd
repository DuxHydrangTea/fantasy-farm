class_name OrderUI
extends TradeMenu
## Container-based view adapted from the skill inventory_ui template.
var board: OrderBoard
var panel: PanelContainer
var heading: Label
var rows: Array[Button] = []
var details: Label
var perfect_button: Button
var _pending_plan: Dictionary = {}
var deliver_button: Button
var abandon_button: Button
var refill_button: Button
var status: Label
var confirmation: VBoxContainer
var confirmation_text: Label
var confirm_button: Button
var cancel_button: Button
var selected_serial: int = 0
var _selected_index: int = 0
var _pending_serial: int = 0
var _pending_kind: String = ""
var _message: String = ""
var _coins: int = 0

func _ready() -> void:
	layer = 25
	_build()
	super._ready()
	visit_started.connect(_visit)
	models_changed.connect(_refresh)
	board.service.changed.connect(_refresh)
	root.resized.connect(_fit)
	panel.minimum_size_changed.connect(_fit.call_deferred)
	_fit()

func _button(parent: Node, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _label(parent: Node, font_size: int = 16) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

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
		style.set_content_margin(edge, 8)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var body: VBoxContainer = VBoxContainer.new()
	margin.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	body.add_child(header)
	heading = _label(header, 20)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = _button(header, func() -> void: pass)
	var content: HBoxContainer = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	body.add_child(content)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(left)
	for index: int in range(3):
		var button: Button = _button(left, _select.bind(index))
		button.clip_text = true
		button.toggle_mode = true
		rows.append(button)
	refill_button = _button(left, _refill)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(right)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	details = _label(scroll)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deliver_button = _button(right, _request.bind("deliver"))
	perfect_button = _button(right,_request.bind("perfect"))
	abandon_button = _button(right, _request.bind("abandon"))
	status = _label(body, 14)
	status.custom_minimum_size.y = 24
	# Confirmation replaces the page body, preserving short-screen touch targets.
	confirmation = VBoxContainer.new()
	confirmation.set_meta(&"body", body)
	margin.add_child(confirmation)
	var confirm_header: HBoxContainer = HBoxContainer.new()
	confirmation.add_child(confirm_header)
	var confirm_heading: Label = _label(confirm_header, 20)
	confirm_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_heading.text = tr("Confirm order action")
	var confirm_scroll: ScrollContainer = ScrollContainer.new()
	confirm_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	confirm_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	confirmation.add_child(confirm_scroll)
	confirmation_text = _label(confirm_scroll)
	confirmation_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button = _button(confirmation, _confirm)
	cancel_button = _button(confirmation, _cancel)
	confirmation.hide()

func _fit() -> void:
	panel.size = Vector2(minf(960, root.size.x - 16), minf(640, root.size.y - 16))
	panel.position = (root.size - panel.size) * 0.5

func _visit() -> void:
	_message = ""
	_cancel()
	_select(0)
	rows[0].grab_focus()

func _select(index: int) -> void:
	_selected_index = index
	selected_serial = int(board.service.capture().slots[index].get("serial", 0))
	_message = ""
	_refresh()

func _summary(entry: OrderDefinition) -> String:
	var text: String = tr(entry.title) + "\n\n"
	for index: int in range(entry.items.size()):
		var item: ItemDefinition = entry.items[index]
		text += tr("{item}: {owned}/{needed}").format({"item": tr(item.display_name), "owned": board.service.inventory.count_item(item.item_id), "needed": entry.amounts[index]}) + "\n"
		text += ItemQuality.summary([board.service.inventory.count_item(item.item_id,0),board.service.inventory.count_item(item.item_id,1),board.service.inventory.count_item(item.item_id,2)]) + "\n"
	return text + "\n" + tr("Reward: %d coins") % entry.reward_coins + "\n" + tr("Normal uses Normal only. Perfect uses Silver before Gold: at least +50% order reward and 10% above direct sale.")

func _refresh() -> void:
	if not is_open:
		return
	heading.text = tr("Order board")
	close_button.text = tr("Close")
	var data: Dictionary = board.service.capture()
	selected_serial = int(data.slots[_selected_index].get("serial", 0))
	for index: int in range(3):
		var serial: int = int(data.slots[index].get("serial", 0))
		var entry: OrderDefinition = board.service.definition(serial)
		rows[index].text = tr(entry.title) if entry != null else tr("No available order")
		rows[index].set_pressed_no_signal(serial > 0 and serial == selected_serial)
	var selected: OrderDefinition = board.service.definition(selected_serial)
	details.text = _summary(selected) if selected != null else tr("No available order. Unlock seed supplies and growing areas, then choose Find orders.")
	perfect_button.text = tr("Perfect delivery (sale guarantee)")
	perfect_button.disabled = not board.service.quote(selected_serial,true).ok
	deliver_button.text = tr("Deliver order")
	deliver_button.disabled = not board.service.quote(selected_serial).ok
	abandon_button.text = tr("Abandon order")
	abandon_button.disabled = selected == null
	refill_button.text = tr("Find orders")
	refill_button.disabled = not data.slots.has({})
	status.text = tr(_message) % _coins if _message == "Order delivered: +%d coins" else tr(_message)
	if confirmation.visible:
		_refresh_confirmation()
	_fit()

func _refill() -> void:
	board.service.fill_empty()
	_select(0)

func _request(kind: String) -> void:
	if board.service.definition(selected_serial) == null:
		return
	_pending_serial = selected_serial
	_pending_kind = kind
	_pending_plan = board.service.quote(selected_serial,kind == "perfect") if kind != "abandon" else {}
	confirmation.show()
	(confirmation.get_meta(&"body") as Control).hide()
	_refresh_confirmation()
	cancel_button.grab_focus()

func _refresh_confirmation() -> void:
	var entry: OrderDefinition = board.service.definition(_pending_serial)
	var delivery: bool = _pending_kind in ["deliver","perfect"]
	var latest: Dictionary = board.service.quote(_pending_serial,_pending_kind == "perfect") if delivery else {}
	var stale: bool = delivery and latest != _pending_plan
	if entry == null:
		confirmation_text.text = tr("This order has changed. Select it again.")
	else:
		confirmation_text.text = tr("Deliver all requested items for the reward?") if delivery else tr("Abandon this order without a coin penalty?")
		confirmation_text.text += "\n\n" + _summary(entry)
		if delivery and _pending_plan.get("ok",false):
			confirmation_text.text += "\n\n" + tr("Exact item tiers to consume:")
			for row: Dictionary in _pending_plan.rows:
				var item: ItemDefinition = null
				for candidate: ItemDefinition in entry.items:
					if String(candidate.item_id) == row.item:
						item = candidate
				confirmation_text.text += "\n" + tr(item.display_name) + ": " + ItemQuality.summary(row.tiers)
			var reward_text: String = tr("Perfect reward: {coins} coins").format({"coins":int(_pending_plan.coins)}) if _pending_kind == "perfect" else tr("Reward: %d coins") % int(_pending_plan.coins)
			confirmation_text.text += "\n" + reward_text
			if _pending_kind == "perfect":
				confirmation_text.text += "\n" + tr("Direct sale of these tiers: {coins} coins").format({"coins":int(_pending_plan.sale_coins)})
		if stale:
			confirmation_text.text += "\n\n" + tr("The ingredient tiers changed. Review the preview and confirm again.")
	confirm_button.text = tr("Confirm delivery") if delivery else tr("Confirm abandon")
	confirm_button.disabled = entry == null or (delivery and (not latest.get("ok",false) or stale))
	cancel_button.text = tr("Cancel")

func _confirm() -> void:
	if not is_open or not confirmation.visible or _pending_serial <= 0:
		return
	var delivery: bool = _pending_kind in ["deliver","perfect"]
	var result: Dictionary = board.service.deliver(_pending_serial,_pending_kind == "perfect",_pending_plan) if delivery else board.service.abandon(_pending_serial)
	_message = ("Order delivered: +%d coins" if delivery else "Order abandoned. No coins spent.") if result.ok else String(result.error)
	_coins = int(result.get("coins",0))
	_cancel()
	_refresh()

func _cancel() -> void:
	_pending_serial = 0
	_pending_kind = ""
	_pending_plan = {}
	confirmation.hide()
	(confirmation.get_meta(&"body") as Control).show()

func close(show_thanks: bool = true) -> void:
	_cancel()
	super.close(show_thanks)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
