extends GutTest
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const PICKUP: PackedScene = preload("res://scenes/objects/item_pickup.tscn")
var viewport: SubViewport
var player: FarmPlayer
var bag: InventoryComponent
var collector: ItemCollector
var item: ItemDefinition

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	player = PLAYER.instantiate() as FarmPlayer
	player.position = Vector2(960, 540)
	viewport.add_child(player)
	bag = player.selection.inventory
	collector = player.get_node("ItemCollector") as ItemCollector
	item = load("res://items/animal_produces/chicken_egg.tres").duplicate() as ItemDefinition
	item.max_stack = 3
	await wait_physics_frames(2)

func _pickup(amount: int = 2, offset: Vector2 = Vector2(40, 0)) -> ItemPickup:
	var pickup: ItemPickup = PICKUP.instantiate() as ItemPickup
	pickup.item = item
	pickup.amount = amount
	pickup.position = player.position + offset
	viewport.add_child(pickup)
	return pickup

func _popups() -> Array[ItemGainPopup]:
	var result: Array[ItemGainPopup] = []
	for child: Node in player.item_feedback.get_children():
		if child is ItemGainPopup and child.message.is_empty() and not child.is_queued_for_deletion():
			result.append(child)
	return result

func _fill_bag() -> void:
	bag.add(load("res://items/tools/hoe.tres"), 100)

func test_nearby_drop_flies_before_transfer_and_shows_actual_icon_above_player() -> void:
	var pickup: ItemPickup = _pickup()
	var resting: Vector2 = pickup.position
	await wait_physics_frames(4)
	assert_true(pickup.is_attracting())
	assert_eq(pickup.position, resting, "Persisted pile never moves")
	assert_lt(pickup.sprite.position.x, 0.0)
	assert_eq(bag.count_item(item.item_id), 0)
	assert_eq(_popups().size(), 0)
	await wait_seconds(0.4)
	assert_false(is_instance_valid(pickup))
	assert_eq(bag.count_item(item.item_id), 2)
	assert_eq(_popups().size(), 1)
	var popup: ItemGainPopup = _popups()[0]
	assert_eq(popup.amount, 2)
	assert_eq(popup.label.text, "+2 ×")
	assert_eq(popup.icon.texture, item.icon)
	assert_lt(popup.global_position.y, player.global_position.y - 30)
	var relative: Vector2 = popup.position
	player.position += Vector2(10, 0)
	assert_eq(popup.global_position, player.item_feedback.to_global(relative))
	await wait_seconds(1.0)
	assert_eq(_popups().size(), 0)
	_pickup(1)
	await wait_seconds(0.4)
	assert_eq(_popups().size(), 1, "Expired feedback must not retain a freed node")
	assert_eq(_popups()[0].amount, 1)

func test_partial_capacity_keeps_remainder_and_only_reports_transferred_amount() -> void:
	bag.add(item, 2)
	_fill_bag()
	var pickup: ItemPickup = _pickup(5)
	await wait_seconds(0.4)
	assert_eq(bag.count_item(item.item_id), 3)
	assert_eq(pickup.amount, 4)
	assert_false(pickup.is_attracting())
	assert_eq(pickup.sprite.position, Vector2(0, -6))
	assert_eq(_popups().size(), 1)
	assert_eq(_popups()[0].amount, 1)

func test_full_bag_keeps_drop_still_and_retries_when_space_opens() -> void:
	_fill_bag()
	var pickup: ItemPickup = _pickup(2)
	await wait_seconds(0.35)
	assert_false(pickup.is_attracting())
	assert_eq(pickup.amount, 2)
	assert_eq(_popups().size(), 0)
	bag.remove(&"hoe", 1)
	await wait_seconds(0.4)
	assert_false(is_instance_valid(pickup))
	assert_eq(bag.count_item(item.item_id), 2)
	assert_eq(_popups()[0].amount, 2)

func test_full_bag_during_flight_cancels_without_losing_drop_or_showing_reward() -> void:
	var pickup: ItemPickup = _pickup()
	await wait_physics_frames(4)
	assert_true(pickup.is_attracting())
	_fill_bag()
	await wait_physics_frames(2)
	assert_false(pickup.is_attracting())
	assert_eq(pickup.amount, 2)
	assert_eq(pickup.sprite.position, Vector2(0, -6))
	assert_eq(_popups().size(), 0)

func test_destroyed_collector_resets_visual_and_preserves_quantity() -> void:
	var pickup: ItemPickup = _pickup()
	await wait_physics_frames(4)
	assert_true(pickup.is_attracting())
	collector.free()
	await wait_physics_frames(2)
	assert_eq(pickup.amount, 2)
	assert_eq(pickup.sprite.position, Vector2(0, -6))
	assert_eq(bag.count_item(item.item_id), 0)

func test_flight_tracks_moving_target_and_multiple_drops_merge_only_feedback() -> void:
	_pickup(1, Vector2(40, 0))
	_pickup(2, Vector2(40, 2))
	await wait_physics_frames(4)
	player.position += Vector2(12, 0)
	await wait_seconds(0.5)
	assert_eq(bag.count_item(item.item_id), 3)
	assert_eq(_popups().size(), 1)
	assert_eq(_popups()[0].amount, 3)

func test_inventory_restore_and_shop_purchase_do_not_create_pickup_popups() -> void:
	bag.add(item, 1)
	var stock: ShopCatalog = load("res://resources/shops/farm_supply.tres") as ShopCatalog
	var service: ShopService = ShopService.new(stock, player.wallet, bag)
	assert_true(service.buy(stock.offers[0], 1).ok)
	assert_eq(_popups().size(), 0)

func test_every_animal_produce_flies_and_shows_its_own_icon(species = use_parameters([
	"chicken_egg", "cow_milk", "sheep_wool", "duck_egg", "goose_egg", "pig_truffle", "horse_compost"
])) -> void:
	var item_path: String = "res://items/animal_produces/%s.tres" % species
	item = load(item_path) as ItemDefinition
	var pickup: ItemPickup = _pickup(2)
	await wait_physics_frames(4)
	assert_true(pickup.is_attracting())
	await wait_seconds(0.4)
	assert_false(is_instance_valid(pickup))
	assert_eq(bag.count_item(item.item_id), 2)
	assert_eq(_popups().size(), 1)
	assert_eq(_popups()[0].icon.texture, item.icon)
	assert_eq(_popups()[0].amount, 2)

func test_full_bag_allows_existing_egg_stack_but_reports_blocked_milk_and_wool() -> void:
	bag.add(item, 2)
	_fill_bag()
	item = load("res://items/animal_produces/cow_milk.tres") as ItemDefinition
	var milk: ItemPickup = _pickup(1)
	item = load("res://items/animal_produces/sheep_wool.tres") as ItemDefinition
	var wool: ItemPickup = _pickup(1, Vector2(40, 4))
	await wait_seconds(0.3)
	assert_false(milk.is_attracting())
	assert_false(wool.is_attracting())
	assert_eq(milk.amount, 1)
	assert_eq(wool.amount, 1)
	assert_eq(_popups().size(), 0)
	assert_eq(player.item_feedback.get_child_count(), 1, "One throttled warning, not one per blocked pile")
	assert_eq((player.item_feedback.get_child(0) as ItemGainPopup).message, "Inventory full")
	item = load("res://items/animal_produces/chicken_egg.tres").duplicate() as ItemDefinition
	item.max_stack = 3
	_pickup(1, Vector2(40, -4))
	await wait_seconds(0.4)
	assert_eq(bag.count_item(&"chicken_egg"), 3)
	bag.remove(&"hoe", 2)
	await wait_seconds(0.4)
	assert_false(is_instance_valid(milk))
	assert_false(is_instance_valid(wool))
	assert_eq(bag.count_item(&"cow_milk"), 1)
	assert_eq(bag.count_item(&"sheep_wool"), 1)
