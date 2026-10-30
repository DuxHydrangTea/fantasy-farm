extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const PESTICIDE: ItemDefinition = preload("res://items/boosters/pesticide.tres")
const MEDICINE: ItemDefinition = preload("res://items/boosters/animal_medicine.tres")
var world: FarmWorld
var farm: FarmingController
var animal: AnimalActor
var now: float = 1000.0
var clock: FarmClock
var cell: Vector2i = Vector2i(56, 22)

func _clocks(node: Node) -> void:
	if node is AnimalNeedsComponent:
		(node as AnimalNeedsComponent).time_manager = clock
	for child: Node in node.get_children():
		_clocks(child)

func before_each() -> void:
	now = 1000.0
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return now
	add_child_autofree(clock)
	clock.set_process(false)
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.farming.time_manager = clock
	_clocks(world)
	add_child_autofree(world)
	farm = world.farming
	world.tool_upgrades.profile_ready = true
	animal = preload("res://scenes/animals/chicken.tscn").instantiate() as AnimalActor
	animal.initial_age_seconds = 1000.0
	animal.position = Vector2(100, 80)
	(animal.get_node("NeedsComponent") as AnimalNeedsComponent).time_manager = clock
	world.get_node("CoopPen").add_child(animal)
	animal.needs.weather = null
	animal.needs.pen = null
	animal.needs.configure(1000000, 1000000)
	animal.growth.configure(1, 10, 1000000)
	animal.production.definition = animal.production.definition.duplicate() as AnimalProductionDefinition
	animal.production.definition.production_seconds = 60.0
	animal.production.definition.production_amount = 1
	animal.health.next_onset_at = 1030.0
	world.player.global_position = farm.farmland.to_global(farm.farmland.map_to_local(cell + Vector2i.UP))
	world.player.animation.face(Vector2.DOWN)
	await wait_physics_frames(2)

func _crop(mature: bool = true) -> Crop:
	farm.restore_soil([{"cell": [cell.x, cell.y], "state": 1}])
	var definition: CropDefinition = preload("res://crops/field/wheat/wheat.tres").duplicate() as CropDefinition
	definition.harvest_amount = 10
	farm.restore_crop(cell, definition, 800, 1000 if mature else 1200, 1.0 if mature else 0.5, now)
	var crop: Crop = farm.get_crop(cell)
	crop.conditions.pests = true
	crop.conditions.weeds = true
	crop.conditions.yield_roll = 0.99
	crop.refresh(now)
	return crop

func _slot(item: ItemDefinition) -> int:
	for i: int in range(world.player.selection.inventory.slot_count):
		if world.player.selection.inventory.slot(i).item == item:
			return i
	return -1

func test_treating_each_crop_condition_preserves_other_flags_and_quality() -> void:
	var crop: Crop = _crop(false)
	crop.mark_watered()
	crop.apply_root()
	var bag: InventoryComponent = world.player.selection.inventory
	bag.add(PESTICIDE, 2)
	assert_true(world.player.boosters.service.use(farm, cell, null, bag, _slot(PESTICIDE), PESTICIDE, world.player).ok)
	assert_false(crop.conditions.pests)
	assert_true(crop.conditions.weeds)
	assert_eq(crop.harvest_tier(), 2)
	assert_eq(bag.count_item(PESTICIDE.item_id), 1)
	assert_false(world.player.boosters.service.use(farm, cell, null, bag, _slot(PESTICIDE), PESTICIDE, world.player).ok)
	assert_eq(bag.count_item(PESTICIDE.item_id), 1)
	assert_true(farm.treat_crop(cell, false, world.player))
	assert_false(crop.conditions.affected())

func test_crop_treatment_out_of_range_does_not_consume_stock() -> void:
	_crop()
	var bag: InventoryComponent = world.player.selection.inventory
	bag.add(PESTICIDE, 1)
	world.player.position += Vector2(200, 0)
	assert_false(world.player.boosters.service.use(farm, cell, null, bag, _slot(PESTICIDE), PESTICIDE, world.player).ok)
	assert_eq(bag.count_item(PESTICIDE.item_id), 1)

func test_zero_harvest_finishes_once_and_produces_no_reward() -> void:
	while farm.fertility.is_fertile(cell):
		cell.y += 1
	var crop: Crop = _crop()
	crop.definition = crop.definition.duplicate() as CropDefinition
	crop.definition.harvest_amount = 1
	assert_eq(farm.harvest_amount(cell), 0)
	var bag: InventoryComponent = world.player.selection.inventory
	var before: int = bag.count_item(crop.definition.harvest_item.item_id)
	assert_true(farm.harvest(cell, bag))
	assert_null(farm.get_crop(cell))
	assert_false(farm.harvest(cell, bag))
	assert_eq(bag.count_item(crop.definition.harvest_item.item_id), before)

func test_worker_wait_policy_and_shared_harvest_amount() -> void:
	var crop: Crop = _crop()
	var row: Dictionary = {"role": "crop", "id": "worker_test", "zone": "", "water_units": 30}
	var task: Dictionary = {"kind": "harvest", "id": "56_22", "cell": [cell.x, cell.y]}
	assert_false(world.workers.bridge._commit_output(row, world.workers.output_inventory(), task))
	assert_not_null(farm.get_crop(cell))
	world.workers.crop_automation.wait_for_care = false
	var expected: int = farm.harvest_amount(cell)
	var item: ItemDefinition = crop.definition.harvest_item
	var before: int = world.workers.output_inventory().count_item(item.item_id)
	assert_true(world.workers.bridge._commit_output(row, world.workers.output_inventory(), task))
	assert_eq(world.workers.output_inventory().count_item(item.item_id), before + expected)

func test_disease_reduces_progress_only_after_onset_and_cure_is_not_food() -> void:
	now = 1060
	animal.needs.update_at(now)
	assert_true(animal.health.sick)
	assert_almost_eq(animal.production.progress_seconds, 45.0, 0.0001)
	var food: float = animal.needs.satiety
	var water: float = animal.needs.hydration
	assert_true(animal.cure_disease())
	assert_eq(animal.needs.satiety, food)
	assert_eq(animal.needs.hydration, water)
	assert_eq(animal.production.progress_seconds, 45.0)
	now = 1070
	animal.needs.update_at(now)
	assert_almost_eq(animal.production.progress_seconds, 55.0, 0.0001)

func test_sick_hungry_thirsty_animal_reports_all_reasons_and_stops_production() -> void:
	animal.health.sick = true
	animal.needs.restore_state(0, 0, now)
	now += 60
	animal.needs.update_at(now)
	assert_eq(animal.production.progress_seconds, 0.0)
	var text: String = AnimalStatusText.new().production_state(animal)
	assert_string_contains(text, tr("Needs food"))
	assert_string_contains(text, tr("Needs water"))
	assert_string_contains(text, tr("Sick"))
	assert_true(animal.cure_disease())
	assert_eq(animal.needs.satiety, 0.0)
	assert_eq(animal.needs.hydration, 0.0)

func test_medicine_consumed_once_only_for_a_nearby_sick_animal() -> void:
	var bag: InventoryComponent = world.player.selection.inventory
	bag.add(MEDICINE, 2)
	animal.health.sick = true
	world.player.global_position = animal.global_position + Vector2(0, 20)
	assert_true(world.player.boosters.service.use(farm, cell, animal, bag, _slot(MEDICINE), MEDICINE, world.player).ok)
	assert_false(animal.health.sick)
	assert_eq(bag.count_item(MEDICINE.item_id), 1)
	assert_false(world.player.boosters.service.use(farm, cell, animal, bag, _slot(MEDICINE), MEDICINE, world.player).ok)
	assert_eq(bag.count_item(MEDICINE.item_id), 1)

func test_save_migration_roundtrip_and_invalid_health_preflight() -> void:
	var crop: Crop = _crop()
	animal.health.sick = true
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var data: Dictionary = adapter.capture("health_test", 1, now)
	assert_true(SaveSchema.validate(data, adapter.catalog).ok)
	var legacy: Dictionary = data.duplicate(true)
	legacy.version = 36
	legacy.workers.crop_automation.erase("wait_for_care")
	for row: Dictionary in legacy.crops:
		row.erase("conditions")
	for row: Dictionary in legacy.animals:
		row.erase("health")
	var migrated: Dictionary = SaveSchema.validate(legacy, adapter.catalog)
	assert_true(migrated.ok)
	assert_eq(legacy.version, 36, "Migration does not mutate input")
	if migrated.ok:
		assert_false(migrated.snapshot.crops[0].conditions.pests)
		assert_false(migrated.snapshot.animals[0].health.sick)
	var original: Dictionary = crop.conditions.capture()
	assert_true(adapter.restore_without_offline(data).ok)
	assert_eq_deep(farm.get_crop(cell).conditions.capture(), original)
	var bad: Dictionary = data.duplicate(true)
	bad.animals[0].health.rng_state = 0
	assert_false(adapter.restore_without_offline(bad).ok)
	assert_eq_deep(farm.get_crop(cell).conditions.capture(), original)

func test_catalog_storage_and_shop_include_both_medicines() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	assert_eq(catalog.items["pesticide"], PESTICIDE)
	assert_eq(catalog.items["animal_medicine"], MEDICINE)
	assert_true(world.storages.definition("farm_supply_storage").accepts(PESTICIDE))
	assert_true(world.storages.definition("farm_supply_storage").accepts(MEDICINE))
	var shop: ShopCatalog = preload("res://resources/shops/farm_supply.tres")
	assert_true(shop.offers.any(func(offer: ShopOffer) -> bool: return offer.item == PESTICIDE))
	assert_true(shop.offers.any(func(offer: ShopOffer) -> bool: return offer.item == MEDICINE))
	var seeds: ShopCatalog = preload("res://resources/shops/seed_flower_shop.tres")
	var pets: ShopCatalog = preload("res://resources/shops/pet_shop.tres")
	assert_true(seeds.offers.any(func(offer: ShopOffer) -> bool: return offer.item == PESTICIDE and offer.category in seeds.category_ids))
	assert_true(pets.offers.any(func(offer: ShopOffer) -> bool: return offer.item == MEDICINE and offer.category in pets.category_ids))

func _impact() -> void:
	var sprite: AnimatedSprite2D = world.player.animation.animated_sprite
	sprite.frame = mini(3, sprite.sprite_frames.get_frame_count(sprite.animation) - 1)
	world.player.boosters._frame_changed()
	world.player.boosters._frame_changed()

func test_weeding_uses_animation_impact_and_preserves_pests() -> void:
	var crop: Crop = _crop(false)
	var target: InteractionTarget = InteractionTarget.new(crop, InteractionTarget.Kind.CROP, world.player)
	assert_true(world.player.interactions.execute(target))
	assert_true(crop.conditions.weeds, "Preparing an animation does not commit care")
	_impact()
	assert_false(crop.conditions.weeds)
	assert_true(crop.conditions.pests)
	assert_string_contains(world.player.boosters.feedback_source(), "Weeds cleared")

func test_pesticide_impact_consumes_once_and_cancellation_keeps_stock() -> void:
	var crop: Crop = _crop(false)
	var bag: InventoryComponent = world.player.selection.inventory
	bag.add(PESTICIDE, 2)
	world.player.selection.select_slot(_slot(PESTICIDE))
	assert_true(world.player.state.use_selected_tool())
	assert_eq(bag.count_item(PESTICIDE.item_id), 2)
	world.player.state.transition_to(StateComponent.State.IDLE)
	_impact()
	assert_eq(bag.count_item(PESTICIDE.item_id), 2)
	assert_true(crop.conditions.pests)
	assert_true(world.player.state.use_selected_tool())
	_impact()
	assert_false(crop.conditions.pests)
	assert_true(crop.conditions.weeds)
	assert_eq(bag.count_item(PESTICIDE.item_id), 1)

func test_changed_crop_during_pesticide_animation_keeps_stock() -> void:
	var old: Crop = _crop(false)
	var bag: InventoryComponent = world.player.selection.inventory
	bag.add(PESTICIDE, 1)
	world.player.selection.select_slot(_slot(PESTICIDE))
	assert_true(world.player.state.use_selected_tool())
	farm._crops.erase(cell)
	farm.unschedule_crop(old)
	old.queue_free()
	var replacement: Crop = _crop(false)
	_impact()
	assert_true(replacement.conditions.pests)
	assert_eq(bag.count_item(PESTICIDE.item_id), 1)

func test_pen_offline_and_online_production_match_across_disease_onset() -> void:
	var pen: AnimalPen = world.get_node("CoopPen") as AnimalPen
	pen.weather = null
	for child: Node in pen.get_children():
		if child is AnimalTrough:
			(child as AnimalTrough).stock = 1200
	animal.needs.pen = pen
	var health_data: Dictionary = animal.health.capture()
	assert_true(pen.advance_offline(1120, true))
	var expected_progress: float = animal.production.progress_seconds
	var expected_output: int = animal.product_pickup().amount if animal.product_pickup() != null else 0
	assert_true(animal.health.sick)
	assert_almost_eq(expected_progress, 15.0, 0.0001)
	assert_eq(expected_output, 1)
	if animal.product_pickup() != null:
		animal.product_pickup().free()
	animal._product_pickup = null
	animal.health.restore(health_data)
	animal.production.restore_state(0, 0)
	animal.needs.restore_state(100, 100, 1000)
	animal.growth.configure(1, 10, 1000000)
	for i: int in range(1, 61):
		animal.needs.update_at(1000 + i * 2)
	assert_almost_eq(animal.production.progress_seconds, expected_progress, 0.0001)
	assert_eq(animal.product_pickup().amount if animal.product_pickup() != null else 0, expected_output)

func test_no_offline_restore_preserves_health_schedule_and_crop_rolls() -> void:
	var crop: Crop = _crop(false)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var snapshot: Dictionary = adapter.capture("health_time", 1, now)
	var expected_crop: Dictionary = crop.conditions.capture()
	var expected_health: Dictionary = animal.health.capture()
	assert_true(adapter.restore_without_offline(snapshot).ok)
	assert_eq_deep(farm.get_crop(cell).conditions.capture(), expected_crop)
	var restored: AnimalActor = world.get_node("CoopPen").get_children().filter(func(node: Node) -> bool: return node is AnimalActor and not node.is_queued_for_deletion())[0]
	assert_eq_deep(restored.health.capture(), expected_health)

func test_animal_popups_follow_needs_signals_and_all_eight_combinations() -> void:
	for mask: int in range(8):
		animal.health.sick = (mask & 1) != 0
		animal.needs.restore_state(0.0 if (mask & 2) != 0 else 100.0, 0.0 if (mask & 4) != 0 else 100.0, now)
		animal._refresh_health_badges()
		var expected: Array[StringName] = []
		if (mask & 1) != 0:
			expected.append(&"sick")
		if (mask & 2) != 0:
			expected.append(&"hungry")
		if (mask & 4) != 0:
			expected.append(&"thirsty")
		assert_eq_deep(animal.health_badges.active_statuses, expected)
		assert_eq(animal.health_badges.visible, mask != 0)
	animal.health.sick = false
	animal.needs.restore_state(0, 0, now)
	animal.needs.feed(100)
	assert_eq_deep(animal.health_badges.active_statuses, [&"thirsty"])
	animal.needs.drink(100)
	assert_false(animal.health_badges.visible)

func test_crop_popup_survives_focus_refresh_and_disappears_after_care() -> void:
	var crop: Crop = _crop(false)
	assert_eq_deep(crop.condition_badges.active_statuses, [&"weeds", &"pests"])
	assert_lt(crop.condition_badges.position.y, crop.progress_frame.position.y)
	var entrance: Tween = crop.condition_badges._entrance
	crop.set_status_focused(true)
	crop.refresh(now)
	assert_eq(crop.condition_badges._entrance, entrance)
	assert_true(farm.treat_crop(cell, true, world.player))
	assert_eq_deep(crop.condition_badges.active_statuses, [&"weeds"])
	assert_true(farm.treat_crop(cell, false, world.player))
	assert_false(crop.condition_badges.visible)
