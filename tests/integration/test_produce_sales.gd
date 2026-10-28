extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const BUYER: PackedScene = preload("res://scenes/characters/produce_buyer.tscn")
var viewport: SubViewport
var player: FarmPlayer
var buyer: ShopMerchant
var menu: ProduceSalesUI
var carrot: ItemDefinition = load("res://items/harvest_produces/carrot_produces.tres") as ItemDefinition
var milk: ItemDefinition = load("res://items/animal_produces/cow_milk.tres") as ItemDefinition

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(500, 281)
	viewport.size_2d_override = Vector2i(1920, 1080)
	viewport.size_2d_override_stretch = true
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	player = PLAYER.instantiate() as FarmPlayer
	viewport.add_child(player)
	player.wallet.set_balance(1000)
	buyer = BUYER.instantiate() as ShopMerchant
	buyer.position = Vector2(24, 0)
	viewport.add_child(buyer)
	menu = buyer.menu as ProduceSalesUI
	player.selection.inventory.add(carrot, 120)
	player.selection.inventory.add(milk, 2)
	await wait_process_frames(4)

func after_each() -> void:
	Language.set_language("en")
	await wait_process_frames(2)

func _click(control: Control) -> void:
	var position: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(event, true)
	event.pressed = false
	event.button_mask = 0
	viewport.push_input(event, true)

func _pixels(control: Control) -> Rect2:
	return viewport.get_stretch_transform() * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func test_entered_quantity_commits_text_and_sell_all_sells_other_types() -> void:
	assert_true(buyer.open_shop(player))
	assert_true(menu.balance_label.visible, "New header shows the current wallet balance")
	assert_eq(player.shop_interaction.active_shop, menu)
	assert_true(player.selection.shop_open)
	assert_eq(menu.row_buttons.size(), 2)
	menu.quantity.get_line_edit().text = "105"
	menu.sell_quantity()
	assert_eq(player.selection.inventory.count_item(carrot.item_id), 15)
	assert_eq(player.wallet.balance, 1000 + menu.catalog.find(carrot.item_id).price * 105)
	assert_string_contains(menu.status.text, "105")
	menu.sell_all()
	assert_eq(player.wallet.balance, 1000 + menu.catalog.find(carrot.item_id).price * 120 + menu.catalog.find(milk.item_id).price * 2)
	assert_eq(player.selection.inventory.count_item(carrot.item_id), 0)
	assert_eq(player.selection.inventory.count_item(milk.item_id), 0)
	assert_eq(player.selection.inventory.count_item(&"hoe"), 1)
	assert_eq(player.selection.inventory.count_item(&"watering_can"), 1)
	assert_gt(player.selection.inventory.count_item(&"carrot_seed"), 0)
	assert_true(menu.sell_all_button.disabled)
	assert_true(menu.sell_quantity_button.disabled)
	menu.sell_all()
	assert_eq(player.wallet.balance, 1000 + menu.catalog.find(carrot.item_id).price * 120 + menu.catalog.find(milk.item_id).price * 2)
	menu.close()
	assert_false(player.selection.shop_open)
	assert_true(buyer.bubble.visible)

func test_over_quantity_rejected_and_menu_close_for_load_or_removal_releases_lock() -> void:
	buyer.open_shop(player)
	menu.quantity.value = 121
	assert_true(menu.sell_quantity_button.disabled)
	menu.sell_quantity()
	assert_eq(player.wallet.balance, 1000)
	assert_eq(player.selection.inventory.count_item(carrot.item_id), 120)
	player.shop_interaction.close_for_load()
	assert_false(menu.is_open)
	assert_false(buyer.bubble.visible)
	buyer.open_shop(player)
	buyer.free()
	assert_false(player.selection.shop_open)
	assert_null(player.shop_interaction.active_shop)

func test_english_vietnamese_resize_and_physical_clicks_preserve_selected_quantity() -> void:
	buyer.open_shop(player)
	menu._select_index(1)
	menu.quantity.value = 2
	var chosen: ProducePrice = menu.selected
	Language.set_language("vi")
	viewport.size = Vector2i(1000, 562)
	await wait_process_frames(4)
	assert_eq(menu.selected, chosen)
	assert_eq(menu.quantity.value, 2.0)
	assert_string_contains((menu.get_node("%ProductName") as Label).text, "Sữa bò")
	Language.set_language("en")
	viewport.size = Vector2i(500, 281)
	await wait_process_frames(4)
	assert_eq(menu.selected, chosen)
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size))
	for control: Control in [menu.panel, menu.close_button, menu.sell_quantity_button, menu.sell_all_button]:
		assert_true(bounds.encloses(_pixels(control)), str(_pixels(control)))
	_click(menu.sell_quantity_button)
	assert_eq(player.wallet.balance, 1000 + menu.catalog.find(milk.item_id).price * 2)
	assert_eq(player.selection.inventory.count_item(carrot.item_id), 120)
	_click(menu.close_button)
	assert_false(menu.is_open)

func test_relocated_produce_buyer_and_seed_merchant_open_their_own_menus() -> void:
	buyer.free()
	player.free()
	var world: FarmWorld = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	viewport.add_child(world)
	var merchant: ShopMerchant = world.get_node("LaiBuon") as ShopMerchant
	buyer = world.get_node("ProduceBuyer") as ShopMerchant
	player = world.player
	menu = buyer.menu as ProduceSalesUI
	assert_eq(buyer.scene_file_path, "res://scenes/characters/produce_buyer.tscn")
	assert_true((buyer.interaction_sprite().global_position - buyer.global_position).is_equal_approx(Vector2(0, -9)))
	assert_true(((buyer.get_node("CollisionShape2D") as CollisionShape2D).global_position - buyer.global_position).is_equal_approx(Vector2(-1, -5)))
	assert_eq(buyer.interaction_position(), buyer.global_position)
	assert_gt(buyer.interaction_position().distance_to(merchant.interaction_position()), 48.0)
	player.position = buyer.interaction_position() + Vector2(0, 24)
	await wait_physics_frames(2)
	assert_true(InteractionTarget.new(buyer, InteractionTarget.Kind.MERCHANT, player).reachable_from(player.global_position))
	assert_eq(player.shop_interaction.nearest_merchant(), buyer)
	assert_true(player.shop_interaction.try_interact())
	assert_true(menu.is_open)
	menu.close()
	player.position = merchant.interaction_position() + Vector2(0, 24)
	assert_eq(player.shop_interaction.nearest_merchant(), merchant)
	assert_true(player.shop_interaction.try_interact())
	assert_true(merchant.menu is ShopUI)
	assert_true(merchant.menu.is_open)

func test_quality_tabs_maximum_and_bulk_sale_keep_other_qualities() -> void:
	player.selection.inventory.add(carrot, 7, 1)
	player.selection.inventory.add(milk, 3, 1)
	buyer.open_shop(player)
	menu._choose_tier(1)
	assert_true(menu.quality_tabs[1].button_pressed)
	assert_eq(menu.row_buttons.size(), 2)
	assert_eq(menu.service.quantity(menu.selected), 7)
	menu._set_maximum()
	assert_eq(int(menu.quantity.value), 7)
	var before: int = player.wallet.balance
	var expected: int = ItemQuality.unit_price(menu.catalog.find(carrot.item_id).price, 1) * 7
	menu.sell_quantity()
	assert_eq(player.wallet.balance, before + expected)
	assert_eq(player.selection.inventory.count_item(carrot.item_id, 0), 120)
	assert_eq(player.selection.inventory.count_item(carrot.item_id, 1), 0)
	menu.sell_all()
	assert_eq(player.selection.inventory.count_item(milk.item_id, 1), 0)
	assert_eq(player.selection.inventory.count_item(milk.item_id, 0), 2)
	assert_true((menu.get_node("%Empty") as Label).visible)
	assert_true(menu.sell_quantity_button.disabled)
	assert_true(menu.sell_all_button.disabled)
	menu._choose_tier(0)
	assert_eq(menu.row_buttons.size(), 2)
	assert_false(menu.sell_all_button.disabled)

func test_maximum_respects_wallet_room_and_bulk_overflow_does_not_sell() -> void:
	buyer.open_shop(player)
	var unit: int = menu.selected.price
	player.wallet.set_balance(WalletComponent.MAX_COINS - unit * 3)
	menu._set_maximum()
	assert_eq(int(menu.quantity.value), 3)
	assert_true(menu.sell_all_button.disabled)
	menu.sell_all()
	assert_eq(player.selection.inventory.count_item(carrot.item_id), 120)
	menu.sell_quantity()
	assert_eq(player.wallet.balance, WalletComponent.MAX_COINS)
	assert_eq(player.selection.inventory.count_item(carrot.item_id), 117)
	assert_true((menu.get_node("%Maximum") as Button).disabled)
	assert_true(menu.sell_quantity_button.disabled)

func test_empty_quality_and_live_inventory_updates_restore_rows() -> void:
	buyer.open_shop(player)
	menu._choose_tier(2)
	assert_eq(menu.row_buttons.size(), 0)
	assert_true((menu.get_node("%Empty") as Label).visible)
	assert_false(menu.quantity.editable)
	player.selection.inventory.add(carrot, 2, 2)
	assert_eq(menu.row_buttons.size(), 1)
	assert_false((menu.get_node("%Empty") as Label).visible)
	assert_true(menu.quantity.editable)
	menu._set_maximum()
	assert_eq(int(menu.quantity.value), 2)
