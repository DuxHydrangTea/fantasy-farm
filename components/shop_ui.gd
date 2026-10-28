class_name ShopUI
extends TradeMenu
const UPGRADES: int = ShopOffer.Category.UPGRADES
var upgrade_view: ToolUpgradeShopView
var _normal_hint: String
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
var _category_tabs: Dictionary[int, Button] = {}
@onready var product_icon: TextureRect = %ProductIcon
@onready var product_name: Label = %ProductName
@onready var product_type: Label = %ProductType
@onready var unit_price: Label = %UnitPrice
@onready var owned_count: Label = %OwnedCount
@onready var total_price: Label = %TotalPrice
@onready var sidebar: VBoxContainer = %Sidebar
@onready var price_row: HBoxContainer = %PriceRow
@onready var owned_row: HBoxContainer = %OwnedRow
@onready var total_row: HBoxContainer = %TotalRow
var _compact: bool = false
var _animal_text: AnimalStatusText = AnimalStatusText.new()

func _ready() -> void:
	InventorySlot.style_count(owned_count)
	super._ready()
	_normal_hint = hint.text
	TouchQuantityComponent.attach(quantity, root, true)
	balance_label.show()
	visit_started.connect(_start_visit)
	models_changed.connect(_refresh)
	root.resized.connect(_fit_layout)
	var upgrades_tab: Button = Button.new()
	upgrades_tab.name = "ToolUpgrades"
	upgrades_tab.toggle_mode = true
	upgrades_tab.custom_minimum_size.y = 48
	categories.add_child(upgrades_tab)
	buy_button.pressed.connect(purchase)
	quantity.value_changed.connect(_quantity_changed)
	for index: int in range(categories.get_child_count()):
		var button: Button = categories.get_child(index) as Button
		button.set_meta("category_id", index)
		_category_tabs[index] = button
		button.pressed.connect(show_category.bind(index))
	_fit_layout()

func _start_visit() -> void:
	service = ShopService.new(merchant.catalog, customer.wallet, customer.selection.inventory)
	var world: FarmWorld = customer.get_parent() as FarmWorld
	service.world = world
	upgrade_view = ToolUpgradeShopView.new(self, world.tool_upgrades if world != null else null, world)
	var farm: FarmingController = customer.farming_actions.get_farming_controller() as FarmingController
	animal_service = AnimalTradeService.new(merchant.catalog, customer.wallet, customer.get_parent(), farm.time_manager if farm != null else TimeManager)
	quantity.value = 1
	_configure_categories()
	show_category(merchant.catalog.category_ids[0])
	_category_tabs[category].grab_focus()

func _configure_categories() -> void:
	if ShopOffer.Category.TOOLS in merchant.catalog.category_ids and not _category_tabs.has(ShopOffer.Category.TOOLS):
		var tools_tab: Button = Button.new()
		tools_tab.name = "BuyTools"
		tools_tab.toggle_mode = true
		tools_tab.custom_minimum_size.y = 48
		tools_tab.set_meta("category_id", ShopOffer.Category.TOOLS)
		tools_tab.pressed.connect(show_category.bind(ShopOffer.Category.TOOLS))
		categories.add_child(tools_tab)
		_category_tabs[ShopOffer.Category.TOOLS] = tools_tab
	for id: int in _category_tabs:
		_category_tabs[id].visible = id in merchant.catalog.category_ids
	for index: int in range(merchant.catalog.category_ids.size()):
		categories.move_child(_category_tabs[merchant.catalog.category_ids[index]], index)
	_fit_layout()

func _process(delta: float) -> void:
	if not is_open or (category not in [ShopOffer.Category.ANIMAL, ShopOffer.Category.SELL_ANIMAL, UPGRADES] and (selected == null or selected.item.item_id != WoodMarket.ITEM)):
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
	if merchant != null and value not in merchant.catalog.category_ids:
		return
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
	quantity.visible = category != UPGRADES
	quantity_label.visible = category != UPGRADES and not _compact
	price_row.visible = category not in [ShopOffer.Category.SELL_ANIMAL, UPGRADES]
	owned_row.visible = category not in [ShopOffer.Category.ANIMAL, ShopOffer.Category.SELL_ANIMAL, UPGRADES]
	total_row.visible = category not in [ShopOffer.Category.SELL_ANIMAL, UPGRADES]
	TouchQuantityComponent.refresh_for(quantity)
	hint.text = tr("Choose a tool to upgrade. Esc / E / Tab to close.") if category == UPGRADES else tr(_normal_hint)
	if category == UPGRADES:
		upgrade_view.build()
	elif category == ShopOffer.Category.ANIMAL:
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
	for id: int in _category_tabs:
		_category_tabs[id].set_pressed_no_signal(id == value)
	_refresh()

func _card(texture: Texture2D, title: String, cost: int, key: Variant, callback: Callable) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(104, 108) if _compact else Vector2(148, 148)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.tooltip_text = title
	var card_body: VBoxContainer = VBoxContainer.new()
	card_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(card_body)
	card_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_body.offset_left = 8
	card_body.offset_top = 8
	card_body.offset_right = -8
	card_body.offset_bottom = -10
	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32) if _compact else Vector2(56, 56)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_body.add_child(icon)
	var name_label: Label = Label.new()
	name_label.text = title
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16 if _compact else 18)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card_body.add_child(name_label)
	var price: Label = Label.new()
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	price.add_theme_font_size_override("font_size", 16 if _compact else 18)
	price.text = _coins(cost)
	card_body.add_child(price)
	button.pressed.connect(callback)
	grid.add_child(button)
	_buttons[key] = button
	_price_labels[key] = price

func select_animal_offer(offer: AnimalShopOffer) -> void:
	if category != ShopOffer.Category.ANIMAL or not merchant.catalog.animal_offers.has(offer):
		return
	selected_animal_offer = offer
	_refresh()

func _select_animal_card(handle: WeakRef) -> void:
	select_animal(handle.get_ref() as AnimalActor)

func select_animal(animal: AnimalActor) -> void:
	selected_animal = animal
	_refresh()

func select_offer(offer: ShopOffer) -> void:
	if offer == null or offer.category != category or not merchant.catalog.offers.has(offer):
		return
	selected = offer
	_refresh()

func _quantity_changed(_value: float) -> void:
	_refresh()

func _refresh() -> void:
	if not is_open:
		return
	balance_label.text = _coins(customer.wallet.balance)
	if category == UPGRADES:
		upgrade_view.refresh()
		return
	for key: Variant in _buttons:
		(_buttons[key] as Button).set_pressed_no_signal(key == selected or key == selected_animal or key == selected_animal_offer)
	if category == ShopOffer.Category.ANIMAL:
		_refresh_animal_purchase()
		return
	if category == ShopOffer.Category.SELL_ANIMAL:
		_refresh_animal_sale()
		return
	if selected == null:
		present_product(null, tr("No items available."), "")
		unit_price.text = "—"
		owned_count.text = "—"
		total_price.text = "—"
		details.text = tr("No items available.")
		buy_button.disabled = true
		return
	var amount: int = int(quantity.value)
	var checked: Dictionary = service.quote(selected, amount)
	present_product(selected.item.icon, tr(selected.item.display_name), tr("Flower seeds") if category == ShopOffer.Category.FLOWER else tr("Crop seeds") if category == ShopOffer.Category.CROP else tr("Buy tools") if category == ShopOffer.Category.TOOLS else tr("Farm supplies"))
	unit_price.text = _coins(selected.price)
	owned_count.text = str(customer.selection.inventory.count_item(selected.item.item_id))
	total_price.text = _coins(selected.price * amount)
	details.text = ""
	if selected.item.item_id == WoodMarket.ITEM and service.world != null:
		details.text += "\n" + tr("Wood bought today: {used}/{cap} · Resets at 06:00 (UTC+7)").format({"used": service.world.wood_market.used(service.world.farming.time_manager.now()), "cap": WoodMarket.DAILY_CAP})
	if not selected.item.description.is_empty():
		details.text += "\n" + tr(selected.item.description)
	buy_button.text = tr("Buy ×{count}").format({"count": amount})
	buy_button.disabled = not checked.ok
	status.text = tr("Choose an item and quantity.") if checked.ok else GameText.error(checked)
	_show_purchase_error(checked)

func _duration(seconds: float, remaining: bool = true) -> String:
	var minutes: int = ceili(maxf(0.0, seconds) / 60.0) if remaining else floori(maxf(0.0, seconds) / 60.0)
	if minutes < 60:
		return tr("{minutes} min").format({"minutes": minutes})
	var hours: int = ceili(minutes / 60.0) if remaining else floori(minutes / 60.0)
	return tr("{days}d {hours}h").format({"days": hours / 24, "hours": hours % 24}) if hours >= 24 else tr("{hours}h").format({"hours": hours})

func _refresh_animal_purchase() -> void:
	if selected_animal_offer == null:
		present_product(null, tr("No animals available to buy."), "")
		unit_price.text = "—"
		total_price.text = "—"
		details.text = tr("No animals available to buy.")
		buy_button.disabled = true
		return
	var offer: AnimalShopOffer = selected_animal_offer
	var amount: int = int(quantity.value)
	var checked: Dictionary = animal_service.quote_buy(offer, amount)
	present_product(offer.icon(), tr(offer.animal.display_name), tr("Animals"))
	unit_price.text = _coins(offer.price)
	total_price.text = _coins(offer.price * amount)
	details.text = tr("{animal} · {price} coins / animal · Young, placed in a pen\nMatures in {maturity} · Lifespan {lifespan}").format({"animal": tr(offer.animal.display_name), "price": offer.price, "maturity": _duration(offer.animal.maturity_seconds), "lifespan": _duration(offer.animal.lifespan_seconds)})
	buy_button.text = tr("Buy ×{count}").format({"count": amount})
	buy_button.disabled = not checked.ok
	status.text = tr("New animals start at age 0. Resale: 50% when young, 75% when adult.") if checked.ok else GameText.error(checked)
	_show_purchase_error(checked)

func _show_purchase_error(checked: Dictionary) -> void:
	buy_button.tooltip_text = "" if checked.ok else GameText.error(checked)
	if _compact and not checked.ok:
		buy_button.text = GameText.error(checked)

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
		present_product(null, tr("Sell animals"), "")
		details.text = tr("Select the individual animal you want to sell.") if not _animal_rows.is_empty() else tr("No animals on your farm to sell.")
		status.text = tr("Sell one animal at a time. Finished produce stays on the farm.")
		return
	var animal: AnimalActor = selected_animal
	present_product(animal.sprite.sprite_frames.get_frame_texture(&"idle_down", 0), tr(animal.definition.display_name), tr("Sell animals"))
	details.text = tr("{animal} · #{id} · {stage} · Age {age}").format({"animal": tr(animal.definition.display_name), "id": String(animal.persistent_id).right(8), "stage": tr("Adult") if animal.growth.is_adult() else tr("Young"), "age": _duration(animal.growth.age_seconds, false)})
	details.text += "\n" + _animal_text.summary(animal)
	status.text = tr("Sell the selected animal for coins. Its produce stays on the farm.")

func purchase() -> void:
	if not is_open:
		return
	if category not in merchant.catalog.category_ids:
		return
	if category == UPGRADES:
		upgrade_view.purchase()
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
		if not animal_purchase and selected.item.item_id == WoodMarket.ITEM:
			upgrade_view._save_progress.call_deferred()
		_refresh()
		status.text = tr("Bought {item} ×{count}!").format({"item": tr(selected_animal_offer.animal.display_name if animal_purchase else selected.item.display_name), "count": int(result.quantity)})
	else:
		_refresh()
		status.text = GameText.error(result)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_language.call_deferred()

func _refresh_language() -> void:
	_fit_layout()
	if is_open:
		# Rebuild outside the notification traversal, retaining the selected item/animal.
		show_category(category)

func _coins(amount: int) -> String:
	return tr("{coins} coins").format({"coins": GameText.grouped_integer(amount)})

func present_product(texture: Texture2D, title: String, subtitle: String) -> void:
	product_icon.texture = texture
	product_icon.get_parent().visible = texture != null
	product_name.text = title
	product_type.text = subtitle
	product_type.visible = not subtitle.is_empty()

func _fit_layout() -> void:
	var view: Vector2 = root.size
	_compact = view.x < 800.0 or view.y < 500.0 or MobileLayout.is_touch(get_viewport())
	panel.custom_minimum_size = Vector2(minf(1100.0, maxf(0.0, view.x - 32.0)), minf(620.0, maxf(0.0, view.y - (16.0 if _compact else 24.0))))
	body.add_theme_constant_override("separation", 4 if _compact else 12)
	sidebar.custom_minimum_size.x = 216 if _compact else 300
	sidebar.add_theme_constant_override("separation", 4 if _compact else 8)
	heading.add_theme_font_size_override("font_size", 20 if _compact else 26)
	balance_label.add_theme_font_size_override("font_size", 16 if _compact else 18)
	quantity_label.visible = not _compact and category != UPGRADES
	quantity_label.text = "Quantity"
	quantity.custom_minimum_size = Vector2(60, 48)
	product_icon.custom_minimum_size = Vector2(32, 32) if _compact else Vector2(64, 64)
	product_name.add_theme_font_size_override("font_size", 18 if _compact else 22)
	product_type.add_theme_font_size_override("font_size", 16 if _compact else 18)
	details.add_theme_font_size_override("font_size", 16 if _compact else 18)
	status.add_theme_font_size_override("font_size", 16 if _compact else 18)
	buy_button.add_theme_font_size_override("font_size", 16 if _compact else 18)
	hint.visible = not _compact
	heading.text = tr(merchant.catalog.display_name) if merchant != null and merchant.catalog != null else tr("LAI BUON'S SHOP")
	var short_titles: Array[String] = ["Seeds", "Supplies", "Flowers", "Animals", "Sell", "Upgrades", "Tools"]
	var full_titles: Array[String] = ["Crop seeds", "Farm supplies", "Flower seeds", "Animals", "Sell animals", "Tool upgrades", "Buy tools"]
	for index: int in range(categories.get_child_count()):
		var tab: Button = categories.get_child(index) as Button
		var id: int = int(tab.get_meta("category_id", index))
		tab.text = tr(short_titles[id] if _compact else full_titles[id])
		tab.tooltip_text = tr(full_titles[id])
		tab.add_theme_font_size_override("font_size", 16 if _compact else 18)
	var width: float = panel.custom_minimum_size.x - 32.0 - sidebar.custom_minimum_size.x - 26.0 - 16.0
	var card_width: float = 104.0 if _compact else 148.0
	grid.columns = clampi(floori((width + 8.0) / (card_width + 8.0)), 1, 4)
	for card: Button in _buttons.values():
		card.custom_minimum_size = Vector2(card_width, 108 if _compact else 148)
		var content: VBoxContainer = card.get_child(0) as VBoxContainer
		(content.get_child(0) as TextureRect).custom_minimum_size = Vector2(32, 32) if _compact else Vector2(56, 56)
		(content.get_child(1) as Label).add_theme_font_size_override("font_size", 16 if _compact else 18)
		(content.get_child(2) as Label).add_theme_font_size_override("font_size", 16 if _compact else 18)
		if category == UPGRADES:
			card.custom_minimum_size.y = 176
	TouchQuantityComponent.refresh_for(quantity)
	if MobileLayout.is_touch(get_viewport()):
		MobileLayout.prepare_buttons(root)
	if is_open:
		_refresh()
