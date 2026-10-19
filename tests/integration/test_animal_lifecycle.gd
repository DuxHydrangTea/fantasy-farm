extends GutTest
const Actor = preload("res://components/animals/animal_actor.gd")
const Pen = preload("res://components/animals/animal_pen.gd")
const Definition = preload("res://scripts/animals/animal_definition.gd")
const ProductionDefinition = preload("res://scripts/animals/animal_production_definition.gd")
const Clock = preload("res://components/time_manager.gd")
const Pickup = preload("res://components/item_pickup.gd")
const Inventory = preload("res://components/inventory_component.gd")
const Behaviour = preload("res://components/animals/animal_behaviour_component.gd")
var timestamp: float = 1000.0
var clock: Clock
var pen: Pen

func before_each() -> void:
	timestamp = 1000.0
	clock = Clock.new()
	clock.clock_source = func() -> float: return timestamp
	add_child_autofree(clock)
	clock.set_process(false)
	pen = Pen.new()
	add_child_autofree(pen)

func _animal(species: String = "chicken", initial_age: float = 0.0, juvenile: SpriteFrames = null, skin: SpriteFrames = null) -> Actor:
	var animal: Actor = preload("res://scenes/animals/chicken.tscn").instantiate() as Actor
	animal.definition = load("res://animals/definitions/" + species + ".tres").duplicate() as Definition
	animal.definition.production = animal.definition.production.duplicate() as ProductionDefinition
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

func _pickups() -> Array[Pickup]:
	var found: Array[Pickup] = []
	for child: Node in pen.get_children():
		var pickup: Pickup = child as Pickup
		if pickup != null and not pickup.is_queued_for_deletion():
			found.append(pickup)
	return found

func test_only_post_maturity_time_counts_towards_first_product() -> void:
	var animal: Actor = _animal()
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
	var animal: Actor = _animal("chicken", 10.0)
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
	var animal: Actor = _animal("chicken", 10.0)
	animal.needs.configure(10.0, 10000.0)
	animal.needs.satiety = 10.0
	timestamp += 50.0
	animal.needs.feed(50.0)
	assert_eq(animal.production.progress_seconds, 1.0)
	assert_eq(_pickups().size(), 0)
	_advance(3.0)
	assert_eq(_pickups().size(), 1)

func test_supply_expires_before_maturity_so_no_productive_time_is_credited() -> void:
	var animal: Actor = _animal()
	animal.needs.configure(5.0, 5.0)
	_advance(20.0)
	assert_true(animal.growth.is_adult(), "Age still advances during starvation")
	assert_eq(animal.production.progress_seconds, 0.0)
	assert_eq(_pickups().size(), 0)

func test_one_large_tick_and_split_ticks_agree_at_maturity_and_starvation() -> void:
	var one_tick: Actor = _animal()
	one_tick.needs.configure(18.0, 100.0)
	var split: Actor = _animal()
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
	var animal: Actor = _animal("chicken", 10.0)
	_advance(9.0)
	var age: float = animal.growth.age_seconds
	animal.needs.update_at(timestamp)
	animal.needs.update_at(timestamp - 4.0)
	assert_eq(animal.growth.age_seconds, age)
	assert_eq(_pickups()[0].amount, 2)
	assert_eq(animal.production.progress_seconds, 1.0)

func test_large_catchup_is_stacked_in_one_pickup_and_survives_animal_removal() -> void:
	var animal: Actor = _animal("chicken", 10.0)
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
	var animal: Actor = _animal("chicken", 0.0, null, skin)
	assert_false(animal.growth.is_adult())
	assert_eq(animal.sprite.sprite_frames, skin)
	var invalid: Actor = _animal("chicken", 0.0, SpriteFrames.new(), skin)
	assert_eq(invalid.sprite.sprite_frames, skin)
	_advance(10.0)
	assert_eq(animal.sprite.sprite_frames, skin)
	assert_true(animal.growth.is_adult())

func test_real_juvenile_sprite_switches_to_adult_skin_while_idle() -> void:
	var juvenile: SpriteFrames = load("res://sprite_frames/animals/chicken_02_frames.tres") as SpriteFrames
	var skin: SpriteFrames = load("res://sprite_frames/animals/chicken_18_frames.tres") as SpriteFrames
	var animal: Actor = _animal("chicken", 0.0, juvenile, skin)
	assert_eq(animal.sprite.sprite_frames, juvenile)
	_advance(10.0)
	await wait_physics_frames(2)
	assert_eq(animal.sprite.sprite_frames, skin)

func test_sprite_transition_waits_for_sleep_and_standing_to_finish() -> void:
	var juvenile: SpriteFrames = load("res://sprite_frames/animals/chicken_02_frames.tres") as SpriteFrames
	var animal: Actor = _animal("chicken", 0.0, juvenile)
	animal.definition.sleep_seconds = Vector2(10, 10)
	assert_true(animal.behaviour.request_behaviour(&"sleep"))
	for frame: int in range(180):
		if animal.behaviour.current_state == Behaviour.State.SLEEP:
			break
		await wait_physics_frames(1)
	assert_eq(animal.behaviour.current_state, Behaviour.State.SLEEP)
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
	var animal: Actor = _animal(species, 10.0)
	_advance(4.0)
	assert_eq(_pickups().size(), 1)
	assert_eq(_pickups()[0].item, animal.definition.production.production_item)
	assert_eq(_pickups()[0].amount, animal.definition.production.production_amount)
	assert_true(pen.contains_world(_pickups()[0].global_position, animal.wander.margin))

func test_direct_collection_mode_keeps_output_until_inventory_accepts_it() -> void:
	var animal: Actor = _animal("cow", 10.0)
	animal.definition.production.collection_mode = ProductionDefinition.CollectionMode.DIRECT_COLLECTION
	_advance(8.0)
	assert_eq(_pickups().size(), 0)
	assert_eq(animal.production.stored_amount, 2)
	var inventory: Inventory = Inventory.new()
	inventory.starting_tools = false
	add_child_autofree(inventory)
	assert_eq(animal.collect_produce(inventory), 2)
	assert_eq(animal.collect_produce(inventory), 0)
	assert_eq(inventory.count_item(&"cow_milk"), 2)

func test_collecting_a_pile_allows_next_cycle_to_create_a_new_one() -> void:
	_animal("chicken", 10.0)
	var inventory: Inventory = Inventory.new()
	inventory.starting_tools = false
	add_child_autofree(inventory)
	_advance(4.0)
	assert_eq(_pickups()[0].collect(inventory), 1)
	_advance(4.0)
	assert_eq(_pickups().size(), 1)
	assert_eq(_pickups()[0].amount, 1)
	assert_eq(inventory.count_item(&"chicken_egg"), 1)
