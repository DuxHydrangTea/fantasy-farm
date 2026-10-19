extends GutTest
const Production = preload("res://components/animals/animal_production_component.gd")
const Definition = preload("res://scripts/animals/animal_production_definition.gd")
const Inventory = preload("res://components/inventory_component.gd")
const Item = preload("res://scripts/item_definition.gd")
var production: Production
var data: Definition

func before_each() -> void:
	data = load("res://animals/productions/chicken_egg_production.tres").duplicate() as Definition
	data.production_seconds = 4.0
	data.production_amount = 2
	production = Production.new()
	add_child_autofree(production)
	production.configure(data)

func test_partial_progress_survives_pauses_and_preserves_remainder() -> void:
	assert_eq(production.advance(3.0), 0)
	assert_eq(production.progress_ratio(), 0.75)
	assert_eq(production.advance(0.0), 0)
	assert_eq(production.advance(-10.0), 0)
	assert_eq(production.advance(2.0), 2)
	assert_eq(production.progress_seconds, 1.0)
	assert_eq(production.stored_amount, 2)

func test_large_interval_batches_output_without_looping_per_item() -> void:
	watch_signals(production)
	assert_eq(production.advance(400001.0), 200000)
	assert_eq(production.stored_amount, 200000)
	assert_eq(production.progress_seconds, 1.0)
	assert_signal_emit_count(production, "produced", 1)

func test_missing_or_invalid_definition_produces_nothing() -> void:
	production.configure(null)
	assert_eq(production.advance(100.0), 0)
	assert_eq(production.progress_ratio(), 0.0)
	data.production_seconds = 0.0
	production.configure(data)
	assert_eq(production.advance(100.0), 0)
	assert_eq(production.stored_amount, 0)

func test_take_output_never_overdraws_or_adds_negative_stock() -> void:
	production.advance(8.0)
	assert_eq(production.take_output(-3), 0)
	assert_eq(production.take_output(3), 3)
	assert_eq(production.take_output(100), 1)
	assert_eq(production.stored_amount, 0)

func test_direct_collection_preserves_output_when_inventory_is_full() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.starting_tools = false
	inventory.slot_count = 1
	add_child_autofree(inventory)
	var item: Item = data.production_item.duplicate() as Item
	item.max_stack = 3
	data.production_item = item
	production.advance(8.0)
	assert_eq(production.collect(inventory), 3)
	assert_eq(production.stored_amount, 1)
	assert_eq(production.collect(inventory), 0)
	inventory.remove(item.item_id, 1)
	assert_eq(production.collect(inventory), 1)
	assert_eq(production.stored_amount, 0)
	assert_eq(inventory.count_item(item.item_id), 3)

func test_reentrant_inventory_notifications_cannot_duplicate_output() -> void:
	var inventory: Inventory = Inventory.new()
	inventory.starting_tools = false
	add_child_autofree(inventory)
	inventory.changed.connect(func() -> void: production.collect(inventory))
	production.advance(8.0)
	assert_eq(production.collect(inventory), 4)
	assert_eq(inventory.count_item(data.production_item.item_id), 4)
	assert_eq(production.stored_amount, 0)

func test_components_sharing_one_definition_have_independent_state() -> void:
	var other: Production = Production.new()
	add_child_autofree(other)
	other.configure(data)
	production.advance(5.0)
	assert_eq(other.progress_seconds, 0.0)
	assert_eq(other.stored_amount, 0)
	assert_eq(data.production_seconds, 4.0)
