extends GutTest
const STORAGE = preload("res://components/animals/pen_produce_storage.gd")
const EGG: ItemDefinition = preload("res://items/animal_produces/chicken_egg.tres")
const MILK: ItemDefinition = preload("res://items/animal_produces/cow_milk.tres")

func test_capacity_is_shared_across_products_and_overflow_is_not_retained() -> void:
	var store: RefCounted = STORAGE.new()
	assert_eq(store.deposit(EGG, 2800), 2800)
	assert_eq(store.deposit(MILK, 600), 200)
	assert_eq(store.count(), 3000)
	assert_eq(store.free_space(), 0)
	assert_eq(store.deposit(EGG, 10), 0)
	var bag: InventoryComponent = InventoryComponent.new()
	bag.starting_tools = false
	assert_eq(store.collect(bag), 3000)
	assert_eq(store.count(), 0)
	assert_eq(bag.count_item(EGG.item_id), 2800)
	assert_eq(bag.count_item(MILK.item_id), 200)
	assert_eq(store.collect(bag), 0, "Discarded overflow never returns")
	bag.free()

func test_partial_collection_and_callbacks_cannot_lose_or_duplicate_stock() -> void:
	var store: RefCounted = STORAGE.new()
	store.deposit(EGG, 20)
	var bag: InventoryComponent = InventoryComponent.new()
	bag.starting_tools = false
	bag.slot_count = 1
	bag.stack_cap = 7
	var observed: Array = []
	bag.changed.connect(func() -> void:
		observed.append([store.count(), bag.count_item(EGG.item_id), store.collect(bag)]))
	assert_eq(store.collect(bag), 7)
	assert_eq(observed, [[13, 7, 0]], "Callbacks see both committed sides and cannot reenter")
	assert_eq(store.collect(bag), 0)
	assert_eq(store.count(), 13)
	bag.free()

func test_round_trip_preserves_mixed_product_ids_and_counts() -> void:
	var store: RefCounted = STORAGE.new()
	store.deposit(EGG, 12)
	store.deposit(MILK, 8)
	var other: RefCounted = STORAGE.new()
	other.restore(store.capture(), {String(EGG.item_id): EGG, String(MILK.item_id): MILK})
	assert_eq(other.capture(), store.capture())
	assert_eq(other.count(), 20)
	assert_eq(other.free_space(), 2980)
