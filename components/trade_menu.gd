class_name TradeMenu
extends CanvasLayer
## Shared modal lifecycle for buying and selling; views own their own commands.
signal visit_started
signal models_changed
@export var root: Control
@export var close_button: Button
var merchant: ShopMerchant
var customer: FarmPlayer
var bought_this_visit: bool = false
var is_open: bool = false
var _closing: bool = false
var _slide: Node

func _ready() -> void:
	root.hide()
	UIScaleComponent.attach(self, root)
	_slide = preload("res://components/modal_slide.gd").new()
	add_child(_slide)
	_slide.configure(self, ^"offset:y", root)
	close_button.pressed.connect(close)

func open(owner_npc: ShopMerchant, player: FarmPlayer) -> bool:
	if is_open or player.selection.is_menu_open():
		return false
	merchant = owner_npc
	customer = player
	bought_this_visit = false
	is_open = true
	customer.shop_interaction.active_shop = self
	customer.selection.set_shop_open(true)
	customer.wallet.changed.connect(_wallet_changed)
	customer.selection.inventory.changed.connect(_inventory_changed)
	show() # CanvasLayer có thể đã bị tắt Visible để soạn map trong editor.
	root.show()
	visit_started.emit()
	_closing = false
	_slide.enter()
	return true

func _wallet_changed(_balance: int) -> void:
	models_changed.emit()

func _inventory_changed() -> void:
	models_changed.emit()

func close(show_thanks: bool = true) -> void:
	if not is_open:
		return
	if show_thanks and is_inside_tree() and not is_queued_for_deletion():
		if not _closing:
			_closing = true
			_slide.leave(_finish_close.bind(show_thanks))
	else:
		_finish_close(show_thanks)

func _finish_close(show_thanks: bool) -> void:
	_slide.stop()
	_closing = false
	is_open = false
	root.hide()
	if is_instance_valid(customer):
		if is_instance_valid(customer.wallet):
			customer.wallet.changed.disconnect(_wallet_changed)
		if is_instance_valid(customer.selection):
			customer.selection.inventory.changed.disconnect(_inventory_changed)
		if is_instance_valid(customer.shop_interaction) and customer.shop_interaction.active_shop == self:
			customer.shop_interaction.active_shop = null
		if is_instance_valid(customer.selection):
			customer.selection.set_shop_open(false)
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
