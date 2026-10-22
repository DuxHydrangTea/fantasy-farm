extends GutTest
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
	assert_false(menu.balance_label.visible, "Sales show quotes, not the player balance")
	assert_eq(player.shop_interaction.active_shop, menu)
	assert_true(player.selection.shop_open)
	assert_eq(menu.items.item_count, 2)
	menu.quantity.get_line_edit().text = "105"
	menu.sell_quantity()
	assert_eq(player.selection.inventory.count_item(carrot.item_id), 15)
	assert_eq(player.wallet.balance, 1525)
	assert_string_contains(menu.status.text, "105")
	menu.sell_all()
	assert_eq(player.wallet.balance, 1648)
	assert_eq(player.selection.inventory.count_item(carrot.item_id), 0)
	assert_eq(player.selection.inventory.count_item(milk.item_id), 0)
	assert_eq(player.selection.inventory.count_item(&"hoe"), 1)
	assert_eq(player.selection.inventory.count_item(&"watering_can"), 1)
	assert_gt(player.selection.inventory.count_item(&"carrot_seed"), 0)
	assert_true(menu.sell_all_button.disabled)
	assert_true(menu.sell_quantity_button.disabled)
	menu.sell_all()
	assert_eq(player.wallet.balance, 1648)
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
	assert_string_contains(menu.details.text, "Sữa bò")
	Language.set_language("en")
	viewport.size = Vector2i(500, 281)
	await wait_process_frames(4)
	assert_eq(menu.selected, chosen)
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size))
	for control: Control in [menu.panel, menu.close_button, menu.sell_quantity_button, menu.sell_all_button]:
		assert_true(bounds.encloses(_pixels(control)), str(_pixels(control)))
	_click(menu.sell_quantity_button)
	assert_eq(player.wallet.balance, 1048)
	assert_eq(player.selection.inventory.count_item(carrot.item_id), 120)
	_click(menu.close_button)
	assert_false(menu.is_open)

func test_npc_is_sixteen_pixels_beside_laibuon_and_nearest_npc_opens_correct_menu() -> void:
	buyer.free()
	player.free()
	var world: FarmWorld = (load("res://world/main_world.tscn") as PackedScene).instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	viewport.add_child(world)
	var merchant: ShopMerchant = world.get_node("LaiBuon") as ShopMerchant
	buyer = world.get_node("ProduceBuyer") as ShopMerchant
	player = world.player
	menu = buyer.menu as ProduceSalesUI
	assert_eq(buyer.interaction_position() - merchant.interaction_position(), Vector2(16, 0))
	player.position = buyer.interaction_position() + Vector2(0, 24)
	assert_eq(player.shop_interaction.nearest_merchant(), buyer)
	assert_true(player.shop_interaction.try_interact())
	assert_true(menu.is_open)
	menu.close()
	player.position = merchant.interaction_position() + Vector2(0, 24)
	assert_eq(player.shop_interaction.nearest_merchant(), merchant)
	assert_true(player.shop_interaction.try_interact())
	assert_true(merchant.menu is ShopUI)
	assert_true(merchant.menu.is_open)
