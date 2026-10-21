extends GutTest
var timestamp: float = 1000.0
var clock: FarmClock
var pen: AnimalPen

func before_each() -> void:
	timestamp = 1000.0
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return timestamp
	add_child_autofree(clock)
	clock.set_process(false)
	pen = AnimalPen.new()
	add_child_autofree(pen)

func _animal(species: String = "chicken", initial_age: float = 0.0, juvenile: SpriteFrames = null, skin: SpriteFrames = null) -> AnimalActor:
	var animal: AnimalActor = preload("res://scenes/animals/chicken.tscn").instantiate() as AnimalActor
	animal.definition = load("res://animals/definitions/" + species + ".tres").duplicate() as AnimalDefinition
	animal.definition.production = animal.definition.production.duplicate() as AnimalProductionDefinition
	animal.definition.production.production_seconds = 4.0
	animal.definition.maturity_seconds = 10.0
	animal.definition.satiety_depletion_seconds = 10000.0
	animal.definition.hydration_depletion_seconds = 10000.0
	animal.definition.walk_weight = 0.0
	animal.definition.forage_weight = 0.0
	animal.definition.rest_weight = 0.0
	animal.definition.sleep_weight = 0.0
	animal.definition.juvenile_frames = juvenile
	animal.skin_frames = skin
	animal.initial_age_seconds = initial_age
	animal.position = Vector2(100, 80)
	animal.get_node("NeedsComponent").time_manager = clock
	pen.add_child(animal)
	animal.behaviour.request_behaviour(&"idle")
	return animal

func _advance(seconds: float) -> void:
	timestamp += seconds
	clock.refresh()

func _pickups() -> Array[ItemPickup]:
	var found: Array[ItemPickup] = []
	for child: Node in pen.get_children():
		var pickup: ItemPickup = child as ItemPickup
		if pickup != null and not pickup.is_queued_for_deletion():
			found.append(pickup)
	return found

func test_only_post_maturity_time_counts_towards_first_product() -> void:
	var animal: AnimalActor = _animal()
	_advance(9.0)
	assert_false(animal.growth.is_adult())
	assert_eq(animal.production.progress_seconds, 0.0)
	_advance(2.0)
	assert_true(animal.growth.is_adult())
	assert_eq(animal.production.progress_seconds, 1.0)
	assert_eq(_pickups().size(), 0)
	_advance(3.0)
	assert_eq(_pickups().size(), 1)
	assert_eq(_pickups()[0].item.item_id, &"chicken_egg")
	assert_eq(animal.production.stored_amount, 0)

func test_empty_needs_pause_production_without_reset_or_retroactive_refill() -> void:
	var animal: AnimalActor = _animal("chicken", 10.0)
	animal.needs.configure(10.0, 20.0)
	animal.needs.satiety = 5.0
	_advance(5.0)
	assert_eq(animal.needs.satiety, 0.0)
	assert_eq(animal.production.progress_seconds, 0.5, "Only the first half second had food")
	_advance(100.0)
	assert_eq(animal.production.progress_seconds, 0.5)
	animal.needs.feed(40.0)
	animal.needs.drink(40.0)
	assert_eq(animal.production.progress_seconds, 0.5)
	_advance(3.5)
	assert_eq(_pickups().size(), 1)
	assert_eq(animal.production.progress_seconds, 0.0)

func test_late_refill_syncs_elapsed_starvation_before_restoring_food() -> void:
	var animal: AnimalActor = _animal("chicken", 10.0)
	animal.needs.configure(10.0, 10000.0)
	animal.needs.satiety = 10.0
	timestamp += 50.0
	animal.needs.feed(50.0)
	assert_eq(animal.production.progress_seconds, 1.0)
	assert_eq(_pickups().size(), 0)
	_advance(3.0)
	assert_eq(_pickups().size(), 1)

func test_supply_expires_before_maturity_so_no_productive_time_is_credited() -> void:
	var animal: AnimalActor = _animal()
	animal.needs.configure(5.0, 5.0)
	_advance(20.0)
	assert_true(animal.growth.is_adult(), "Age still advances during starvation")
	assert_eq(animal.production.progress_seconds, 0.0)
	assert_eq(_pickups().size(), 0)

func test_one_large_tick_and_split_ticks_agree_at_maturity_and_starvation() -> void:
	var one_tick: AnimalActor = _animal()
	one_tick.needs.configure(18.0, 100.0)
	var split: AnimalActor = _animal()
	split.needs.configure(18.0, 100.0)
	one_tick.needs.update_at(1030.0)
	for second: int in range(1, 31):
		split.needs.update_at(1000.0 + second)
	assert_eq(one_tick.growth.age_seconds, split.growth.age_seconds)
	assert_almost_eq(one_tick.production.progress_seconds, split.production.progress_seconds, 0.00001)
	assert_eq(_pickups().size(), 2)
	assert_eq(_pickups()[0].amount, _pickups()[1].amount)
	assert_eq(_pickups()[0].amount, 2)

func test_repeated_or_backward_timestamps_cannot_duplicate_age_or_products() -> void:
	var animal: AnimalActor = _animal("chicken", 10.0)
	_advance(9.0)
	var age: float = animal.growth.age_seconds
	animal.needs.update_at(timestamp)
	animal.needs.update_at(timestamp - 4.0)
	assert_eq(animal.growth.age_seconds, age)
	assert_eq(_pickups()[0].amount, 2)
	assert_eq(animal.production.progress_seconds, 1.0)

func test_large_catchup_is_stacked_in_one_pickup_and_survives_animal_removal() -> void:
	var animal: AnimalActor = _animal("chicken", 10.0)
	_advance(1000.0)
	assert_eq(_pickups().size(), 1)
	assert_eq(_pickups()[0].amount, 250)
	_advance(4.0)
	assert_eq(_pickups().size(), 1)
	assert_eq(_pickups()[0].amount, 251)
	animal.queue_free()
	await wait_physics_frames(2)
	assert_eq(_pickups().size(), 1)

func test_missing_or_invalid_juvenile_art_preserves_individual_adult_skin() -> void:
	var skin: SpriteFrames = load("res://sprite_frames/animals/chicken_18_frames.tres") as SpriteFrames
	var animal: AnimalActor = _animal("chicken", 0.0, null, skin)
	assert_false(animal.growth.is_adult())
	assert_eq(animal.sprite.sprite_frames, skin)
	var invalid: AnimalActor = _animal("chicken", 0.0, SpriteFrames.new(), skin)
	assert_eq(invalid.sprite.sprite_frames, skin)
	_advance(10.0)
	assert_eq(animal.sprite.sprite_frames, skin)
	assert_true(animal.growth.is_adult())

func test_real_juvenile_sprite_switches_to_adult_skin_while_idle() -> void:
	var juvenile: SpriteFrames = load("res://sprite_frames/animals/chicken_02_frames.tres") as SpriteFrames
	var skin: SpriteFrames = load("res://sprite_frames/animals/chicken_18_frames.tres") as SpriteFrames
	var animal: AnimalActor = _animal("chicken", 0.0, juvenile, skin)
	assert_eq(animal.sprite.sprite_frames, juvenile)
	_advance(10.0)
	await wait_physics_frames(2)
	assert_eq(animal.sprite.sprite_frames, skin)

func test_sprite_transition_waits_for_sleep_and_standing_to_finish() -> void:
	var juvenile: SpriteFrames = load("res://sprite_frames/animals/chicken_02_frames.tres") as SpriteFrames
	var animal: AnimalActor = _animal("chicken", 0.0, juvenile)
	animal.definition.sleep_seconds = Vector2(10, 10)
	assert_true(animal.behaviour.request_behaviour(&"sleep"))
	for frame: int in range(180):
		if animal.behaviour.current_state == AnimalBehaviourComponent.State.SLEEP:
			break
		await wait_physics_frames(1)
	assert_eq(animal.behaviour.current_state, AnimalBehaviourComponent.State.SLEEP)
	_advance(10.0)
	await wait_physics_frames(2)
	assert_eq(animal.sprite.sprite_frames, juvenile)
	assert_true(animal.behaviour.wake())
	for frame: int in range(180):
		if animal.sprite.sprite_frames == animal.definition.adult_frames:
			break
		await wait_physics_frames(1)
	assert_eq(animal.sprite.sprite_frames, animal.definition.adult_frames)

func test_all_species_use_their_configured_produce(species = use_parameters(["chicken", "cow", "duck", "goose", "pig", "sheep", "horse"])) -> void:
	var animal: AnimalActor = _animal(species, 10.0)
	_advance(4.0)
	assert_eq(_pickups().size(), 1)
	assert_eq(_pickups()[0].item, animal.definition.production.production_item)
	assert_eq(_pickups()[0].amount, animal.definition.production.production_amount)
	assert_true(pen.contains_world(_pickups()[0].global_position, animal.wander.margin))

func test_direct_collection_mode_keeps_output_until_inventory_accepts_it() -> void:
	var animal: AnimalActor = _animal("cow", 10.0)
	animal.definition.production.collection_mode = AnimalProductionDefinition.CollectionMode.DIRECT_COLLECTION
	_advance(8.0)
	assert_eq(_pickups().size(), 0)
	assert_eq(animal.production.stored_amount, 2)
	var inventory: InventoryComponent = InventoryComponent.new()
	inventory.starting_tools = false
	add_child_autofree(inventory)
	assert_eq(animal.collect_produce(inventory), 2)
	assert_eq(animal.collect_produce(inventory), 0)
	assert_eq(inventory.count_item(&"cow_milk"), 2)

func test_collecting_a_pile_allows_next_cycle_to_create_a_new_one() -> void:
	_animal("chicken", 10.0)
	var inventory: InventoryComponent = InventoryComponent.new()
	inventory.starting_tools = false
	add_child_autofree(inventory)
	_advance(4.0)
	assert_eq(_pickups()[0].collect(inventory), 1)
	_advance(4.0)
	assert_eq(_pickups().size(), 1)
	assert_eq(_pickups()[0].amount, 1)
	assert_eq(inventory.count_item(&"chicken_egg"), 1)

func _short_lifetime(animal: AnimalActor, lifetime: float = 20.0) -> void:
	animal.definition.lifespan_seconds = lifetime
	animal.growth.configure(animal.definition.maturity_seconds, animal.growth.age_seconds, lifetime)

func test_single_offline_jump_credits_only_adult_living_interval_then_retires_once() -> void:
	var animal: AnimalActor = _animal()
	_short_lifetime(animal)
	watch_signals(animal)
	_advance(1000.0)
	assert_true(animal.is_dead())
	assert_true(animal.is_queued_for_deletion())
	assert_eq(animal.growth.age_seconds, 20.0)
	assert_eq(_pickups().size(), 1)
	assert_eq(_pickups()[0].amount, 2, "Only age 10..20 is productive, with four-second cycles")
	assert_signal_emit_count(animal, "died", 1)
	animal.needs.update_at(timestamp + 1000.0)
	assert_eq(_pickups()[0].amount, 2)
	assert_signal_emit_count(animal, "died", 1)
	await wait_physics_frames(2)
	assert_false(is_instance_valid(animal))
	assert_eq(_pickups().size(), 1)

func test_split_and_single_ticks_agree_across_maturity_and_death() -> void:
	var one_tick: AnimalActor = _animal()
	var split: AnimalActor = _animal()
	_short_lifetime(one_tick)
	_short_lifetime(split)
	one_tick.needs.update_at(1100.0)
	for second: int in range(1, 101):
		split.needs.update_at(1000.0 + second)
	assert_true(one_tick.is_dead())
	assert_true(split.is_dead())
	assert_eq(one_tick.growth.age_seconds, split.growth.age_seconds)
	assert_eq(one_tick.production.progress_seconds, split.production.progress_seconds)
	assert_eq(_pickups().size(), 2)
	assert_eq(_pickups()[0].amount, _pickups()[1].amount)

func test_starvation_does_not_delay_death_and_cannot_create_posthumous_produce() -> void:
	var animal: AnimalActor = _animal()
	_short_lifetime(animal)
	animal.needs.configure(5.0, 5.0)
	_advance(19.0)
	assert_false(animal.is_dead())
	_advance(1.0)
	assert_true(animal.is_dead())
	assert_eq(_pickups().size(), 0)
	assert_eq(animal.needs.feed(100.0), 0.0)
	assert_eq(animal.needs.drink(100.0), 0.0)

func test_death_drops_completed_direct_collection_stock_and_preserves_existing_pile() -> void:
	var animal: AnimalActor = _animal("cow", 10.0)
	_short_lifetime(animal)
	animal.definition.production.collection_mode = AnimalProductionDefinition.CollectionMode.DIRECT_COLLECTION
	_advance(8.0)
	assert_eq(animal.production.stored_amount, 2)
	assert_eq(_pickups().size(), 0)
	_advance(2.0)
	assert_true(animal.is_dead())
	assert_eq(animal.production.stored_amount, 0)
	assert_eq(_pickups()[0].amount, 2)
	var bag: InventoryComponent = InventoryComponent.new()
	bag.starting_tools = false
	add_child_autofree(bag)
	assert_eq(animal.collect_produce(bag), 0)
	assert_eq(_pickups()[0].collect(bag), 2)

func test_actual_day_boundary_does_not_credit_the_juvenile_day() -> void:
	var animal: AnimalActor = _animal()
	var data: AnimalDefinition = load("res://animals/definitions/chicken.tres") as AnimalDefinition
	animal.definition.maturity_seconds = data.maturity_seconds
	animal.growth.configure(data.maturity_seconds, 0.0, data.lifespan_seconds)
	animal.needs.configure(2000000.0, 2000000.0)
	_advance(86399.0)
	assert_false(animal.growth.is_adult())
	assert_eq(_pickups().size(), 0)
	_advance(1.0)
	assert_true(animal.growth.is_adult())
	assert_eq(animal.production.progress_seconds, 0.0)
	_advance(4.0)
	assert_eq(_pickups()[0].amount, 1)
