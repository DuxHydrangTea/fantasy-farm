extends GutTest
var production: BeehiveProductionComponent
var bag: InventoryComponent

func before_each() -> void:
	production = BeehiveProductionComponent.new()
	production.definition = preload("res://resources/bees/beehive.tres").duplicate() as BeehiveDefinition
	production.definition.cycle_seconds = 100.0
	bag = InventoryComponent.new()
	bag.starting_tools = false
	bag.slot_count = 2
	add_child_autofree(bag)

func test_wild_cycle_caps_at_one_batch_and_only_restarts_on_collection() -> void:
	production.advance(99,"")
	assert_null(production.ready_item)
	production.advance(10000,"")
	assert_eq(production.ready_item,production.definition.wild_honey)
	assert_eq(production.work,100.0)
	assert_eq(production.collect(bag),production.definition.wild_honey)
	assert_eq(bag.count_item(&"wild_honey"),1)
	assert_eq(production.work,0.0)
	assert_null(production.collect(bag))
	production.advance(1,"")
	assert_eq(production.work,1.0)

func test_thirty_percent_speed_and_monofloral_threshold_use_earned_work() -> void:
	production.advance(100.0/1.3,"sunflower")
	assert_eq(production.ready_item,production.definition.sunflower_honey)
	assert_almost_eq(production.contributions.sunflower,100.0,0.00001)

func test_last_minute_flower_cannot_upgrade_a_wild_batch() -> void:
	production.advance(60,"")
	production.advance(100,"flower_08")
	assert_eq(production.ready_item,production.definition.wild_honey)
	assert_eq(production.contributions.flower_08,40.0)

func test_exactly_half_qualifies_and_later_changes_cannot_relabel_ready_honey() -> void:
	production.advance(50,"")
	production.advance(50,"flower_01")
	assert_eq(production.ready_item,production.definition.floral_honey)
	production.advance(10000,"sunflower")
	assert_eq(production.ready_item,production.definition.floral_honey)
	assert_eq(production.contributions.flower_01,50.0)

func test_different_flower_species_are_not_pooled_into_one_specialty() -> void:
	production.advance(40.0/1.3,"flower_01")
	production.advance(40.0/1.3,"flower_02")
	production.advance(20,"")
	assert_eq(production.ready_item,production.definition.wild_honey)

func test_full_bag_preserves_ready_honey_and_collect_is_atomic_against_reentry() -> void:
	production.advance(100,"")
	bag.add(InventoryComponent.HOE,2)
	assert_null(production.collect(bag))
	assert_eq(production.work,100.0)
	bag.remove(&"hoe",1)
	var seen: Array[bool] = []
	bag.changed.connect(func() -> void:
		seen.append(production.ready_item == null and production.work == 0.0)
		assert_null(production.collect(bag))
	)
	assert_eq(production.collect(bag),production.definition.wild_honey)
	assert_eq(seen,[true])
	assert_eq(bag.count_item(&"wild_honey"),1)

func test_dominant_species_tie_breaks_by_nearest_then_id() -> void:
	var pollen: PollinationComponent = PollinationComponent.new()
	pollen.sources = [{"type":"flower_01","name":"A","point":Vector2(30,0)}, {"type":"flower_02","name":"B","point":Vector2(20,0)}]
	pollen.resolve(Vector2.ZERO)
	assert_eq(pollen.source_id,"flower_02")
	pollen.sources.append({"type":"flower_01","name":"A","point":Vector2(40,0)})
	pollen.resolve(Vector2.ZERO)
	assert_eq(pollen.source_id,"flower_01")
