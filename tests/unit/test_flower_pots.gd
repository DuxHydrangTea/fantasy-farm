extends GutTest
const POT: PackedScene = preload("res://scenes/flowers/flower_pot.tscn")
const Pot = preload("res://components/flowers/flower_pot.gd")
const Bag = preload("res://components/inventory_component.gd")
const Item = preload("res://scripts/item_definition.gd")
var pot: Pot
var bag: Bag
var seed: Item

func before_each() -> void:
	pot = POT.instantiate() as Pot
	add_child_autofree(pot)
	bag = Bag.new()
	bag.starting_tools = false
	bag.slot_count = 2
	add_child_autofree(bag)
	seed = load("res://items/seeds/flower_01_seed.tres") as Item
	bag.add(seed, 3)

func test_all_ten_flowers_have_five_stages_and_six_frames_each() -> void:
	for index: int in range(1, 11):
		var path: String = "res://items/seeds/flower_%02d_seed.tres" % index
		var item: Item = load(path) as Item
		assert_true(item.crop.is_valid())
		assert_eq(item.crop.stage_frames.size(), 5)
		for stage: SpriteFrames in item.crop.stage_frames:
			assert_eq(stage.get_frame_count(&"grow"), 6)
		assert_eq(item.crop.harvest_item.item_type, Item.ItemType.PRODUCE)

func test_plant_spends_one_seed_once_and_rejects_other_crops() -> void:
	assert_false(pot.can_plant(load("res://items/seeds/carrot_seed.tres")))
	assert_true(pot.plant(bag, 0, 1000.0))
	assert_false(pot.plant(bag, 0, 1000.0))
	assert_eq(bag.count_item(seed.item_id), 2)
	assert_eq(pot.stage, 0)
	assert_true(pot.can_water())

func test_waiting_for_water_does_not_grow_even_offline() -> void:
	pot.plant(bag, 0, 1000.0)
	pot.refresh(100000.0)
	assert_eq(pot.progress, 0.0)
	assert_eq(pot.stage, 0)
	assert_false(pot.is_mature())

func test_water_starts_clock_once_and_five_stages_follow_timestamp() -> void:
	pot.plant(bag, 0, 1000.0)
	assert_true(pot.water(1010.0))
	assert_false(pot.water(1020.0))
	assert_eq(pot.growth_started_at, 1010.0)
	for stage: int in range(5):
		pot.refresh(1010.0 + stage * 30.0)
		assert_eq(pot.stage, stage)
		assert_eq(pot.sprite.sprite_frames, seed.crop.stage_frames[stage])
	assert_true(pot.is_mature())

func test_harvest_preserves_full_pot_when_bag_full_then_returns_empty_once() -> void:
	pot.plant(bag, 0, 1000.0)
	pot.water(1000.0)
	pot.refresh(1120.0)
	bag.add(load("res://items/tools/hoe.tres"), 1)
	assert_false(pot.harvest(bag))
	assert_true(pot.is_mature())
	bag.remove(seed.item_id, 2)
	assert_true(pot.harvest(bag))
	assert_false(pot.harvest(bag))
	assert_eq(bag.count_item(&"flower_01"), 1)
	assert_null(pot.definition)
	assert_eq(pot.sprite.sprite_frames, pot.empty_frames)
	assert_false(pot.can_water())

func test_progress_never_moves_back_and_bar_only_shows_on_focus() -> void:
	pot.plant(bag, 0, 1000.0)
	pot.water(1000.0)
	pot.refresh(1060.0)
	pot.refresh(900.0)
	assert_eq(pot.progress, 0.5)
	assert_false(pot.progress_frame.visible)
	pot.set_focused(true)
	assert_true(pot.progress_frame.visible)
	assert_true(pot.marker.visible)
	pot.set_focused(false)
	assert_false(pot.progress_frame.visible)

func test_animation_frames_do_not_advance_growth_stage() -> void:
	pot.plant(bag, 0, 1000.0)
	pot.sprite.frame = 5
	assert_eq(pot.stage, 0)
	assert_eq(pot.progress, 0.0)
