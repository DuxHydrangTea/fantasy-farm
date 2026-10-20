extends GutTest
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const MERCHANT: PackedScene = preload("res://scenes/characters/shop_merchant.tscn")
var viewport: SubViewport
var player: FarmPlayer
var merchant: ShopMerchant
var shop: ShopUI

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	player = PLAYER.instantiate() as FarmPlayer
	player.position = Vector2(960, 540)
	viewport.add_child(player)
	merchant = MERCHANT.instantiate() as ShopMerchant
	merchant.position = player.position + Vector2(24, 0)
	viewport.add_child(merchant)
	shop = merchant.shop_ui
	await wait_physics_frames(3)

func after_each() -> void:
	Input.action_release(&"move_right")

func _key(code: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	viewport.push_input(event, true)
	event.pressed = false
	viewport.push_input(event, true)

func test_e_opens_shop_instead_of_tool_and_menu_blocks_world_and_inventory() -> void:
	_key(KEY_E)
	assert_true(shop.is_open)
	assert_true(player.selection.shop_open)
	assert_false(player.selection.inventory_open)
	assert_eq(player.state.current_state, StateComponent.State.IDLE)
	assert_eq(shop.grid.get_child_count(), 22)
	var start: Vector2 = player.position
	Input.action_press(&"move_right")
	_key(KEY_SPACE)
	await wait_physics_frames(4)
	assert_eq(player.position, start)
	assert_eq(player.state.current_state, StateComponent.State.IDLE)
	_key(KEY_TAB)
	assert_false(shop.is_open)
	assert_false(player.selection.inventory_open)
	assert_false(player.selection.shop_open)

func test_thanks_only_after_successful_purchase_and_close_and_resets_per_visit() -> void:
	assert_true(merchant.open_shop(player))
	shop.quantity.value = 2
	shop.purchase()
	assert_true(shop.bought_this_visit)
	assert_false(merchant.bubble.visible)
	assert_eq(player.wallet.balance, 980)
	_key(KEY_ESCAPE)
	assert_true(merchant.bubble.visible)
	assert_true(merchant.bubble_text.text.contains("Cảm ơn"))
	assert_true(merchant.open_shop(player))
	assert_false(merchant.bubble.visible)
	shop.close()
	assert_false(merchant.bubble.visible)

func test_failed_purchase_and_load_close_have_no_thanks() -> void:
	merchant.open_shop(player)
	player.wallet.set_balance(0)
	assert_true(shop.buy_button.disabled)
	shop.purchase()
	assert_false(shop.bought_this_visit)
	shop.close()
	assert_false(merchant.bubble.visible)
	player.wallet.set_balance(1000)
	merchant.open_shop(player)
	shop.purchase()
	player.shop_interaction.close_for_load()
	assert_false(shop.is_open)
	assert_false(merchant.bubble.visible)
	assert_false(player.selection.is_menu_open())

func test_range_categories_and_checkout_revalidation() -> void:
	player.position += Vector2(200, 0)
	assert_false(player.shop_interaction.try_interact())
	player.position = merchant.position + Vector2(24, 0)
	assert_true(player.shop_interaction.try_interact())
	shop.show_category(ShopOffer.Category.FEED)
	assert_eq(shop.grid.get_child_count(), 2)
	shop.show_category(ShopOffer.Category.FLOWER)
	assert_eq(shop.grid.get_child_count(), 10)
	shop.quantity.value = 99
	assert_true(shop.buy_button.disabled)
	shop.purchase()
	assert_eq(player.wallet.balance, 1000)
	assert_false(shop.bought_this_visit)

func test_shop_panel_is_inside_full_hd_viewport() -> void:
	merchant.open_shop(player)
	await wait_process_frames(3)
	assert_true(Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(shop.panel.get_global_rect()))
	assert_gt(shop.panel.size.y, 500.0)

func test_removing_merchant_releases_modal_lock() -> void:
	merchant.open_shop(player)
	merchant.free()
	assert_false(player.selection.shop_open)
	assert_null(player.shop_interaction.active_shop)

func test_main_world_attaches_shop_to_existing_laibuon_at_sprite_position() -> void:
	merchant.free()
	player.free()
	var world: FarmWorld = load("res://world/main_world.tscn").instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	viewport.add_child(world)
	player = world.player
	merchant = world.get_node("LaiBuon") as ShopMerchant
	assert_not_null(merchant)
	assert_false(world.has_node("SeedMerchant"))
	assert_eq(merchant.position, Vector2(1779, 214))
	assert_eq((merchant.get_node("AnimatedSprite2D") as Node2D).position, Vector2(-38, 1))
	assert_eq((merchant.get_node("CollisionShape2D") as Node2D).position, Vector2(-39, 6))
	assert_eq(merchant.interaction_position(), Vector2(1741, 224))
	assert_eq(viewport.get_tree().get_nodes_in_group(&"shop_merchants").size(), 1)
	player.position = merchant.interaction_position() + Vector2(0, 24)
	shop = merchant.shop_ui
	_key(KEY_E)
	assert_true(shop.is_open)
	shop.purchase()
	assert_false(merchant.bubble.visible)
	_key(KEY_ESCAPE)
	assert_true(merchant.bubble.visible)
