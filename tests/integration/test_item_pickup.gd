extends GutTest
const Pickup = preload("res://components/item_pickup.gd")
const Collector = preload("res://components/item_collector.gd")
const Inventory = preload("res://components/inventory_component.gd")
const Item = preload("res://scripts/item_definition.gd")
var inventory: Inventory
var item: Item

func before_each() -> void:
	inventory = Inventory.new()
	inventory.starting_tools = false
	inventory.slot_count = 1
	add_child_autofree(inventory)
	item = load("res://items/animal_produces/chicken_egg.tres").duplicate() as Item
	item.max_stack = 3

func _pickup(count: int) -> Pickup:
	var pickup: Pickup = preload("res://scenes/objects/item_pickup.tscn").instantiate() as Pickup
	pickup.item = item
	pickup.amount = count
	add_child_autofree(pickup)
	return pickup

func _collector() -> Collector:
	var collector: Collector = Collector.new()
	collector.inventory = inventory
	collector.collision_layer = 0
	collector.collision_mask = 8
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 14.0
	collision.shape = shape
	collector.add_child(collision)
	add_child_autofree(collector)
	return collector

func test_partial_transfer_preserves_remainder_and_full_bag_keeps_item() -> void:
	var pickup: Pickup = _pickup(5)
	assert_eq(pickup.collect(inventory), 3)
	assert_eq(pickup.amount, 2)
	assert_false(pickup.is_queued_for_deletion())
	assert_eq(pickup.collect(inventory), 0)
	assert_eq(pickup.amount, 2)
	inventory.remove(item.item_id, 2)
	assert_eq(pickup.collect(inventory), 2)
	assert_true(pickup.is_queued_for_deletion())

func test_same_frame_and_reentrant_collection_cannot_duplicate_items() -> void:
	var pickup: Pickup = _pickup(2)
	inventory.changed.connect(func() -> void: pickup.collect(inventory))
	assert_eq(pickup.collect(inventory), 2)
	assert_eq(pickup.collect(inventory), 0)
	assert_eq(inventory.count_item(item.item_id), 2)

func test_area_overlap_automatically_collects_into_inventory() -> void:
	_collector()
	var pickup: Pickup = _pickup(2)
	await wait_physics_frames(4)
	assert_eq(inventory.count_item(item.item_id), 2)
	assert_false(is_instance_valid(pickup))

func test_freeing_space_retries_pickup_without_leaving_sensor() -> void:
	inventory.add(item, 3)
	_collector()
	var pickup: Pickup = _pickup(2)
	await wait_physics_frames(4)
	assert_eq(pickup.amount, 2)
	inventory.remove(item.item_id, 2)
	await wait_physics_frames(2)
	assert_eq(inventory.count_item(item.item_id), 3)
	assert_false(is_instance_valid(pickup))

func test_player_scene_binds_collector_to_existing_shared_inventory() -> void:
	var player: Node2D = preload("res://scenes/characters/player.tscn").instantiate() as Node2D
	add_child_autofree(player)
	var collector: Collector = player.get_node("ItemCollector") as Collector
	var shared: Inventory = player.get_node("ToolSelection").get("inventory") as Inventory
	assert_eq(collector.inventory, shared)
	var pickup: Pickup = _pickup(1)
	pickup.global_position = player.global_position
	await wait_physics_frames(4)
	assert_eq(shared.count_item(item.item_id), 1)
	assert_false(is_instance_valid(pickup))
