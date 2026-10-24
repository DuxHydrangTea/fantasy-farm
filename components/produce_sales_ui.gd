class_name ProduceSalesUI
extends TradeMenu
@export var catalog: ProducePriceCatalog
@export var panel: PanelContainer
@export var body: VBoxContainer
@export var heading: Label
@export var balance_label: Label
@export var items: ItemList
@export var details: Label
@export var status: Label
@export var quantity: SpinBox
@export var sell_quantity_button: Button
@export var sell_all_button: Button
var service: ProduceSaleService
var selected: ProducePrice
var _rows: Array[ProducePrice] = []
var _refreshing: bool = false

func _ready() -> void:
	super._ready()
	TouchQuantityComponent.attach(quantity, root)
	balance_label.hide()
	visit_started.connect(_start_visit)
	models_changed.connect(_refresh)
	items.item_selected.connect(_select_index)
	quantity.value_changed.connect(_quantity_changed)
	quantity.update_on_text_changed = true
	sell_quantity_button.pressed.connect(sell_quantity)
	sell_all_button.pressed.connect(sell_all)
	root.resized.connect(_fit_layout)
	_fit_layout()

func _start_visit() -> void:
	service = ProduceSaleService.new(catalog, customer.wallet, customer.selection.inventory)
	selected = null
	_rows.clear()
	items.clear()
	quantity.value = 1
	_refresh()
	items.grab_focus()

func _select_index(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	selected = _rows[index]
	_refresh()

func _quantity_changed(_value: float) -> void:
	_refresh()

func _refresh() -> void:
	if not is_open or _refreshing:
		return
	_refreshing = true
	var rows: Array[ProducePrice] = service.owned_entries()
	if rows != _rows:
		_rows = rows
		items.clear()
		for entry: ProducePrice in _rows:
			items.add_item("", entry.item.icon)
	if not _rows.has(selected):
		selected = _rows[0] if not _rows.is_empty() else null
	for index: int in range(_rows.size()):
		var entry: ProducePrice = _rows[index]
		items.set_item_text(index, tr("{item} ×{count}").format({"item": tr(entry.item.display_name), "count": service.quantity(entry)}))
		if entry == selected:
			items.select(index)
	balance_label.text = tr("{coins} coins").format({"coins": customer.wallet.balance})
	quantity.max_value = maxi(1, customer.selection.inventory.slot_count * 32000)
	quantity.editable = selected != null
	TouchQuantityComponent.refresh_for(quantity)
	var checked: Dictionary = service.quote(selected, int(quantity.value))
	sell_quantity_button.disabled = not checked.ok
	sell_quantity_button.text = tr("Sell ×{count} - {coins} coins").format({"count": int(quantity.value), "coins": selected.price * int(quantity.value) if selected != null else 0})
	var all: Dictionary = service.quote_all()
	sell_all_button.disabled = not all.ok
	sell_all_button.tooltip_text = tr("Enter a quantity, or sell all accepted produce in your bag.") if all.ok else GameText.error(all)
	sell_all_button.text = tr("Sell all produce - {coins} coins").format({"coins": int(all.get("total", 0))})
	if selected != null:
		details.text = tr("{item}\nIn bag: {count}\nPrice: {price} coins each").format({"item": tr(selected.item.display_name), "count": service.quantity(selected), "price": selected.price})
		status.text = tr("Enter a quantity, or sell all accepted produce in your bag.") if checked.ok else GameText.error(checked)
	else:
		details.text = tr("No produce to sell.")
		status.text = tr("Bring harvested crops, flowers or animal produce.")
	var warning: String = _order_warning()
	if not warning.is_empty():
		status.text += "\n" + warning
		sell_all_button.tooltip_text = warning
	_refreshing = false

func _order_warning() -> String:
	var farm: FarmWorld = customer.get_parent() as FarmWorld
	if farm != null and farm.orders != null and farm.orders.service.requested_in_bag():
		return tr("Sell all also sells items requested by your orders. Deliver them at the order board first if you want to keep them.")
	return ""

func sell_quantity() -> void:
	if not is_open or sell_quantity_button.disabled:
		return
	quantity.apply()
	_show_result(service.sell(selected, int(quantity.value)))

func sell_all() -> void:
	if is_open:
		_show_result(service.sell_all())

func _show_result(result: Dictionary) -> void:
	_refresh()
	if result.ok:
		bought_this_visit = true
		status.text = tr("Sold {count} items for {coins} coins!").format({"count": int(result.quantity), "coins": int(result.total)})
	else:
		status.text = GameText.error(result)
	var warning: String = _order_warning()
	if not warning.is_empty():
		status.text += "\n" + warning

func _fit_layout() -> void:
	var view: Vector2 = root.size
	var compact: bool = view.x < 1000.0 or view.y < 700.0
	panel.custom_minimum_size = Vector2(minf(960.0, maxf(0.0, view.x - 24.0)), minf(660.0, maxf(0.0, view.y - 24.0)))
	body.add_theme_constant_override("separation", 8 if compact else 12)
	heading.add_theme_font_size_override("font_size", 26 if compact else 30)
	balance_label.add_theme_font_size_override("font_size", 20 if compact else 24)
	items.add_theme_font_size_override("font_size", 20 if compact else 24)
	quantity.custom_minimum_size = Vector2(96, 40) if compact else Vector2(108, 48)
	if MobileLayout.is_touch(get_viewport()):
		panel.custom_minimum_size = Vector2(minf(960.0, view.x - 16.0), minf(660.0, view.y - 16.0))
		quantity.custom_minimum_size = Vector2(72, 48)
		items.add_theme_constant_override("v_separation", 16)
		MobileLayout.prepare_buttons(root)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
