extends GutTest
const POT: PackedScene = preload("res://scenes/flowers/flower_pot.tscn")
var pot: FlowerPot
var bag: InventoryComponent
var seed: ItemDefinition

func before_each() -> void:
	pot = POT.instantiate() as FlowerPot
	add_child_autofree(pot)
	bag = InventoryComponent.new()
	bag.starting_tools = false
	bag.slot_count = 2
	add_child_autofree(bag)
	seed = load("res://items/seeds/flower_01_seed.tres") as ItemDefinition
	seed = seed.duplicate() as ItemDefinition
	seed.crop = seed.crop.duplicate() as FlowerDefinition
	seed.crop.growth_seconds = 120.0
	seed.crop.harvest_amount = 1
	bag.add(seed, 3)

func test_all_ten_flowers_have_five_static_stages() -> void:
	for index: int in range(1, 11):
		var path: String = "res://items/seeds/flower_%02d_seed.tres" % index
		var item: ItemDefinition = load(path) as ItemDefinition
		assert_true(item.crop.is_valid())
		assert_eq(item.crop.stage_textures.size(), 5)
		for texture: Texture2D in item.crop.stage_textures:
			assert_not_null(texture)
		assert_eq(item.crop.harvest_item.item_type, ItemDefinition.ItemType.PRODUCE)

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
		assert_eq(pot.sprite.texture, seed.crop.stage_textures[stage])
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
	assert_false(pot.sprite.visible)
	assert_true(pot.visual.pot_sprite.visible)
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
