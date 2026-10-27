extends GutTest
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const MERCHANT: PackedScene = preload("res://scenes/characters/shop_merchant.tscn")
var viewport: SubViewport
var player: FarmPlayer
var merchant: ShopMerchant
var shop: ShopUI

func before_each() -> void:
	Language.set_language("en")
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	player = PLAYER.instantiate() as FarmPlayer
	player.position = Vector2(960, 540)
	viewport.add_child(player)
	player.wallet.set_balance(1000000)
	merchant = MERCHANT.instantiate() as ShopMerchant
	merchant.position = player.position + Vector2(24, 0)
	viewport.add_child(merchant)
	player.animation.face(merchant.interaction_position() - player.global_position)
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
	assert_true(shop.balance_label.visible, "Balance is visible at checkout")
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
	assert_eq(player.wallet.balance, 1000000 - 2 * shop.selected.price)
	_key(KEY_ESCAPE)
	assert_true(merchant.bubble.visible)
	assert_true(merchant.bubble_text.text.contains("Thank you"))
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
	player.wallet.set_balance(1000000)
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
	assert_eq(shop.grid.get_child_count(), merchant.catalog.offers.filter(func(offer: ShopOffer) -> bool: return offer.category == ShopOffer.Category.FEED).size())
	shop.show_category(ShopOffer.Category.FLOWER)
	assert_eq(shop.grid.get_child_count(), 10)
	shop.quantity.value = 99
	player.wallet.set_balance(1000)
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
	assert_true(viewport.get_tree().get_nodes_in_group(&"shop_merchants").has(merchant))
	player.position = merchant.interaction_position() + Vector2(0, 24)
	player.animation.face(merchant.interaction_position() - player.global_position)
	shop = merchant.shop_ui
	_key(KEY_E)
	assert_true(shop.is_open)
	shop.purchase()
	assert_false(merchant.bubble.visible)
	_key(KEY_ESCAPE)
	assert_true(merchant.bubble.visible)

func test_animal_tabs_buy_newborn_then_sell_only_explicitly_selected_animal() -> void:
	var pen: AnimalPen = AnimalPen.new()
	pen.accepted_species = [AnimalTypes.Species.CHICKEN]
	pen.capacity = 2
	viewport.add_child(pen)
	await wait_physics_frames(2)
	assert_true(merchant.open_shop(player))
	assert_eq(shop.categories.get_child_count(), 6)
	shop.show_category(ShopOffer.Category.ANIMAL)
	assert_eq(shop.grid.get_child_count(), 7)
	assert_false(shop.buy_button.disabled)
	shop.purchase()
	assert_eq(player.wallet.balance, 1000000 - merchant.catalog.animal_offers[0].price)
	var actor: AnimalActor = shop.animal_service.owned_animals()[0]
	assert_eq(actor.growth.age_seconds, 0.0)
	shop.show_category(ShopOffer.Category.SELL_ANIMAL)
	assert_eq(shop.grid.get_child_count(), 1)
	assert_true(shop.buy_button.disabled, "Choose a specific animal before selling")
	shop.select_animal(actor)
	assert_false(shop.buy_button.disabled)
	assert_true(shop.details.text.contains("Young"))
	assert_true(shop.details.text.contains("Age 0 min"), "A newborn must not display a rounded-up age")
	shop.purchase()
	assert_eq(player.wallet.balance, 1000000 - merchant.catalog.animal_offers[0].price + floori(merchant.catalog.animal_offers[0].price * 0.5))
	assert_eq(shop.grid.get_child_count(), 0)
	assert_true(shop.buy_button.disabled)
	shop.purchase()
	assert_eq(player.wallet.balance, 1000000 - merchant.catalog.animal_offers[0].price + floori(merchant.catalog.animal_offers[0].price * 0.5), "Another click cannot sell again")
	shop.close()
	assert_true(merchant.bubble.visible)

func test_real_farm_can_buy_all_seven_species_into_configured_pens() -> void:
	merchant.free()
	player.free()
	var world: FarmWorld = load("res://world/main_world.tscn").instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	viewport.add_child(world)
	await wait_physics_frames(4)
	player = world.player
	player.wallet.set_balance(10000000)
	merchant = world.get_node("LaiBuon") as ShopMerchant
	player.position = merchant.interaction_position() + Vector2(0, 24)
	assert_true(merchant.open_shop(player))
	player.animation.face(merchant.interaction_position() - player.global_position)
	shop = merchant.shop_ui
	shop.show_category(ShopOffer.Category.ANIMAL)
	for offer: AnimalShopOffer in merchant.catalog.animal_offers:
		shop.select_animal_offer(offer)
		var before: int = shop.animal_service.owned_animals().size()
		shop.purchase()
		var actors: Array[AnimalActor] = shop.animal_service.owned_animals()
		assert_eq(actors.size(), before + 1, String(offer.animal.animal_id))
		var found: AnimalActor
		for actor: AnimalActor in actors:
			if actor.definition == offer.animal and String(actor.persistent_id).begins_with("animal_"):
				found = actor
		assert_not_null(found)
		if found != null:
			assert_true(found.pen.accepted_species.has(found.definition.species))
			assert_true(found.pen.contains_world(found.global_position, found.wander.margin))
			assert_lt(found.growth.age_seconds, 1.0)
			if found.pen is PondPen:
				assert_false((found.pen as PondPen).is_water(found.global_position))
			if found.definition.species in [AnimalTypes.Species.COW, AnimalTypes.Species.SHEEP, AnimalTypes.Species.PIG, AnimalTypes.Species.HORSE]:
				var food: AnimalTrough = found.pen.get_node("FeedTrough") as AnimalTrough
				assert_true(food.can_supply(found.definition), "Purchased livestock can eat at the existing barn trough")
	var spent: int = 0
	for offer: AnimalShopOffer in merchant.catalog.animal_offers:
		spent += offer.price
	assert_eq(player.wallet.balance, 10000000 - spent)

func test_removed_sale_animal_clears_inspection_and_stale_card_cannot_sell() -> void:
	var pen: AnimalPen = AnimalPen.new()
	pen.accepted_species = [AnimalTypes.Species.CHICKEN]
	viewport.add_child(pen)
	await wait_physics_frames(2)
	merchant.open_shop(player)
	shop.show_category(ShopOffer.Category.ANIMAL)
	shop.purchase()
	var animal: AnimalActor = shop.animal_service.owned_animals()[0]
	shop.show_category(ShopOffer.Category.SELL_ANIMAL)
	shop.select_animal(animal)
	var card: Button = shop.grid.get_child(0) as Button
	animal.free()
	card.pressed.emit()
	assert_null(shop.selected_animal)
	assert_true(shop.buy_button.disabled)
	shop.purchase()
	assert_eq(player.wallet.balance, 1000000 - merchant.catalog.animal_offers[0].price, "A stale selection cannot sell an absent animal")
	shop.show_category(ShopOffer.Category.SELL_ANIMAL)
	assert_eq(shop.grid.get_child_count(), 0)
