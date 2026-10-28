extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var seeds: ShopMerchant
var pets: ShopMerchant
var smith: ShopMerchant
var flowers: ShopMerchant

func before_each() -> void:
	Language.set_language("en")
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(13, 4)
	world.player.wallet.set_balance(10000000)
	seeds = world.get_node("LaiBuon") as ShopMerchant
	pets = world.get_node("PetMerchant") as ShopMerchant
	smith = world.get_node("BlacksmithMerchant") as ShopMerchant
	flowers = world.get_node("FlowerMerchant") as ShopMerchant
	await wait_physics_frames(2)

func after_each() -> void:
	Language.set_language("vi")

func _open(npc: ShopMerchant) -> ShopUI:
	world.player.global_position = npc.interaction_position() + Vector2(0, 24)
	world.player.animation.face(npc.interaction_position() - world.player.global_position)
	assert_true(npc.open_shop(world.player))
	return npc.shop_ui

func test_stock_is_split_without_losing_or_duplicating_existing_items() -> void:
	var offered: Dictionary = {}
	for npc: ShopMerchant in [seeds, flowers, pets, smith]:
		for offer: ShopOffer in npc.catalog.offers:
			assert_false(offered.has(offer.item.item_id), String(offer.item.item_id))
			offered[offer.item.item_id] = offer.price
	var original: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	for offer: ShopOffer in original.offers:
		assert_eq(offered.get(offer.item.item_id), offer.price, "Keep the original price and item")
	assert_true(offered.has(&"hoe"))
	assert_true(offered.has(&"watering_can"))
	assert_true(seeds.catalog.animal_offers.is_empty())
	assert_true(smith.catalog.animal_offers.is_empty())
	assert_eq(pets.catalog.animal_offers.size(), 7)

func test_each_npc_opens_its_own_tabs_and_rejects_other_shop_categories() -> void:
	for npc: ShopMerchant in [seeds, flowers, pets, smith]:
		var shop: ShopUI = _open(npc)
		assert_eq(shop.heading.text, npc.catalog.display_name)
		assert_eq(shop.category, npc.catalog.category_ids[0])
		for id: int in shop._category_tabs:
			assert_eq(shop._category_tabs[id].visible, id in npc.catalog.category_ids)
		for id: int in [0, 1, 2, 3, 4, 5, 6]:
			var previous: int = shop.category
			shop.show_category(id)
			assert_eq(shop.category, id if id in npc.catalog.category_ids else previous)
		shop.close(false)
		assert_false(world.player.selection.shop_open)

func test_seed_purchase_animal_purchase_sale_and_tool_purchase_use_separate_vendors() -> void:
	var shop: ShopUI = _open(seeds)
	var offer: ShopOffer = shop.selected
	var amount: int = world.player.selection.inventory.count_item(offer.item.item_id)
	shop.purchase()
	assert_eq(world.player.selection.inventory.count_item(offer.item.item_id), amount + 1)
	var selection: ShopOffer = shop.selected
	shop.select_offer(smith.catalog.offers[0])
	assert_eq(shop.selected, selection, "A foreign offer cannot replace the inspected product")
	assert_false(shop.service.quote(smith.catalog.offers[0], 1).ok)
	shop.close(false)
	shop = _open(pets)
	var count: int = shop.animal_service.owned_animals().size()
	shop.purchase()
	var animals: Array[AnimalActor] = shop.animal_service.owned_animals()
	assert_eq(animals.size(), count + 1)
	var newborn: AnimalActor
	for animal: AnimalActor in animals:
		if String(animal.persistent_id).begins_with("animal_"):
			newborn = animal
	assert_not_null(newborn)
	shop.show_category(ShopOffer.Category.SELL_ANIMAL)
	shop.select_animal(newborn)
	shop.purchase()
	assert_eq(shop.animal_service.owned_animals().size(), count)
	shop.close(false)
	shop = _open(smith)
	assert_eq(shop.grid.get_child_count(), 3)
	offer = shop.selected
	amount = world.player.selection.inventory.count_item(offer.item.item_id)
	shop.purchase()
	assert_eq(world.player.selection.inventory.count_item(offer.item.item_id), amount + 1)
	shop.show_category(ShopUI.UPGRADES)
	assert_eq(shop.grid.get_child_count(), 3)
	assert_false(shop.quantity.visible)
	shop.purchase()
	assert_eq(world.tool_upgrade_state.level(&"hoe"), 2)
	shop.close(false)

func test_npcs_have_distinct_visuals_are_nearby_and_can_be_reached_from_the_path() -> void:
	var frames: Dictionary = {}
	for npc: ShopMerchant in [seeds, flowers, pets, smith]:
		var visual: AnimatedSprite2D = npc.interaction_sprite() as AnimatedSprite2D
		assert_false(frames.has(visual.sprite_frames))
		frames[visual.sprite_frames] = true
		assert_lt(npc.global_position.distance_to(pets.global_position), 700.0)
		world.player.global_position = npc.interaction_position() + Vector2(0, 24)
		await wait_physics_frames(2)
		assert_eq(world.player.shop_interaction.nearest_merchant(), npc)
		var target: InteractionTarget = InteractionTarget.new(npc, InteractionTarget.Kind.MERCHANT, world.player)
		assert_true(target.reachable_from(world.player.global_position), "No shop building blocks its NPC")

func test_shop_titles_translate_and_compact_tabs_stay_restricted() -> void:
	Language.set_language("vi")
	for npc: ShopMerchant in [seeds, flowers, pets, smith]:
		var shop: ShopUI = _open(npc)
		assert_ne(shop.heading.text, npc.catalog.display_name)
		shop.root.size = Vector2(667, 375)
		shop._fit_layout()
		assert_true(shop._compact)
		assert_eq(shop.category, npc.catalog.category_ids[0])
		assert_eq(shop.categories.get_child(0), shop._category_tabs[npc.catalog.category_ids[0]])
		shop.close(false)

func test_interaction_prompts_name_each_shop_and_update_language() -> void:
	var shops: Array[ShopMerchant] = [seeds, flowers, pets, smith]
	var english: Array[String] = ["Seed shop", "Flower shop", "Animal shop", "Tool shop"]
	var vietnamese: Array[String] = ["Cửa hàng hạt giống", "Cửa hàng bán hoa", "Cửa hàng vật nuôi", "Cửa hàng nông cụ"]
	for index: int in range(shops.size()):
		var npc: ShopMerchant = shops[index]
		assert_eq(npc.interaction_action_text(), english[index])
		assert_eq(npc.prompt.text, "[E] " + english[index])
		var target: InteractionTarget = InteractionTarget.new(npc, InteractionTarget.Kind.MERCHANT, world.player)
		world.player.interactions.presenter.show_target(target, false)
		assert_eq(world.player.interactions.presenter.label.text, english[index])
	Language.set_language("vi")
	for index: int in range(shops.size()):
		var npc: ShopMerchant = shops[index]
		assert_eq(npc.interaction_action_text(), vietnamese[index])
		assert_eq(npc.prompt.text, "[E] " + vietnamese[index])
		var target: InteractionTarget = InteractionTarget.new(npc, InteractionTarget.Kind.MERCHANT, world.player)
		world.player.interactions.presenter.show_target(target, false)
		assert_eq(world.player.interactions.presenter.label.text, vietnamese[index])

func test_flowers_can_only_be_bought_from_the_new_flower_merchant() -> void:
	assert_false(ShopOffer.Category.FLOWER in seeds.catalog.category_ids)
	for offer: ShopOffer in seeds.catalog.offers:
		assert_ne(offer.category, ShopOffer.Category.FLOWER)
	assert_eq(flowers.catalog.category_ids, [ShopOffer.Category.FLOWER])
	assert_eq(flowers.catalog.offers.size(), 30)
	var shop: ShopUI = _open(flowers)
	assert_eq(shop.grid.get_child_count(), 30)
	var offer: ShopOffer = shop.selected
	var count: int = world.player.selection.inventory.count_item(offer.item.item_id)
	var coins: int = world.player.wallet.balance
	shop.purchase()
	assert_eq(world.player.selection.inventory.count_item(offer.item.item_id), count + 1)
	assert_eq(world.player.wallet.balance, coins - offer.price)
	shop.close(false)
	shop = _open(seeds)
	assert_false(shop.service.quote(offer, 1).ok)
	shop.show_category(ShopOffer.Category.FLOWER)
	assert_eq(shop.category, ShopOffer.Category.CROP)
	shop.close(false)
