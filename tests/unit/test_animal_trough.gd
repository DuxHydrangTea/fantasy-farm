extends GutTest
const Trough = preload("res://components/animals/animal_trough.gd")
const Needs = preload("res://components/animals/animal_needs_component.gd")
const Definition = preload("res://scripts/animals/animal_definition.gd")
const Foraging = preload("res://components/animals/animal_foraging_component.gd")
const Clock = preload("res://components/time_manager.gd")
var trough: Trough
var needs: Needs
var data: Definition
var animal: Node2D

func before_each() -> void:
	trough = Trough.new()
	trough.kind = Trough.Kind.FOOD
	trough.capacity = 3
	trough.stock = 3
	add_child_autofree(trough)
	animal = Node2D.new()
	add_child_autofree(animal)
	animal.global_position = trough.access_position(0)
	var clock: Clock = Clock.new()
	clock.clock_source = func() -> float: return 1000.0
	add_child_autofree(clock)
	clock.set_process(false)
	needs = Needs.new()
	needs.time_manager = clock
	add_child_autofree(needs)
	data = load("res://animals/definitions/chicken.tres").duplicate() as Definition

func test_refill_clamps_to_capacity_and_never_removes_stock() -> void:
	trough.stock = 1
	assert_eq(trough.refill(100), 2)
	assert_eq(trough.stock, 3)
	assert_eq(trough.refill(-4), 0)
	trough.stock = -10
	assert_eq(trough.stock, 0)
	assert_false(trough.can_supply(data))

func test_reservations_are_exclusive_and_release_when_animal_leaves() -> void:
	var other: Node2D = Node2D.new()
	add_child_autofree(other)
	assert_true(trough.claim(animal, 0, data))
	assert_false(trough.claim(other, 0, data))
	assert_true(trough.claim(other, 1, data))
	trough.release(animal)
	assert_true(trough.slot_available(0))
	remove_child(other)
	assert_true(trough.slot_available(1), "An animal leaving the tree cannot hold a slot")
	other.free()
	assert_false(trough.slot_available(50))

func test_only_reserved_nearby_animal_can_consume_and_only_matching_need_changes() -> void:
	needs.satiety = 20.0
	needs.hydration = 30.0
	assert_eq(trough.serve(animal, needs, data, 0), 0.0)
	assert_true(trough.claim(animal, 0, data))
	animal.position += Vector2(100, 0)
	assert_eq(trough.serve(animal, needs, data, 0), 0.0)
	assert_eq(trough.stock, 3)
	animal.global_position = trough.access_position(0)
	assert_eq(trough.serve(animal, needs, data, 0), 40.0)
	assert_eq(needs.satiety, 60.0)
	assert_eq(needs.hydration, 30.0)
	assert_eq(trough.stock, 2)

func test_water_caps_at_full_and_does_not_spend_stock_for_full_animals() -> void:
	trough.kind = Trough.Kind.WATER
	needs.hydration = 90.0
	assert_true(trough.claim(animal, 0, data))
	assert_eq(trough.serve(animal, needs, data, 0), 10.0)
	assert_eq(needs.hydration, 100.0)
	assert_eq(trough.serve(animal, needs, data, 0), 0.0)
	assert_eq(trough.stock, 2)

func test_species_and_portion_rules_prevent_partial_or_overdrawn_meals() -> void:
	var cow: Definition = load("res://animals/definitions/cow.tres").duplicate() as Definition
	trough.allowed_species = [int(data.species)]
	assert_false(trough.can_supply(cow))
	data.food_per_meal = 2
	needs.satiety = 0.0
	assert_true(trough.claim(animal, 0, data))
	assert_eq(trough.serve(animal, needs, data, 0), 80.0)
	assert_eq(trough.stock, 1)
	assert_eq(trough.serve(animal, needs, data, 0), 0.0)
	assert_eq(trough.stock, 1)

func test_priority_uses_lower_need_and_water_wins_ties() -> void:
	var foraging: Foraging = Foraging.new()
	add_child_autofree(foraging)
	foraging.configure(data, needs, null)
	needs.satiety = 20.0
	needs.hydration = 10.0
	assert_eq(foraging.priority_kinds(), [Trough.Kind.WATER, Trough.Kind.FOOD])
	needs.hydration = 20.0
	assert_eq(foraging.priority_kinds()[0], Trough.Kind.WATER)
	needs.hydration = 40.0
	assert_eq(foraging.priority_kinds()[0], Trough.Kind.FOOD)
	needs.satiety = 100.0
	needs.hydration = 100.0
	assert_false(foraging.has_need())

func test_scenes_switch_to_empty_art_and_back_on_refill() -> void:
	for scene_path: String in ["res://scenes/animals/feed_trough.tscn", "res://scenes/animals/water_trough.tscn"]:
		var station: Trough = (load(scene_path) as PackedScene).instantiate() as Trough
		add_child_autofree(station)
		station.stock = 0
		assert_eq((station.get_node("Sprite2D") as Sprite2D).texture, station.empty_texture)
		station.refill(1)
		assert_eq((station.get_node("Sprite2D") as Sprite2D).texture, station.full_texture)
