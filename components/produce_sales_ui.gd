class_name ProduceSalesUI
extends TradeMenu
## Quality-scoped selling view; all inventory and coin mutations stay in the service.
@export var catalog: ProducePriceCatalog
@onready var panel: PanelContainer = %Panel
@onready var body: VBoxContainer = %Body
@onready var heading: Label = %Heading
@onready var balance_label: Label = %Balance
@onready var items: VBoxContainer = %Items
@onready var details: Label = %Details
@onready var status: Label = %Status
@onready var quantity: SpinBox = %Quantity
@onready var sell_quantity_button: Button = %SellQuantity
@onready var sell_all_button: Button = %SellAll
@onready var browse: ScrollContainer = %Browse
var service: ProduceSaleService
var selected: ProducePrice
var quality_tabs: Array[Button] = []
var row_buttons: Array[Button] = []
var _rows: Array[ProducePrice] = []
var _refreshing: bool = false
var _compact: bool = false
var _tier: int = 0
var _message: String = ""
const ROW_SCENE: PackedScene = preload("res://scenes/ui/produce_sale_row.tscn")

func _ready() -> void:
	root = %Root
	close_button = %Close
	super._ready()
	quality_tabs.assign([%Normal, %Silver, %Gold])
	for tier: int in range(quality_tabs.size()):
		quality_tabs[tier].pressed.connect(_choose_tier.bind(tier))
	TouchQuantityComponent.attach(quantity, root, true)
	visit_started.connect(_start_visit)
	models_changed.connect(_refresh)
	quantity.value_changed.connect(_quantity_changed)
	quantity.update_on_text_changed = true
	sell_quantity_button.pressed.connect(sell_quantity)
	sell_all_button.pressed.connect(sell_all)
	(%Maximum as Button).pressed.connect(_set_maximum)
	root.resized.connect(_fit_layout)
	_fit_layout()

func _start_visit() -> void:
	service = ProduceSaleService.new(catalog, customer.wallet, customer.selection.inventory)
	service.tier = _tier
	selected = null
	_message = ""
	quantity.set_value_no_signal(1)
	quantity.get_line_edit().text = "1"
	browse.scroll_vertical = 0
	(%InfoScroll as ScrollContainer).scroll_vertical = 0
	_refresh()
	close_button.grab_focus()

func _select_index(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	selected = _rows[index]
	_message = ""
	_refresh()

func _quantity_changed(_value: float) -> void:
	quantity.get_line_edit().text = str(int(quantity.value))
	_message = ""
	_refresh()

func _coins(value: int) -> String:
	return tr("{coins} coins").format({"coins": GameText.grouped_integer(value)})

func _rebuild_rows(rows: Array[ProducePrice]) -> void:
	_rows = rows
	for child: Node in items.get_children():
		child.free()
	row_buttons.clear()
	for index: int in range(_rows.size()):
		var button: Button = ROW_SCENE.instantiate() as Button
		button.pressed.connect(_select_index.bind(index))
		items.add_child(button)
		row_buttons.append(button)
	_fit_rows()

func _refresh() -> void:
	if not is_open or _refreshing or service == null:
		return
	_refreshing = true
	var rows: Array[ProducePrice] = service.owned_entries()
	if rows != _rows:
		_rebuild_rows(rows)
	if not _rows.has(selected):
		selected = _rows[0] if not _rows.is_empty() else null
	for index: int in range(_rows.size()):
		var entry: ProducePrice = _rows[index]
		var button: Button = row_buttons[index]
		(button.get_node("Margin/Row/Icon") as TextureRect).texture = entry.item.icon
		(button.get_node("Margin/Row/Name") as Label).text = tr(entry.item.display_name)
		(button.get_node("Margin/Row/Owned") as Label).text = GameText.grouped_integer(service.quantity(entry))
		(button.get_node("Margin/Row/Price") as Label).text = _coins(ItemQuality.unit_price(entry.price, _tier))
		button.tooltip_text = "%s · %s\n%s" % [tr(entry.item.display_name), ItemQuality.label(_tier), _coins(ItemQuality.unit_price(entry.price, _tier))]
		button.set_pressed_no_signal(entry == selected)
	for tier: int in range(quality_tabs.size()):
		quality_tabs[tier].set_pressed_no_signal(tier == _tier)
	balance_label.text = _coins(customer.wallet.balance)
	quantity.editable = selected != null
	TouchQuantityComponent.refresh_for(quantity)
	var amount: int = int(quantity.value)
	var checked: Dictionary = service.quote(selected, amount)
	var owned: int = service.quantity(selected)
	var unit_price: int = ItemQuality.unit_price(selected.price, _tier) if selected != null else 0
	var item_name: String = tr(selected.item.display_name) if selected != null else tr("No produce to sell.")
	(%ProductIcon as TextureRect).texture = selected.item.icon if selected != null else null
	(%ProductIcon as TextureRect).visible = selected != null
	(%ProductName as Label).text = item_name
	(%Quality as Label).text = tr("Quality") + ": " + ItemQuality.label(_tier)
	if selected != null:
		details.text = tr("In bag: {count}\nUnit price: {price}").format({"count": GameText.grouped_integer(owned), "price": _coins(unit_price)})
	else:
		details.text = tr("Bring harvested crops, flowers or animal produce.")
	(%Total as Label).text = _coins(unit_price * amount)
	(%Maximum as Button).disabled = _maximum() < 1
	sell_quantity_button.disabled = not checked.ok
	sell_quantity_button.text = tr("Sell ×{count} - {coins} coins").format({"count": amount, "coins": GameText.grouped_integer(unit_price * amount)})
	var all: Dictionary = service.quote_all()
	sell_all_button.disabled = not all.ok
	sell_all_button.text = tr("Sell all · {quality} · {coins}").format({"quality": ItemQuality.label(_tier), "coins": _coins(int(all.get("total", 0)))})
	# Wallet-overflow quotes include the candidate totals; other failures may not.
	(%BulkSummary as Label).text = tr("All {quality} produce: {count} items · {coins}").format({"quality": ItemQuality.label(_tier), "count": int(all.get("quantity", 0)), "coins": _coins(int(all.get("total", 0)))})
	sell_all_button.tooltip_text = (%BulkSummary as Label).text + "\n" + tr("Sells every accepted item of the selected quality in your bag.")
	if not all.ok:
		sell_all_button.tooltip_text += "\n" + GameText.error(all)
	status.text = _message if not _message.is_empty() else (GameText.error(checked) if not checked.ok and selected != null else "")
	status.visible = not status.text.is_empty()
	(%Empty as Label).visible = _rows.is_empty()
	var warning: String = _order_warning()
	(%Warning as Label).text = warning
	(%WarningPanel as PanelContainer).visible = not warning.is_empty()
	_refreshing = false

func _maximum() -> int:
	if selected == null or service == null:
		return 0
	var unit: int = ItemQuality.unit_price(selected.price, _tier)
	var wallet_room: int = WalletComponent.MAX_COINS - customer.wallet.balance
	return mini(service.quantity(selected), int(wallet_room / float(unit))) if unit > 0 else service.quantity(selected)

func _set_maximum() -> void:
	quantity.value = maxi(1, _maximum())
	quantity.get_line_edit().text = str(int(quantity.value))

func _order_warning() -> String:
	var farm: FarmWorld = customer.get_parent() as FarmWorld
	if farm != null and farm.orders != null and farm.orders.service.requested_in_bag():
		return tr("Sell all also sells items requested by your orders. Deliver them at the order board first if you want to keep them.")
	return ""

func sell_quantity() -> void:
	if not is_open:
		return
	quantity.apply()
	# The service rechecks stock and wallet after the entered text is committed.
	_show_result(service.sell(selected, int(quantity.value)))

func sell_all() -> void:
	if is_open:
		_show_result(service.sell_all())

func _show_result(result: Dictionary) -> void:
	if result.ok:
		bought_this_visit = true
		_message = tr("Sold {count} items for {coins} coins!").format({"count": int(result.quantity), "coins": GameText.grouped_integer(int(result.total))})
	else:
		_message = GameText.error(result)
	_refresh()

func _fit_layout() -> void:
	var compact: bool = root.size.x < 900 or root.size.y < 500 or MobileLayout.is_touch(get_viewport())
	if compact != _compact:
		_compact = compact
		(%WarningPanel as PanelContainer).reparent(%InfoContent if compact else body)
	panel.custom_minimum_size = Vector2(minf(1120, maxf(0, root.size.x - 24)), minf(620, maxf(0, root.size.y - 16)))
	body.add_theme_constant_override("separation", 4 if _compact else 12)
	(%Main as HBoxContainer).add_theme_constant_override("separation", 8 if _compact else 16)
	(%Sidebar as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 8)
	(%BrowsePanel as PanelContainer).custom_minimum_size.x = 240 if _compact else 400
	(%Sidebar as VBoxContainer).custom_minimum_size.x = 0 if _compact else 320
	heading.add_theme_font_size_override("font_size", 20 if _compact else 26)
	balance_label.add_theme_font_size_override("font_size", 14 if _compact else 18)
	(%ProductIcon as TextureRect).custom_minimum_size = Vector2(36, 36) if _compact else Vector2(64, 64)
	(%ProductName as Label).add_theme_font_size_override("font_size", 18 if _compact else 24)
	(%Total as Label).add_theme_font_size_override("font_size", 22 if _compact else 28)
	(%BrowseHeading as Label).visible = not _compact
	(%QuantityHeading as Label).visible = not _compact
	(%Quality as Label).add_theme_font_size_override("font_size", 14 if _compact else 18)
	(%OwnedHeading as Label).custom_minimum_size.x = 40 if _compact else 72
	(%PriceHeading as Label).custom_minimum_size.x = 64 if _compact else 96
	for label: Label in [%ItemHeading, %OwnedHeading, %PriceHeading]:
		label.add_theme_font_size_override("font_size", 12 if _compact else 16)
	for button: Button in quality_tabs + [sell_quantity_button, sell_all_button]:
		button.add_theme_font_size_override("font_size", 14 if _compact else 18)
	_fit_rows()

func _fit_rows() -> void:
	for button: Button in row_buttons:
		button.custom_minimum_size.y = 48 if _compact else 64
		(button.get_node("Margin/Row/Icon") as TextureRect).custom_minimum_size = Vector2(24, 24) if _compact else Vector2(36, 36)
		(button.get_node("Margin/Row/Owned") as Label).custom_minimum_size.x = 40 if _compact else 72
		(button.get_node("Margin/Row/Price") as Label).custom_minimum_size.x = 64 if _compact else 96
		for label_name: String in ["Name", "Owned", "Price"]:
			(button.get_node("Margin/Row/" + label_name) as Label).add_theme_font_size_override("font_size", 14 if _compact else 18)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_message = ""
		_refresh()

func _choose_tier(index: int) -> void:
	if index < 0 or index > 2:
		return
	_tier = index
	_message = ""
	quantity.set_value_no_signal(1)
	quantity.get_line_edit().text = "1"
	if service != null:
		service.tier = index
		selected = null
		_refresh()
	browse.scroll_vertical = 0
