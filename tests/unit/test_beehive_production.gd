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
	assert_eq(bag.count_item(&"wild_honey"),100)
	assert_eq(production.work,0.0)
	assert_null(production.collect(bag))
	production.advance(1,"")
	assert_eq(production.work,1.0)

func test_sunflower_speed_and_monofloral_threshold_use_earned_work() -> void:
	production.advance(75.0,"sunflower")
	assert_eq(production.ready_item,production.definition.sunflower_honey)
	assert_almost_eq(production.contributions.sunflower,100.0,0.00001)

func test_last_minute_flower_cannot_upgrade_a_wild_batch() -> void:
	production.advance(60,"")
	production.advance(100,"flower_08")
	assert_eq(production.ready_item,production.definition.wild_honey)
	assert_eq(production.contributions.flower_08,40.0)

func test_exactly_half_qualifies_and_later_changes_cannot_relabel_ready_honey() -> void:
	production.advance(50,"")
	production.advance(50,"flower_06")
	assert_eq(production.ready_item,production.definition.floral_honey)
	production.advance(10000,"sunflower")
	assert_eq(production.ready_item,production.definition.floral_honey)
	assert_eq(production.contributions.flower_06,50.0)

func test_different_flower_species_are_not_pooled_into_one_specialty() -> void:
	production.advance(20.0,"flower_06")
	production.advance(20.0,"flower_07")
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
	assert_eq(bag.count_item(&"wild_honey"),100)

func test_dominant_species_tie_breaks_by_nearest_then_id() -> void:
	var pollen: PollinationComponent = PollinationComponent.new()
	pollen.sources = [{"type":"flower_06","name":"A","point":Vector2(30,0)}, {"type":"flower_07","name":"B","point":Vector2(20,0)}]
	pollen.resolve(Vector2.ZERO)
	assert_eq(pollen.source_id,"flower_07")
	pollen.sources.append({"type":"flower_06","name":"A","point":Vector2(40,0)})
	pollen.resolve(Vector2.ZERO)
	assert_eq(pollen.source_id,"flower_06")

func test_real_cycles_are_24_18_and_12_hours_and_cap_at_100_jars() -> void:
	production.definition.cycle_seconds = 86400.0
	for source: String in ["", "sunflower", "flower_06"]:
		var hive: BeehiveProductionComponent = BeehiveProductionComponent.new()
		hive.definition = production.definition
		var seconds: float = 86400.0 if source == "" else 64800.0 if source == "sunflower" else 43200.0
		hive.advance(seconds - 1.0, source)
		assert_null(hive.ready_item)
		hive.advance(1.0, source)
		assert_eq(hive.ready_item, hive.definition.honey_for(source))
		hive.advance(86400.0 * 40, "flower_10")
		assert_eq(hive.work, 86400.0)
		assert_eq(hive.batch_amount(), 100)

func test_only_flowers_six_to_ten_can_accelerate_and_make_floral_honey() -> void:
	for index: int in range(1, 11):
		var hive: BeehiveProductionComponent = BeehiveProductionComponent.new()
		hive.definition = production.definition
		var source: String = "flower_%02d" % index
		hive.advance(25.0, source)
		assert_eq(hive.work, 50.0 if index >= 6 else 25.0)
		hive.advance(10000.0, source)
		assert_eq(hive.ready_item, hive.definition.floral_honey if index >= 6 else hive.definition.wild_honey)

func test_ninety_nine_free_spaces_cannot_partially_collect_a_hundred_jar_batch() -> void:
	production.advance(100, "")
	bag.add(production.definition.wild_honey, 31901)
	bag.add(InventoryComponent.HOE, 1)
	assert_eq(bag.capacity_for(production.ready_item), 99)
	assert_null(production.collect(bag))
	assert_eq(bag.count_item(&"wild_honey"), 31901)
	assert_eq(production.work, 100.0)
	bag.remove(&"wild_honey", 1)
	assert_not_null(production.collect(bag))
	assert_eq(bag.count_item(&"wild_honey"), 32000)

func test_legacy_batch_keeps_one_jar_and_old_rate_then_switches_to_new_rules() -> void:
	production.legacy_batch = true
	production.advance(100.0 / 1.3, "flower_01")
	assert_eq(production.ready_item, production.definition.floral_honey)
	assert_not_null(production.collect(bag))
	assert_eq(bag.count_item(&"floral_honey"), 1)
	assert_false(production.legacy_batch)
	production.advance(50.0, "flower_06")
	assert_not_null(production.collect(bag))
	assert_eq(bag.count_item(&"floral_honey"), 101)

func test_qualified_sources_take_priority_over_common_flowers_with_stable_ties() -> void:
	var pollen: PollinationComponent = PollinationComponent.new()
	pollen.sources = [{"type":"flower_01","name":"Common","point":Vector2.ZERO}, {"type":"sunflower","name":"Sunflower","point":Vector2(8,0)}, {"type":"flower_06","name":"Rare","point":Vector2(24,0)}]
	pollen.resolve(Vector2.ZERO, production.definition)
	assert_eq(pollen.source_id, "flower_06")
	pollen.sources.reverse()
	pollen.resolve(Vector2.ZERO, production.definition)
	assert_eq(pollen.source_id, "flower_06")
	pollen.resolve(Vector2.ZERO, production.definition, true)
	assert_eq(pollen.source_id, "flower_01", "Migrated batches retain the historic selection rule")
