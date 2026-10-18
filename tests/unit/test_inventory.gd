extends GutTest
const Bag = preload("res://components/inventory_component.gd")
const Item = preload("res://scripts/item_definition.gd")
var bag: Bag
var seed: Item

func before_each() -> void:
	bag = Bag.new()
	bag.starting_tools = false
	bag.slot_count = 4
	add_child_autofree(bag)
	seed = Item.new()
	seed.item_id = &"seed"
	seed.display_name = "Hạt giống"
	seed.item_type = Item.ItemType.SEED
	seed.max_stack = 5

func test_add_fills_existing_stack_before_free_slots() -> void:
	assert_eq(bag.add(seed, 3), 3)
	assert_eq(bag.add(seed, 4), 4)
	assert_eq(bag.slot(0).count, 5)
	assert_eq(bag.slot(1).count, 2)
	assert_eq(bag.count_item(&"seed"), 7)

func test_full_bag_reports_accepted_amount_without_losing_items() -> void:
	assert_eq(bag.add(seed, 25), 20)
	assert_eq(bag.add(seed, 3), 0)
	assert_eq(bag.count_item(&"seed"), 20)

func test_remove_across_stacks_and_clear_empty_slot() -> void:
	bag.add(seed, 8)
	assert_eq(bag.remove(&"seed", 6), 6)
	assert_null(bag.slot(0).item)
	assert_eq(bag.count_item(&"seed"), 2)
	assert_eq(bag.remove(&"seed", 9), 2)
	assert_eq(bag.remove(&"seed", 1), 0)

func test_tools_never_stack() -> void:
	assert_eq(bag.add(Bag.HOE, 3), 3)
	for index: int in range(3):
		assert_eq(bag.slot(index).count, 1)

func test_move_merge_partial_stack_preserves_remainder() -> void:
	bag.add(seed, 8)
	assert_true(bag.move_slot(0, 1))
	assert_eq(bag.slot(0).count, 3)
	assert_eq(bag.slot(1).count, 5)
	assert_eq(bag.count_item(&"seed"), 8)
	assert_false(bag.move_slot(0, 1), "Full stack cannot consume items")

func test_swap_different_items_and_move_to_empty_slot() -> void:
	bag.add(seed, 3)
	bag.add(Bag.HOE)
	assert_true(bag.move_slot(0, 1))
	assert_eq(bag.slot(0).item.item_id, &"hoe")
	assert_eq(bag.slot(1).count, 3)
	assert_true(bag.move_slot(1, 3))
	assert_null(bag.slot(1).item)
	assert_eq(bag.slot(3).count, 3)

func test_invalid_operations_do_not_mutate_or_emit() -> void:
	watch_signals(bag)
	assert_eq(bag.add(null, 4), 0)
	assert_eq(bag.add(seed, -1), 0)
	assert_eq(bag.remove(&"seed", -1), 0)
	assert_false(bag.move_slot(-1, 0))
	assert_false(bag.move_slot(0, 10))
	assert_false(bag.move_slot(0, 0))
	assert_false(bag.move_slot(0, 1))
	assert_signal_not_emitted(bag, "changed")

func test_slot_snapshot_does_not_expose_mutable_storage() -> void:
	bag.add(seed, 3)
	var copy: Dictionary = bag.slot(0)
	copy.count = 999
	assert_eq(bag.slot(0).count, 3)

func test_existing_seed_resources_load_with_crop_metadata() -> void:
	var carrot: Item = load("res://items/seeds/carrot_seed.tres") as Item
	assert_not_null(carrot)
	assert_not_null(carrot.crop)
	assert_eq(bag.add(carrot, 12), 12)
	assert_eq(bag.slot(0).count, 12)

func test_remove_from_slot_spends_only_the_target_stack() -> void:
	bag.add(seed, 8)
	assert_eq(bag.remove_from_slot(1, 1), 1)
	assert_eq(bag.slot(0).count, 5)
	assert_eq(bag.slot(1).count, 2)
	assert_eq(bag.remove_from_slot(1, 99), 2)
	assert_null(bag.slot(1).item)
	assert_eq(bag.remove_from_slot(-1, 1), 0)
	assert_eq(bag.remove_from_slot(0, -1), 0)

func test_capacity_counts_partial_stacks_and_free_slots_without_mutation() -> void:
	watch_signals(bag)
	bag.add(seed, 3)
	assert_eq(bag.capacity_for(seed), 17)
	assert_eq(bag.capacity_for(null), 0)
	assert_eq(bag.slot(0).count, 3)
	assert_signal_emit_count(bag, "changed", 1)
