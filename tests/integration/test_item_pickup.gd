extends GutTest
var inventory: InventoryComponent
var item: ItemDefinition

func before_each() -> void:
	inventory = InventoryComponent.new()
	inventory.starting_tools = false
	inventory.slot_count = 1
	add_child_autofree(inventory)
	item = load("res://items/animal_produces/chicken_egg.tres").duplicate() as ItemDefinition
	item.max_stack = 3

func _pickup(count: int) -> ItemPickup:
	var pickup: ItemPickup = preload("res://scenes/objects/item_pickup.tscn").instantiate() as ItemPickup
	pickup.item = item
	pickup.amount = count
	add_child_autofree(pickup)
	return pickup

func _collector() -> ItemCollector:
	var collector: ItemCollector = ItemCollector.new()
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
	var pickup: ItemPickup = _pickup(5)
	assert_eq(pickup.collect(inventory), 3)
	assert_eq(pickup.amount, 2)
	assert_false(pickup.is_queued_for_deletion())
	assert_eq(pickup.collect(inventory), 0)
	assert_eq(pickup.amount, 2)
	inventory.remove(item.item_id, 2)
	assert_eq(pickup.collect(inventory), 2)
	assert_true(pickup.is_queued_for_deletion())

func test_animal_produce_hides_world_quantity_even_after_stacking_and_collection(species = use_parameters([
	"chicken_egg", "duck_egg", "goose_egg", "cow_milk", "sheep_wool", "pig_truffle", "horse_compost"
])) -> void:
	var item_path: String = "res://items/animal_produces/%s.tres" % species
	item = load(item_path).duplicate() as ItemDefinition
	item.max_stack = 3
	var pickup: ItemPickup = _pickup(5)
	var label: Label = pickup.get_node("Quantity") as Label
	assert_false(label.visible)
	pickup.add_amount(2)
	assert_false(label.visible)
	assert_eq(pickup.collect(inventory), 3)
	assert_eq(pickup.amount, 4)
	assert_false(label.visible)
	assert_eq(inventory.count_item(item.item_id), 3)

func test_other_world_pickups_still_show_stack_quantity() -> void:
	item = load("res://items/feeds/poultry_feed.tres") as ItemDefinition
	var pickup: ItemPickup = _pickup(5)
	var label: Label = pickup.get_node("Quantity") as Label
	assert_true(label.visible)
	assert_eq(label.text, "5")

func test_same_frame_and_reentrant_collection_cannot_duplicate_items() -> void:
	var pickup: ItemPickup = _pickup(2)
	inventory.changed.connect(func() -> void: pickup.collect(inventory))
	assert_eq(pickup.collect(inventory), 2)
	assert_eq(pickup.collect(inventory), 0)
	assert_eq(inventory.count_item(item.item_id), 2)

func test_area_overlap_automatically_collects_into_inventory() -> void:
	_collector()
	var pickup: ItemPickup = _pickup(2)
	await wait_physics_frames(4)
	assert_eq(inventory.count_item(item.item_id), 2)
	assert_false(is_instance_valid(pickup))

func test_freeing_space_retries_pickup_without_leaving_sensor() -> void:
	inventory.add(item, 3)
	_collector()
	var pickup: ItemPickup = _pickup(2)
	await wait_physics_frames(4)
	assert_eq(pickup.amount, 2)
	inventory.remove(item.item_id, 2)
	await wait_physics_frames(2)
	assert_eq(inventory.count_item(item.item_id), 3)
	assert_false(is_instance_valid(pickup))

func test_player_scene_binds_collector_to_existing_shared_inventory() -> void:
	var player: Node2D = preload("res://scenes/characters/player.tscn").instantiate() as Node2D
	add_child_autofree(player)
	var collector: ItemCollector = player.get_node("ItemCollector") as ItemCollector
	var shared: InventoryComponent = player.get_node("ToolSelection").get("inventory") as InventoryComponent
	assert_eq(collector.inventory, shared)
	var pickup: ItemPickup = _pickup(1)
	pickup.global_position = player.global_position
	await wait_physics_frames(4)
	assert_eq(shared.count_item(item.item_id), 1)
	assert_false(is_instance_valid(pickup))
