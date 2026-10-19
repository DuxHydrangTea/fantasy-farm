extends GutTest

const WORLD: PackedScene = preload("res://world/main_world.tscn")
const Actor = preload("res://components/animals/animal_actor.gd")
const Pen = preload("res://components/animals/animal_pen.gd")
const Clock = preload("res://components/time_manager.gd")
const Pickup = preload("res://components/item_pickup.gd")
const Inventory = preload("res://components/inventory_component.gd")
const Collector = preload("res://components/item_collector.gd")
const Trough = preload("res://components/animals/animal_trough.gd")
var clock: Clock
var pen: Pen
var timestamp: float = 1000.0

func before_each() -> void:
	timestamp = 1000.0
	clock = Clock.new()
	clock.clock_source = func() -> float: return timestamp
	add_child_autofree(clock)
	clock.set_process(false)
	var world: Node = WORLD.instantiate()
	pen = world.get_node("BarnPen") as Pen
	world.remove_child(pen)
	pen.owner = null
	world.free()
	for child: Node in pen.get_children():
		var actor: Actor = child as Actor
		if actor != null:
			actor.get_node("NeedsComponent").time_manager = clock
	add_child_autofree(pen)

func _advance(seconds: float) -> void:
	timestamp += seconds
	clock.refresh()

func _piles(item_id: StringName) -> Array[Pickup]:
	var piles: Array[Pickup] = []
	for child: Node in pen.get_children():
		var pickup: Pickup = child as Pickup
		if pickup != null and not pickup.is_queued_for_deletion() and pickup.item.item_id == item_id:
			piles.append(pickup)
	return piles

func _amount(item_id: StringName) -> int:
	var amount: int = 0
	for pile: Pickup in _piles(item_id):
		amount += pile.amount
	return amount

func test_barn_has_nine_cows_and_nine_sheep_sharing_one_pen() -> void:
	assert_eq(pen.bounds, Rect2(0, 0, 384, 272))
	assert_eq(pen.position, Vector2(1008, 592))
	var skins: Dictionary[String, int] = {}
	var count: int = 0
	for child: Node in pen.get_children():
		var actor: Actor = child as Actor
		if actor == null:
			continue
		count += 1
		assert_eq(actor.pen, pen)
		assert_eq(actor.wander.pen, pen)
		assert_true(actor.growth.is_adult())
		assert_true(pen.contains_world(actor.global_position, actor.wander.margin))
		assert_true(actor.definition.has_movement_frames(actor.sprite.sprite_frames))
		skins[actor.sprite.sprite_frames.resource_path] = skins.get(actor.sprite.sprite_frames.resource_path, 0) + 1
	assert_eq(count, 18)
	for species: String in ["cow", "sheep"]:
		for index: int in range(1, 10):
			var path: String = "res://sprite_frames/animals/%s_%02d_frames.tres" % [species, index]
			assert_eq(skins.get(path, 0), 1)

func test_real_scene_produces_milk_and_wool_at_sixty_seconds() -> void:
	_advance(59.0)
	assert_eq(_amount(&"cow_milk"), 0)
	assert_eq(_amount(&"sheep_wool"), 0)
	_advance(1.0)
	assert_eq(_amount(&"cow_milk"), 9)
	assert_eq(_amount(&"sheep_wool"), 9)
	_advance(120.0)
	assert_eq(_amount(&"cow_milk"), 27)
	assert_eq(_amount(&"sheep_wool"), 27)
	assert_eq(_piles(&"cow_milk").size(), 9, "Later batches stack without spawning extra piles")
	assert_eq(_piles(&"sheep_wool").size(), 9)
	for item_id: StringName in [&"cow_milk", &"sheep_wool"]:
		for pickup: Pickup in _piles(item_id):
			assert_not_null(pickup.item.icon)
			assert_true(pen.contains_world(pickup.global_position, 14.0))
	clock.refresh()
	assert_eq(_amount(&"cow_milk"), 27, "Repeated timestamps cannot duplicate output")

func test_starving_one_cow_pauses_only_its_own_production() -> void:
	var cow: Actor = pen.get_node("Cow_1") as Actor
	_advance(60.0)
	cow.needs.satiety = 0.0
	_advance(60.0)
	assert_eq(_amount(&"cow_milk"), 17)
	assert_eq(_amount(&"sheep_wool"), 18)
	cow.needs.feed(50.0)
	assert_eq(_amount(&"cow_milk"), 17, "Feeding does not retroactively credit starved time")
	_advance(60.0)
	assert_eq(_amount(&"cow_milk"), 26)
	assert_eq(_amount(&"sheep_wool"), 27)

func test_products_survive_full_inventory_and_can_be_collected_once() -> void:
	_advance(60.0)
	var bag: Inventory = Inventory.new()
	bag.starting_tools = false
	bag.slot_count = 1
	add_child_autofree(bag)
	bag.add(load("res://items/tools/hoe.tres"), 1)
	var milk: Pickup = _piles(&"cow_milk")[0]
	var wool: Pickup = _piles(&"sheep_wool")[0]
	assert_eq(milk.collect(bag), 0)
	assert_eq(milk.amount, 1)
	assert_eq(wool.collect(bag), 0)
	bag.remove(&"hoe", 1)
	assert_eq(milk.collect(bag), 1)
	assert_eq(milk.collect(bag), 0)
	assert_eq(bag.count_item(&"cow_milk"), 1)
	bag.remove(&"cow_milk", 1)
	assert_eq(wool.collect(bag), 1)
	assert_eq(bag.count_item(&"sheep_wool"), 1)

func test_existing_pickup_sensor_collects_both_species_products() -> void:
	_advance(60.0)
	var milk: Pickup = _piles(&"cow_milk")[0]
	var wool: Pickup = _piles(&"sheep_wool")[0]
	var bag: Inventory = Inventory.new()
	bag.starting_tools = false
	add_child_autofree(bag)
	var collector: Collector = Collector.new()
	collector.inventory = bag
	collector.collision_layer = 0
	collector.collision_mask = 8
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 14.0
	collision.shape = shape
	collector.add_child(collision)
	pen.add_child(collector)
	collector.global_position = milk.global_position
	await wait_physics_frames(4)
	assert_eq(bag.count_item(&"cow_milk"), 1)
	collector.global_position = wool.global_position
	await wait_physics_frames(4)
	assert_eq(bag.count_item(&"sheep_wool"), 1)

func test_cow_and_sheep_share_trough_with_independent_reservations() -> void:
	var cow: Actor = pen.get_node("Cow_1") as Actor
	var sheep: Actor = pen.get_node("Sheep_1") as Actor
	var food: Trough = pen.get_node("FeedTrough") as Trough
	var water: Trough = pen.get_node("WaterTrough") as Trough
	assert_eq(food.pen, pen)
	assert_eq(water.pen, pen)
	assert_true(food.can_supply(cow.definition))
	assert_true(food.can_supply(sheep.definition))
	for animal: Actor in [cow, sheep]:
		animal.behaviour.set_physics_process(false)
		animal.needs.satiety = 20.0
	cow.position = Vector2(100, 188)
	sheep.position = Vector2(148, 225)
	await wait_physics_frames(2)
	assert_true(cow.foraging.try_begin())
	assert_true(sheep.foraging.try_begin())
	assert_eq(cow.foraging.target, food)
	assert_eq(sheep.foraging.target, food)
	assert_ne(cow.foraging.target_slot, sheep.foraging.target_slot)
	for animal: Actor in [cow, sheep]:
		animal.global_position = food.access_position(animal.foraging.target_slot)
		assert_gt(animal.foraging.finish(), 0.0)
		animal.foraging.cancel()
	assert_eq(food.stock, 598)
	assert_eq(water.stock, 600)

func test_barn_animals_cannot_use_another_pens_troughs() -> void:
	var other_pen: Pen = Pen.new()
	add_child_autofree(other_pen)
	var station: Trough = preload("res://scenes/animals/feed_trough.tscn").instantiate() as Trough
	station.position = Vector2(200, 150)
	other_pen.add_child(station)
	var cow: Actor = pen.get_node("Cow_1") as Actor
	cow.behaviour.set_physics_process(false)
	cow.needs.satiety = 20.0
	pen.get_node("FeedTrough").stock = 0
	await wait_physics_frames(2)
	assert_false(cow.foraging.try_begin())
	assert_eq(station.stock, 120)

func test_livestock_feed_supply_refills_only_the_barn_feed_trough() -> void:
	var bag: Inventory = Inventory.new()
	bag.starting_tools = false
	add_child_autofree(bag)
	var starter: Pickup = pen.get_node("LivestockFeed") as Pickup
	assert_eq(starter.collect(bag), 5)
	var food: Trough = pen.get_node("FeedTrough") as Trough
	food.stock = 0
	assert_eq(food.refill_from_inventory(bag), 600)
	assert_eq(bag.count_item(&"livestock_feed"), 3)
	assert_eq(food.feed_item.item_id, &"livestock_feed")
