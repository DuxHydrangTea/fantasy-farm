extends GutTest
const FEED: ItemDefinition = preload("res://items/feeds/poultry_feed.tres")
var trough: AnimalTrough
var inventory: InventoryComponent

func before_each() -> void:
	trough = preload("res://scenes/animals/feed_trough.tscn").instantiate() as AnimalTrough
	add_child_autofree(trough)
	trough.stock = 0
	inventory = InventoryComponent.new()
	inventory.starting_tools = false
	add_child_autofree(inventory)

func test_food_transfers_whole_packages_and_only_spends_accepted_quantity() -> void:
	inventory.add(FEED, 5)
	assert_eq(trough.refill_from_inventory(inventory), 600)
	assert_eq(trough.stock, 600)
	assert_eq(inventory.count_item(FEED.item_id), 3)
	assert_eq(trough.refill_from_inventory(inventory), 0)
	assert_eq(inventory.count_item(FEED.item_id), 3)

func test_feed_never_discards_a_partial_package() -> void:
	trough.stock = 400
	inventory.add(FEED, 1)
	assert_eq(trough.refill_from_inventory(inventory), 0)
	assert_eq(inventory.count_item(FEED.item_id), 1)
	trough.stock = 300
	assert_eq(trough.refill_from_inventory(inventory), 300)
	assert_eq(inventory.count_item(FEED.item_id), 0)

func test_missing_or_wrong_feed_or_invalid_configuration_spends_nothing() -> void:
	inventory.add(preload("res://items/seeds/carrot_seed.tres"), 10)
	assert_eq(trough.refill_from_inventory(inventory), 0)
	inventory.add(FEED, 2)
	trough.kind = AnimalTrough.Kind.WATER
	assert_eq(trough.refill_from_inventory(inventory), 0)
	trough.kind = AnimalTrough.Kind.FOOD
	trough.feed_item = null
	assert_eq(trough.refill_from_inventory(inventory), 0)
	assert_eq(trough.refill_from_inventory(null), 0)
	assert_eq(inventory.count_item(FEED.item_id), 2)

func test_custom_species_feed_is_selected_by_resource_not_hardcoded_id() -> void:
	var hay: ItemDefinition = FEED.duplicate() as ItemDefinition
	hay.item_id = &"hay"
	hay.food_units_per_item = 20
	trough.feed_item = hay
	inventory.add(FEED, 2)
	assert_eq(trough.refill_from_inventory(inventory), 0)
	inventory.add(hay, 3)
	assert_eq(trough.refill_from_inventory(inventory), 60)
	assert_eq(inventory.count_item(FEED.item_id), 2)

func test_reentrant_inventory_notification_cannot_spend_twice() -> void:
	inventory.add(FEED, 4)
	inventory.changed.connect(func() -> void: trough.refill_from_inventory(inventory))
	assert_eq(trough.refill_from_inventory(inventory), 600)
	assert_eq(inventory.count_item(FEED.item_id), 2)

func test_inventory_limit_and_water_overflow_are_respected() -> void:
	inventory.add(FEED, 1)
	assert_eq(trough.refill_from_inventory(inventory), 300)
	trough.kind = AnimalTrough.Kind.WATER
	trough.stock = 590
	assert_eq(trough.refill(trough.water_per_use), 10)
	assert_eq(trough.stock, 600)
