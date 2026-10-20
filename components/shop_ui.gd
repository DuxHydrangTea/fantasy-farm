class_name ShopUI
extends CanvasLayer
## Inventory-style view adapted from the skill inventory_ui template.
@export var root: Control
@export var panel: PanelContainer
@export var grid: GridContainer
@export var balance_label: Label
@export var details: Label
@export var status: Label
@export var quantity: SpinBox
@export var buy_button: Button
@export var close_button: Button
@export var categories: HBoxContainer
var merchant: ShopMerchant
var customer: FarmPlayer
var service: ShopService
var selected: ShopOffer
var category: int = ShopOffer.Category.CROP
var bought_this_visit: bool = false
var is_open: bool = false
var _buttons: Dictionary = {}

func _ready() -> void:
	root.hide()
	close_button.pressed.connect(close)
	buy_button.pressed.connect(purchase)
	quantity.value_changed.connect(_quantity_changed)
	for index: int in range(categories.get_child_count()):
		var button: Button = categories.get_child(index) as Button
		button.pressed.connect(show_category.bind(index))

func open(owner_npc: ShopMerchant, player: FarmPlayer) -> void:
	if is_open:
		return
	merchant = owner_npc
	customer = player
	service = ShopService.new(merchant.catalog, customer.wallet, customer.selection.inventory)
	bought_this_visit = false
	is_open = true
	customer.shop_interaction.active_shop = self
	customer.selection.set_shop_open(true)
	customer.wallet.changed.connect(_wallet_changed)
	customer.selection.inventory.changed.connect(_refresh)
	quantity.value = 1
	root.show()
	show_category(ShopOffer.Category.CROP)
	categories.get_child(0).grab_focus()

func show_category(value: int) -> void:
	category = value
	for child: Node in grid.get_children():
		child.free()
	_buttons.clear()
	selected = null
	for offer: ShopOffer in merchant.catalog.offers:
		if offer.category != category:
			continue
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(100, 104)
		button.toggle_mode = true
		button.tooltip_text = "%s · %d xu" % [offer.item.display_name, offer.price]
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
		icon.texture = offer.item.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		body.add_child(icon)
		var price: Label = Label.new()
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_font_size_override("font_size", 18)
		price.text = "%d xu" % offer.price
		body.add_child(price)
		button.pressed.connect(select_offer.bind(offer))
		grid.add_child(button)
		_buttons[offer] = button
		if selected == null:
			selected = offer
	for index: int in range(categories.get_child_count()):
		(categories.get_child(index) as Button).set_pressed_no_signal(index == value)
	_refresh()

func select_offer(offer: ShopOffer) -> void:
	selected = offer
	_refresh()

func _wallet_changed(_balance: int) -> void:
	_refresh()

func _quantity_changed(_value: float) -> void:
	_refresh()

func _refresh() -> void:
	if not is_open:
		return
	balance_label.text = "%d xu" % customer.wallet.balance
	for offer: ShopOffer in _buttons:
		(_buttons[offer] as Button).set_pressed_no_signal(offer == selected)
	if selected == null:
		details.text = "Chưa có mặt hàng."
		buy_button.disabled = true
		return
	var amount: int = int(quantity.value)
	var checked: Dictionary = service.quote(selected, amount)
	details.text = "%s · %d xu / món · Trong túi: %d" % [selected.item.display_name, selected.price, customer.selection.inventory.count_item(selected.item.item_id)]
	buy_button.text = "Mua ×%d — %d xu" % [amount, selected.price * amount]
	buy_button.disabled = not checked.ok
	status.text = "Chọn vật phẩm và số lượng muốn mua." if checked.ok else String(checked.error)

func purchase() -> void:
	if not is_open:
		return
	# Revalidate on click, even when the UI previously enabled this button.
	var result: Dictionary = service.buy(selected, int(quantity.value))
	if result.ok:
		bought_this_visit = true
		_refresh()
		status.text = "Đã mua %s ×%d!" % [selected.item.display_name, int(result.quantity)]
	else:
		_refresh()
		status.text = String(result.error)

func close(show_thanks: bool = true) -> void:
	if not is_open:
		return
	is_open = false
	root.hide()
	if is_instance_valid(customer):
		if is_instance_valid(customer.wallet):
			customer.wallet.changed.disconnect(_wallet_changed)
		if is_instance_valid(customer.selection):
			customer.selection.inventory.changed.disconnect(_refresh)
			customer.selection.set_shop_open(false)
		if is_instance_valid(customer.shop_interaction):
			customer.shop_interaction.active_shop = null
	if bought_this_visit and show_thanks and is_instance_valid(merchant):
		merchant.thank_customer()
	bought_this_visit = false

func _exit_tree() -> void:
	close(false)

func _input(event: InputEvent) -> void:
	if not is_open or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"toggle_inventory") or event.is_action_pressed(&"harvest") or event.is_action_pressed(&"interact"):
		close()
		get_viewport().set_input_as_handled()
