extends GutTest
const APPLE: ItemDefinition = preload("res://items/trees/apple.tres")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const FEED: ItemDefinition = preload("res://items/feeds/poultry_feed.tres")
const FLOWER: ItemDefinition = preload("res://items/seeds/flower_01_seed.tres")
const PRODUCE: String = "produce_warehouse"
const SUPPLY: String = "farm_supply_storage"
var service: FarmStorageService
var bag: InventoryComponent

func before_each() -> void:
	service = FarmStorageService.new()
	add_child_autofree(service)
	bag = InventoryComponent.new()
	bag.starting_tools = false
	bag.slot_count = 2
	add_child_autofree(bag)

func test_filters_and_transfers_across_both_storages() -> void:
	bag.add(APPLE, 200)
	assert_true(service.transfer(PRODUCE, bag, APPLE.item_id, 123, true).ok)
	assert_eq(bag.count_item(APPLE.item_id), 77)
	assert_eq(service.inventory(PRODUCE).count_item(APPLE.item_id), 123)
	assert_false(service.transfer(SUPPLY, bag, APPLE.item_id, 1, true).ok)
	assert_eq(service.transfer_all(PRODUCE, bag, false).moved, 123)
	bag.remove(APPLE.item_id, 200)
	bag.add(SEED, 24)
	bag.add(FEED, 4)
	assert_eq(service.transfer_all(SUPPLY, bag, true).moved, 28)
	assert_eq(bag.count_item(SEED.item_id), 0)
	assert_false(service.definition(SUPPLY).accepts(FLOWER))
	assert_false(service.definition(SUPPLY).accepts(InventoryComponent.HOE))
	assert_false(service.definition(PRODUCE).accepts(SEED))

func test_full_destination_moves_only_what_fits_and_preserves_remainder() -> void:
	bag.slot_count = 2
	bag.add(APPLE, APPLE.get_stack_limit() * 2 - 2)
	service.inventory(PRODUCE).add(APPLE, 10)
	assert_eq(service.transfer(PRODUCE, bag, APPLE.item_id, 10, false).moved, 2)
	assert_eq(service.inventory(PRODUCE).count_item(APPLE.item_id), 8)
	assert_false(service.transfer_all(PRODUCE, bag, false).ok)
	assert_eq(service.inventory(PRODUCE).count_item(APPLE.item_id), 8)

func test_observers_see_atomic_state_and_cannot_reenter() -> void:
	bag.add(APPLE, 10)
	var observed: Array[int] = []
	bag.changed.connect(func() -> void:
		observed.append(bag.count_item(APPLE.item_id) + service.inventory(PRODUCE).count_item(APPLE.item_id))
		assert_false(service.transfer(PRODUCE, bag, APPLE.item_id, 1, true).ok)
	)
	assert_true(service.transfer(PRODUCE, bag, APPLE.item_id, 6, true).ok)
	assert_eq(observed, [10])

func test_dto_roundtrip_capacity_and_reject_bad_items_counts_or_missing_storage() -> void:
	service.inventory(PRODUCE).add(APPLE, 6)
	var data: Dictionary = service.capture()
	var catalog: SaveCatalog = SaveCatalog.new()
	assert_true(FarmStorageSaveSchema.valid(data, catalog))
	service.restore(data, catalog)
	assert_eq(service.capture(), data)
	var bad: Dictionary = data.duplicate(true)
	bad[PRODUCE].slots[0].count = -1
	assert_false(FarmStorageSaveSchema.valid(bad, catalog))
	bad = data.duplicate(true)
	bad[SUPPLY].slots[0] = {"item": String(APPLE.item_id), "count": 1}
	assert_false(FarmStorageSaveSchema.valid(bad, catalog))
	bad = data.duplicate(true)
	bad.erase(SUPPLY)
	assert_false(FarmStorageSaveSchema.valid(bad, catalog))
	bad = data.duplicate(true)
	bad[PRODUCE].slot_count = 1
	bad[PRODUCE].slots.resize(1)
	assert_true(FarmStorageSaveSchema.valid(bad, catalog))
	service.restore(bad, catalog)
	assert_eq(service.inventory(PRODUCE).slot_count, 1)
	assert_eq(service.inventory(PRODUCE).count_item(APPLE.item_id), 6)

func test_selected_quality_moves_only_that_tier_and_clamps_to_available() -> void:
	bag.add(APPLE, 8, 0)
	bag.add(APPLE, 5, 1)
	bag.add(APPLE, 3, 2)
	assert_eq(service.transfer(PRODUCE, bag, APPLE.item_id, 99, true, 1).moved, 5)
	assert_eq(bag.count_item(APPLE.item_id, 0), 8)
	assert_eq(bag.count_item(APPLE.item_id, 1), 0)
	assert_eq(bag.count_item(APPLE.item_id, 2), 3)
	assert_eq(service.inventory(PRODUCE).count_item(APPLE.item_id, 1), 5)
	assert_eq(service.transfer(PRODUCE, bag, APPLE.item_id, 2, false, 1).moved, 2)
	assert_eq(bag.count_item(APPLE.item_id, 1), 2)
	assert_eq(service.inventory(PRODUCE).count_item(APPLE.item_id, 1), 3)
	assert_false(service.transfer(PRODUCE, bag, APPLE.item_id, 1, true, 4).ok)
	assert_false(service.transfer(PRODUCE, bag, APPLE.item_id, 1, true, -2).ok)
	assert_eq(bag.count_item(APPLE.item_id, -1), 13)

func test_quality_transfer_with_full_target_preserves_other_tiers() -> void:
	var target: InventoryComponent = service.inventory(PRODUCE)
	target.slot_count = 1
	target.add(APPLE, APPLE.get_stack_limit() - 2)
	bag.add(APPLE, 4, 0)
	bag.add(APPLE, 7, 2)
	assert_eq(service.transfer(PRODUCE, bag, APPLE.item_id, 7, true, 2).moved, 2)
	assert_eq(target.count_item(APPLE.item_id, 2), 2)
	assert_eq(bag.count_item(APPLE.item_id, 0), 4)
	assert_eq(bag.count_item(APPLE.item_id, 2), 5)
	assert_false(service.transfer(PRODUCE, bag, APPLE.item_id, 1, true, 2).ok)
	assert_eq(bag.count_item(APPLE.item_id, 2), 5)
