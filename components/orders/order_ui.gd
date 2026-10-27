class_name OrderUI
extends TradeMenu
## Scene-authored order board; quotes and confirmations retain the exact tier plan.
var board: OrderBoard
@onready var panel: PanelContainer = %Panel
@onready var heading: Label = %Heading
@onready var details: Label = %Details
@onready var perfect_button: Button = %Perfect
@onready var deliver_button: Button = %Deliver
@onready var abandon_button: Button = %Abandon
@onready var refill_button: Button = %Refill
@onready var status: Label = %Status
@onready var confirmation: VBoxContainer = %Confirmation
@onready var confirmation_text: Label = %ConfirmationText
@onready var confirm_button: Button = %Confirm
@onready var cancel_button: Button = %Cancel
var rows: Array[Button] = []
var _card_icons: Array[TextureRect] = []
var _card_titles: Array[Label] = []
var _card_states: Array[Label] = []
var _card_rewards: Array[Label] = []
var _pending_plan: Dictionary = {}
var selected_serial: int = 0
var _selected_index: int = 0
var _pending_serial: int = 0
var _pending_kind: String = ""
var _message: String = ""
var _coins: int = 0
var _display_serial: int = -1
var _display_entry: OrderDefinition
var _counts: Array[Label] = []
var _compact: bool = false

func _ready() -> void:
	root = %Root
	close_button = %Close
	confirmation.set_meta(&"body", %Page)
	rows.assign([%Order0, %Order1, %Order2])
	_card_icons.assign([%OrderIcon0, %OrderIcon1, %OrderIcon2])
	_card_titles.assign([%OrderTitle0, %OrderTitle1, %OrderTitle2])
	_card_states.assign([%OrderState0, %OrderState1, %OrderState2])
	_card_rewards.assign([%OrderReward0, %OrderReward1, %OrderReward2])
	super._ready()
	visit_started.connect(_visit)
	models_changed.connect(_refresh)
	board.service.changed.connect(_refresh)
	root.resized.connect(_fit)
	for index: int in range(rows.size()):
		rows[index].pressed.connect(_select.bind(index))
	refill_button.pressed.connect(_refill)
	deliver_button.pressed.connect(_request.bind("deliver"))
	perfect_button.pressed.connect(_request.bind("perfect"))
	abandon_button.pressed.connect(_request.bind("abandon"))
	confirm_button.pressed.connect(_confirm)
	cancel_button.pressed.connect(_cancel)
	_fit()

func _fit() -> void:
	_compact = root.size.x < 900 or root.size.y < 500 or MobileLayout.is_touch(get_viewport())
	panel.custom_minimum_size = Vector2(minf(1120, maxf(0, root.size.x - 24)), minf(620, maxf(0, root.size.y - 16)))
	(%Shell as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 12)
	(%Main as HBoxContainer).add_theme_constant_override("separation", 8 if _compact else 16)
	(%OrderColumn as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 8)
	(%DetailColumn as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 8)
	(%OrderColumn as VBoxContainer).custom_minimum_size.x = 176 if _compact else 320
	(%OrdersHeading as Label).visible = not _compact
	(%Hint as Label).visible = not _compact
	heading.add_theme_font_size_override("font_size", 20 if _compact else 26)
	(%Balance as Label).add_theme_font_size_override("font_size", 14 if _compact else 18)
	(%OrderTitle as Label).add_theme_font_size_override("font_size", 18 if _compact else 24)
	for button: Button in [deliver_button, perfect_button, abandon_button, refill_button, confirm_button, cancel_button]:
		button.add_theme_font_size_override("font_size", 14 if _compact else 18)
	for index: int in range(rows.size()):
		rows[index].custom_minimum_size.y = 64 if _compact else 128
		_card_icons[index].custom_minimum_size = Vector2(24, 24) if _compact else Vector2(48, 48)
		_card_titles[index].add_theme_font_size_override("font_size", 14 if _compact else 18)
		_card_states[index].visible = not _compact
		_card_rewards[index].add_theme_font_size_override("font_size", 12 if _compact else 18)

func _visit() -> void:
	_message = ""
	_cancel()
	_select(0)
	close_button.grab_focus()

func _select(index: int) -> void:
	if index < 0 or index >= rows.size():
		return
	_selected_index = index
	_message = ""
	_refresh()
	(%DetailScroll as ScrollContainer).scroll_vertical = 0

func _money(value: int) -> String:
	return tr("{coins} coins").format({"coins": GameText.grouped_integer(value)})

func _build_requirements(entry: OrderDefinition) -> void:
	for child: Node in (%Requirements as VBoxContainer).get_children():
		child.free()
	_counts.clear()
	if entry == null:
		return
	for index: int in range(entry.items.size()):
		var item: ItemDefinition = entry.items[index]
		var card: PanelContainer = PanelContainer.new()
		card.theme_type_variation = &"DetailCard"
		(%Requirements as VBoxContainer).add_child(card)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var icon: TextureRect = TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var content: VBoxContainer = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(content)
		var caption: Label = Label.new()
		caption.text = tr(item.display_name) + " · " + tr("Needed: {count}").format({"count": entry.amounts[index]})
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(caption)
		var counts: Label = Label.new()
		counts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		counts.add_theme_font_size_override("font_size", 14)
		content.add_child(counts)
		_counts.append(counts)

func _summary(entry: OrderDefinition) -> String:
	var text: String = tr(entry.title) + "\n\n"
	for index: int in range(entry.items.size()):
		var item: ItemDefinition = entry.items[index]
		text += tr("{item}: {owned}/{needed}").format({"item": tr(item.display_name), "owned": board.service.inventory.count_item(item.item_id), "needed": entry.amounts[index]}) + "\n"
		text += ItemQuality.summary([board.service.inventory.count_item(item.item_id, 0), board.service.inventory.count_item(item.item_id, 1), board.service.inventory.count_item(item.item_id, 2)]) + "\n"
	return text + "\n" + tr("Reward: %d coins") % entry.reward_coins + "\n" + tr("Normal uses Normal only. Perfect uses Silver before Gold: at least +50% order reward and 10% above direct sale.")

func _refresh() -> void:
	if not is_open:
		return
	var service: OrderService = board.service
	var data: Dictionary = service.capture()
	selected_serial = int(data.slots[_selected_index].get("serial", 0))
	(%Balance as Label).text = _money(customer.wallet.balance)
	for index: int in range(rows.size()):
		var serial: int = int(data.slots[index].get("serial", 0))
		var entry: OrderDefinition = service.definition(serial)
		var can_deliver: bool = service.quote(serial).ok or service.quote(serial, true).ok
		_card_titles[index].text = tr(entry.title) if entry != null else tr("No available order")
		_card_states[index].text = tr("Ready to deliver") if can_deliver else tr("Delivery unavailable")
		_card_rewards[index].text = _money(entry.reward_coins) if entry != null else "—"
		_card_icons[index].texture = entry.items[0].icon if entry != null else null
		rows[index].tooltip_text = _card_titles[index].text
		rows[index].set_pressed_no_signal(serial > 0 and serial == selected_serial)
	var selected: OrderDefinition = service.definition(selected_serial)
	if _display_serial != selected_serial or _display_entry != selected:
		_display_serial = selected_serial
		_display_entry = selected
		_build_requirements(selected)
	(%OrderTitle as Label).text = tr(selected.title) if selected != null else tr("No available order")
	(%RequirementsHeading as Label).text = tr("Items to deliver") if selected != null else tr("No available order. Unlock seed supplies and growing areas, then choose Find orders.")
	if selected != null:
		for index: int in range(_counts.size()):
			var item: ItemDefinition = selected.items[index]
			_counts[index].text = ItemQuality.summary([service.inventory.count_item(item.item_id, 0), service.inventory.count_item(item.item_id, 1), service.inventory.count_item(item.item_id, 2)])
	var normal: Dictionary = service.quote(selected_serial)
	var perfect: Dictionary = service.quote(selected_serial, true)
	(%NormalReward as Label).text = _money(selected.reward_coins) if selected != null else "—"
	(%PerfectReward as Label).text = _money(int(perfect.coins)) if perfect.ok else ("≥ " + _money(roundi(selected.reward_coins * 1.5)) if selected != null else "—")
	(%NormalState as Label).text = tr("Ready to deliver") if normal.ok else tr(str(normal.error))
	(%PerfectState as Label).text = tr("Ready to deliver") if perfect.ok else tr(str(perfect.error))
	(%PerfectState as Label).tooltip_text = tr("Normal uses Normal only. Perfect uses Silver before Gold: at least +50% order reward and 10% above direct sale.")
	details.text = _summary(selected) if selected != null else ""
	deliver_button.disabled = not normal.ok
	perfect_button.disabled = not perfect.ok
	abandon_button.disabled = selected == null
	refill_button.disabled = not data.slots.has({})
	status.text = tr(_message) % _coins if _message == "Order delivered: +%d coins" else tr(_message)
	status.visible = not status.text.is_empty()
	if confirmation.visible:
		_refresh_confirmation()
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
		_display_serial = -1
		_refresh()
