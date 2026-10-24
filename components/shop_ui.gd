class_name ShopUI
extends TradeMenu
## Inventory-style view adapted from the skill inventory_ui template.
@export var panel: PanelContainer
@export var grid: GridContainer
@export var balance_label: Label
@export var details: Label
@export var status: Label
@export var quantity: SpinBox
@export var buy_button: Button
@export var categories: Container
@export var body: VBoxContainer
@export var heading: Label
@export var hint: Label
@export var quantity_label: Label
@export var browse: ScrollContainer
var service: ShopService
var animal_service: AnimalTradeService
var selected_animal: AnimalActor
var selected_animal_offer: AnimalShopOffer
var _animal_rows: Array[AnimalActor] = []
var _price_labels: Dictionary = {}
var _elapsed: float = 0.0
var selected: ShopOffer
var category: int = ShopOffer.Category.CROP
var _buttons: Dictionary = {}
var _animal_text: AnimalStatusText = AnimalStatusText.new()

func _ready() -> void:
	super._ready()
	TouchQuantityComponent.attach(quantity, root)
	balance_label.hide() # The player's balance belongs to the inventory only.
	visit_started.connect(_start_visit)
	models_changed.connect(_refresh)
	root.resized.connect(_fit_layout)
	_fit_layout()
	buy_button.pressed.connect(purchase)
	quantity.value_changed.connect(_quantity_changed)
	for index: int in range(categories.get_child_count()):
		var button: Button = categories.get_child(index) as Button
		button.pressed.connect(show_category.bind(index))

func _start_visit() -> void:
	service = ShopService.new(merchant.catalog, customer.wallet, customer.selection.inventory)
	var farm: FarmingController = customer.farming_actions.get_farming_controller() as FarmingController
	animal_service = AnimalTradeService.new(merchant.catalog, customer.wallet, customer.get_parent(), farm.time_manager if farm != null else TimeManager)
	quantity.value = 1
	show_category(ShopOffer.Category.CROP)
	categories.get_child(0).grab_focus()

func _process(delta: float) -> void:
	if not is_open or category < ShopOffer.Category.ANIMAL:
		return
	_elapsed += delta
	if _elapsed < 0.5:
		return
	_elapsed = 0.0
	if category == ShopOffer.Category.SELL_ANIMAL and animal_service.owned_animals() != _animal_rows:
		show_category(category)
	else:
		_refresh()

func show_category(value: int) -> void:
	var previous_item: ShopOffer = selected if category == value else null
	var previous_offer: AnimalShopOffer = selected_animal_offer if category == value else null
	var previous: AnimalActor = selected_animal if category == value and is_instance_valid(selected_animal) else null
	category = value
	for child: Node in grid.get_children():
		child.free()
	_buttons.clear()
	_price_labels.clear()
	_animal_rows.clear()
	selected = null
	selected_animal = null
	selected_animal_offer = null
	quantity.max_value = 1.0 if category == ShopOffer.Category.SELL_ANIMAL else 99.0
	if category == ShopOffer.Category.ANIMAL:
		for offer: AnimalShopOffer in merchant.catalog.animal_offers:
			_card(offer.icon(), tr(offer.animal.display_name), offer.price, offer, select_animal_offer.bind(offer))
			if selected_animal_offer == null:
				selected_animal_offer = offer
		if merchant.catalog.animal_offers.has(previous_offer):
			selected_animal_offer = previous_offer
	elif category == ShopOffer.Category.SELL_ANIMAL:
		_animal_rows = animal_service.owned_animals()
		for index: int in range(_animal_rows.size()):
			var animal: AnimalActor = _animal_rows[index]
			var checked: Dictionary = animal_service.quote_sell(animal)
			var frames: SpriteFrames = animal.sprite.sprite_frames
			_card(frames.get_frame_texture(&"idle_down", 0), "%d · %s" % [index + 1, tr(animal.definition.display_name)], int(checked.get("total", 0)), animal, _select_animal_card.bind(weakref(animal)))
		if _animal_rows.has(previous):
			selected_animal = previous
	else:
		for offer: ShopOffer in merchant.catalog.offers:
			if offer.category != category:
				continue
			_card(offer.item.icon, tr(offer.item.display_name), offer.price, offer, select_offer.bind(offer))
			if selected == null:
				selected = offer
	if previous_item != null and _buttons.has(previous_item):
		selected = previous_item
	for index: int in range(categories.get_child_count()):
		(categories.get_child(index) as Button).set_pressed_no_signal(index == value)
	_refresh()

func _card(texture: Texture2D, title: String, cost: int, key: Variant, callback: Callable) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(120, 116)
	button.toggle_mode = true
	button.tooltip_text = title
	var body: VBoxContainer = VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 8
	body.offset_top = 8
	body.offset_right = -8
	body.offset_bottom = -10
	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(icon)
	var name_label: Label = Label.new()
	name_label.text = title
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(name_label)
	var price: Label = Label.new()
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	price.add_theme_font_size_override("font_size", 18)
	price.text = tr("{coins} coins").format({"coins": cost})
	body.add_child(price)
	button.pressed.connect(callback)
	grid.add_child(button)
	_buttons[key] = button
	_price_labels[key] = price

func select_animal_offer(offer: AnimalShopOffer) -> void:
	selected_animal_offer = offer
	_refresh()

func _select_animal_card(handle: WeakRef) -> void:
	select_animal(handle.get_ref() as AnimalActor)

func select_animal(animal: AnimalActor) -> void:
	selected_animal = animal
	_refresh()

func select_offer(offer: ShopOffer) -> void:
	selected = offer
	_refresh()

func _quantity_changed(_value: float) -> void:
	_refresh()

func _refresh() -> void:
	if not is_open:
		return
	balance_label.text = tr("{coins} coins").format({"coins": customer.wallet.balance})
	for key: Variant in _buttons:
		(_buttons[key] as Button).set_pressed_no_signal(key == selected or key == selected_animal or key == selected_animal_offer)
	if category == ShopOffer.Category.ANIMAL:
		_refresh_animal_purchase()
		return
	if category == ShopOffer.Category.SELL_ANIMAL:
		_refresh_animal_sale()
		return
	if selected == null:
		details.text = tr("No items available.")
		buy_button.disabled = true
		return
	var amount: int = int(quantity.value)
	var checked: Dictionary = service.quote(selected, amount)
	details.text = tr("{item} · {price} coins / item · In bag: {count}").format({"item": tr(selected.item.display_name), "price": selected.price, "count": customer.selection.inventory.count_item(selected.item.item_id)})
	if not selected.item.description.is_empty():
		details.text += "\n" + tr(selected.item.description)
	buy_button.text = tr("Buy ×{count} - {coins} coins").format({"count": amount, "coins": selected.price * amount})
	buy_button.disabled = not checked.ok
	status.text = tr("Choose an item and quantity.") if checked.ok else GameText.error(checked)

func _duration(seconds: float, remaining: bool = true) -> String:
	var minutes: int = ceili(maxf(0.0, seconds) / 60.0) if remaining else floori(maxf(0.0, seconds) / 60.0)
	if minutes < 60:
		return tr("{minutes} min").format({"minutes": minutes})
	var hours: int = ceili(minutes / 60.0) if remaining else floori(minutes / 60.0)
	return tr("{days}d {hours}h").format({"days": hours / 24, "hours": hours % 24}) if hours >= 24 else tr("{hours}h").format({"hours": hours})

func _refresh_animal_purchase() -> void:
	if selected_animal_offer == null:
		details.text = tr("No animals available to buy.")
		buy_button.disabled = true
		return
	var offer: AnimalShopOffer = selected_animal_offer
	var amount: int = int(quantity.value)
	var checked: Dictionary = animal_service.quote_buy(offer, amount)
	details.text = tr("{animal} · {price} coins / animal · Young, placed in a pen\nMatures in {maturity} · Lifespan {lifespan}").format({"animal": tr(offer.animal.display_name), "price": offer.price, "maturity": _duration(offer.animal.maturity_seconds), "lifespan": _duration(offer.animal.lifespan_seconds)})
	buy_button.text = tr("Buy ×{count} - {coins} coins").format({"count": amount, "coins": offer.price * amount})
	buy_button.disabled = not checked.ok
	status.text = tr("New animals start at age 0. Resale: 50% when young, 75% when adult.") if checked.ok else GameText.error(checked)

func _refresh_animal_sale() -> void:
	if not is_instance_valid(selected_animal):
		selected_animal = null
	for animal: AnimalActor in _animal_rows:
		if is_instance_valid(animal):
			var quote: Dictionary = animal_service.quote_sell(animal)
			(_price_labels[animal] as Label).text = tr("{coins} coins").format({"coins": int(quote.get("total", 0))})
	var checked: Dictionary = animal_service.quote_sell(selected_animal)
	buy_button.disabled = not checked.ok
	buy_button.text = tr("Sell animal") if not checked.ok else tr("Sell - {coins} coins").format({"coins": int(checked.total)})
	if not checked.ok:
		details.text = tr("Select the individual animal you want to sell.") if not _animal_rows.is_empty() else tr("No animals on your farm to sell.")
		status.text = tr("Sell one animal at a time. Finished produce stays on the farm.")
		return
	var animal: AnimalActor = selected_animal
	details.text = tr("{animal} · #{id} · {stage} · Age {age}").format({"animal": tr(animal.definition.display_name), "id": String(animal.persistent_id).right(8), "stage": tr("Adult") if animal.growth.is_adult() else tr("Young"), "age": _duration(animal.growth.age_seconds, false)})
	details.text += "\n" + _animal_text.summary(animal)
	status.text = tr("Sell the selected animal for coins. Its produce stays on the farm.")

func purchase() -> void:
	if not is_open:
		return
	if category == ShopOffer.Category.SELL_ANIMAL:
		if not is_instance_valid(selected_animal):
			selected_animal = null
		var sold_name: String = tr(selected_animal.definition.display_name) if is_instance_valid(selected_animal) else tr("animal")
		var sale: Dictionary = animal_service.sell(selected_animal)
		if sale.ok:
			bought_this_visit = true
			selected_animal = null
			show_category(category)
			status.text = tr("Sold {animal} for {coins} coins!").format({"animal": sold_name, "coins": int(sale.total)})
		else:
			_refresh()
			status.text = GameText.error(sale)
		return
	var animal_purchase: bool = category == ShopOffer.Category.ANIMAL
	var result: Dictionary = animal_service.buy(selected_animal_offer, int(quantity.value)) if animal_purchase else service.buy(selected, int(quantity.value))
	if result.ok:
		bought_this_visit = true
		_refresh()
		status.text = tr("Bought {item} ×{count}!").format({"item": tr(selected_animal_offer.animal.display_name if animal_purchase else selected.item.display_name), "count": int(result.quantity)})
	else:
		_refresh()
		status.text = GameText.error(result)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_language.call_deferred()

func _refresh_language() -> void:
	if is_open:
		# Rebuild outside the notification traversal, retaining the selected item/animal.
		show_category(category)

func _fit_layout() -> void:
	var view: Vector2 = root.size
	var compact: bool = view.x < 1000.0 or view.y < 700.0
	panel.custom_minimum_size = Vector2(minf(960.0, maxf(0.0, view.x - 24.0)), minf(660.0, maxf(0.0, view.y - 24.0)))
	body.add_theme_constant_override("separation", 8 if compact else 12)
	heading.add_theme_font_size_override("font_size", 26 if compact else 30)
	balance_label.add_theme_font_size_override("font_size", 20 if compact else 24)
	quantity_label.text = "Qty" if compact else "Quantity"
	quantity_label.add_theme_font_size_override("font_size", 20 if compact else 24)
	quantity.custom_minimum_size = Vector2(96, 40) if compact else Vector2(108, 48)
	hint.visible = not compact
	for button: Button in categories.get_children():
		button.add_theme_font_size_override("font_size", 20 if compact else 24)
	# Browse is a separate scroll area; changing columns never resets the checkout.
	var short_titles: Array[String] = ["Seeds", "Supplies", "Flowers", "Animals", "Sell"]
	var full_titles: Array[String] = ["Crop seeds", "Farm supplies", "Flower seeds", "Animals", "Sell animals"]
	for index: int in range(categories.get_child_count()):
		var tab: Button = categories.get_child(index) as Button
		tab.text = short_titles[index] if compact else full_titles[index]
		tab.tooltip_text = full_titles[index]
	var width: float = maxf(100.0, (panel.custom_minimum_size.x - 72.0) * 0.5 - 16.0)
	grid.columns = maxi(1, floori((width + 8.0) / 128.0))
	if MobileLayout.is_touch(get_viewport()):
		panel.custom_minimum_size = Vector2(minf(960.0, view.x - 16.0), minf(660.0, view.y - 16.0))
		quantity.custom_minimum_size = Vector2(72, 48)
		quantity_label.hide()
		MobileLayout.prepare_buttons(root)
		for button: Button in categories.get_children():
			button.add_theme_font_size_override("font_size", 18)
	else:
		quantity_label.show()
