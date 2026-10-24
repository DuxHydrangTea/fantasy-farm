extends GutTest
const CHICKEN: PackedScene = preload("res://scenes/animals/chicken.tscn")
var pen: AnimalPen
var animal: AnimalActor
var clock: FarmClock
var timestamp: float = 1000.0

func before_each() -> void:
	timestamp = 1000.0
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return timestamp
	add_child_autofree(clock)
	clock.set_process(false)
	pen = AnimalPen.new()
	pen.bounds = Rect2(0, 0, 320, 200)
	add_child_autofree(pen)
	animal = _animal("chicken", Vector2(45, 95))
	await wait_physics_frames(2)

func _animal(species: String, point: Vector2) -> AnimalActor:
	var actor: AnimalActor = CHICKEN.instantiate() as AnimalActor
	actor.definition = load("res://animals/definitions/" + species + ".tres").duplicate() as AnimalDefinition
	actor.definition.move_speed = 120.0
	actor.definition.idle_seconds = Vector2(0.05, 0.05)
	actor.definition.walk_weight = 0.0
	actor.definition.forage_weight = 0.0
	actor.definition.rest_weight = 0.0
	actor.definition.sleep_weight = 0.0
	actor.position = point
	actor.get_node("WanderComponent").random_seed = 31
	actor.get_node("NeedsComponent").time_manager = clock
	pen.add_child(actor)
	actor.behaviour.request_behaviour(&"idle")
	return actor

func _trough(supply_kind: AnimalTrough.Kind, point: Vector2) -> AnimalTrough:
	var path: String = "res://scenes/animals/feed_trough.tscn" if supply_kind == AnimalTrough.Kind.FOOD else "res://scenes/animals/water_trough.tscn"
	var station: AnimalTrough = (load(path) as PackedScene).instantiate() as AnimalTrough
	station.position = point
	station.serving_seconds = 0.1
	pen.add_child(station)
	return station

func _wait_for(state: AnimalBehaviourComponent.State, frames: int = 240, actor: AnimalActor = animal) -> bool:
	for index: int in range(frames):
		if actor.behaviour.current_state == state:
			return true
		await wait_physics_frames(1)
	return false

func test_hungry_chicken_walks_to_food_and_eats_without_refilling_water() -> void:
	var station: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(160, 70))
	animal.needs.satiety = 30.0
	var start: Vector2 = animal.position
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE))
	assert_eq(station.stock, 120, "Claiming/travelling cannot spend food")
	assert_true(await _wait_for(AnimalBehaviourComponent.State.EAT))
	assert_gt(animal.position.distance_to(start), 50.0)
	assert_eq(animal.needs.satiety, 30.0, "Food is restored only after the serving delay")
	assert_true(await _wait_for(AnimalBehaviourComponent.State.IDLE))
	assert_eq(animal.needs.satiety, 70.0)
	assert_eq(animal.needs.hydration, 100.0)
	assert_eq(station.stock, 119)
	assert_true(station.slot_available(0))

func test_focus_preserves_resource_trip_and_meal(state = use_parameters([
	AnimalBehaviourComponent.State.SEEK_RESOURCE, AnimalBehaviourComponent.State.EAT,
	AnimalBehaviourComponent.State.DRINK
])) -> void:
	var kind: AnimalTrough.Kind = AnimalTrough.Kind.WATER if state == AnimalBehaviourComponent.State.DRINK else AnimalTrough.Kind.FOOD
	var station: AnimalTrough = _trough(kind, Vector2(160, 70))
	station.serving_seconds = 0.5
	if kind == AnimalTrough.Kind.FOOD:
		animal.needs.satiety = 30.0
	else:
		animal.needs.hydration = 30.0
	assert_true(await _wait_for(state))
	var slot: int = animal.foraging.target_slot
	assert_false(station.slot_available(slot))
	animal.set_status_focused(true)
	assert_eq(animal.behaviour.current_state, state)
	assert_not_null(animal.foraging.target)
	assert_false(station.slot_available(slot), "UI attention must preserve the serving reservation")
	assert_true(await _wait_for(AnimalBehaviourComponent.State.IDLE))
	assert_eq(station.stock, 119)

func test_late_meal_sync_that_reaches_death_releases_slot_without_spending_stock() -> void:
	var station: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(160, 70))
	animal.behaviour.set_physics_process(false)
	animal.needs.satiety = 30.0
	await wait_physics_frames(2)
	assert_true(animal.foraging.try_begin())
	var slot: int = animal.foraging.target_slot
	animal.global_position = station.access_position(slot)
	animal.growth.configure(0.0, 19.0, 20.0)
	timestamp += 2.0
	assert_eq(animal.foraging.finish(), 0.0)
	assert_true(animal.is_dead())
	assert_true(station.slot_available(slot))
	assert_null(animal.foraging.target)
	assert_eq(station.stock, 120)

func test_more_urgent_water_then_food_are_both_satisfied() -> void:
	_trough(AnimalTrough.Kind.FOOD, Vector2(160, 70))
	var water: AnimalTrough = _trough(AnimalTrough.Kind.WATER, Vector2(75, 70))
	animal.needs.satiety = 40.0
	animal.needs.hydration = 20.0
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE))
	assert_eq(animal.foraging.target, water)
	for index: int in range(300):
		if animal.needs.satiety > 50.0 and animal.needs.hydration > 50.0:
			break
		await wait_physics_frames(1)
	assert_eq(animal.needs.hydration, 60.0)
	assert_eq(animal.needs.satiety, 80.0)

func test_empty_other_pen_and_outside_stations_are_ignored() -> void:
	var empty: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(70, 70))
	empty.stock = 0
	var outside: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(500, 70))
	var other_pen: AnimalPen = AnimalPen.new()
	add_child_autofree(other_pen)
	var foreign: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(90, 70))
	foreign.pen = other_pen
	var valid: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(180, 70))
	animal.needs.satiety = 30.0
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE))
	assert_eq(animal.foraging.target, valid)
	assert_eq(outside.stock, 120)

func test_nearest_compatible_station_is_chosen() -> void:
	var near: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(100, 70))
	_trough(AnimalTrough.Kind.FOOD, Vector2(220, 70))
	var incompatible: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(65, 70))
	incompatible.allowed_species = [99]
	animal.needs.satiety = 30.0
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE))
	assert_eq(animal.foraging.target, near)

func test_unavailable_urgent_water_does_not_prevent_eating() -> void:
	var food: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(100, 70))
	var water: AnimalTrough = _trough(AnimalTrough.Kind.WATER, Vector2(160, 70))
	water.stock = 0
	animal.needs.satiety = 30.0
	animal.needs.hydration = 10.0
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE))
	assert_eq(animal.foraging.target, food)
	assert_true(await _wait_for(AnimalBehaviourComponent.State.EAT))
	assert_true(await _wait_for(AnimalBehaviourComponent.State.IDLE))
	assert_eq(animal.needs.satiety, 70.0)
	assert_eq(animal.needs.hydration, 10.0)

func test_no_supply_falls_back_and_refilling_empty_supply_is_discovered() -> void:
	var station: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(100, 70))
	station.stock = 0
	animal.needs.satiety = 30.0
	await wait_physics_frames(70)
	assert_ne(animal.behaviour.current_state, AnimalBehaviourComponent.State.SEEK_RESOURCE)
	assert_eq(animal.needs.satiety, 30.0)
	station.refill(1)
	assert_true(await _wait_for(AnimalBehaviourComponent.State.EAT))
	assert_true(await _wait_for(AnimalBehaviourComponent.State.IDLE))
	assert_eq(animal.needs.satiety, 70.0)
	assert_eq(station.stock, 0)

func test_deleted_target_cancels_without_restoring_food_or_leaking_reservation() -> void:
	var station: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(160, 70))
	animal.needs.satiety = 30.0
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE))
	station.queue_free()
	await wait_physics_frames(3)
	assert_eq(animal.behaviour.current_state, AnimalBehaviourComponent.State.IDLE)
	assert_null(animal.foraging.target)
	assert_eq(animal.needs.satiety, 30.0)

func test_moved_target_releases_old_slot_without_remote_feeding() -> void:
	var station: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(160, 70))
	animal.needs.satiety = 30.0
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE))
	station.position += Vector2(60, 0)
	await wait_physics_frames(2)
	assert_eq(animal.behaviour.current_state, AnimalBehaviourComponent.State.IDLE)
	assert_true(station.slot_available(0))
	assert_eq(station.stock, 120)
	assert_eq(animal.needs.satiety, 30.0)

func test_last_portion_cannot_be_consumed_twice_by_competing_animals() -> void:
	var station: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(120, 70))
	station.stock = 1
	var other: AnimalActor = _animal("chicken", Vector2(190, 95))
	animal.needs.satiety = 30.0
	other.needs.satiety = 30.0
	await wait_physics_frames(200)
	assert_eq(station.stock, 0)
	assert_eq(animal.needs.satiety + other.needs.satiety, 100.0, "Exactly one 40-point meal is available")
	assert_true(station.slot_available(0))
	assert_true(station.slot_available(1))

func test_station_emptying_during_service_does_not_create_food() -> void:
	var station: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(80, 70))
	station.serving_seconds = 1.0
	animal.needs.satiety = 30.0
	assert_true(await _wait_for(AnimalBehaviourComponent.State.EAT))
	station.stock = 0
	await wait_physics_frames(3)
	assert_eq(animal.behaviour.current_state, AnimalBehaviourComponent.State.IDLE)
	assert_eq(animal.needs.satiety, 30.0)
	assert_true(station.slot_available(0))

func test_sleeping_chicken_finishes_standing_up_before_seeking() -> void:
	_trough(AnimalTrough.Kind.WATER, Vector2(100, 70))
	animal.definition.sleep_seconds = Vector2(10, 10)
	assert_true(animal.behaviour.request_behaviour(&"sleep"))
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SLEEP))
	animal.needs.hydration = 20.0
	assert_true(await _wait_for(AnimalBehaviourComponent.State.STAND_UP))
	assert_null(animal.foraging.target)
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE))
	assert_true(await _wait_for(AnimalBehaviourComponent.State.DRINK))

func test_animals_reserve_different_slots_and_shared_logic_serves_other_species() -> void:
	var station: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(160, 70))
	var cow: AnimalActor = _animal("cow", Vector2(220, 100))
	animal.needs.satiety = 30.0
	cow.needs.satiety = 30.0
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE))
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE, 240, cow))
	assert_ne(animal.foraging.target_slot, cow.foraging.target_slot)
	for index: int in range(300):
		if animal.needs.satiety > 50.0 and cow.needs.satiety > 50.0:
			break
		await wait_physics_frames(1)
	assert_eq(animal.needs.satiety, 70.0)
	assert_eq(cow.needs.satiety, 70.0)
	assert_eq(station.stock, 118)

func test_obstructed_nearest_station_is_skipped_for_clear_station() -> void:
	var blocked: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(120, 70))
	var clear: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(45, 160))
	var wall: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(12, 70)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector2(85, 80)
	pen.add_child(wall)
	await wait_physics_frames(2)
	animal.needs.satiety = 30.0
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE))
	assert_eq(animal.foraging.target, clear)
	assert_true(await _wait_for(AnimalBehaviourComponent.State.EAT))
	assert_eq(blocked.stock, 120)

func test_new_obstacle_abandons_blocked_trip_and_uses_another_station() -> void:
	var blocked: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(110, 70))
	var clear: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(45, 180))
	animal.needs.satiety = 30.0
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE))
	assert_eq(animal.foraging.target, blocked)
	var wall: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(12, 70)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector2(85, 80)
	pen.add_child(wall)
	assert_true(await _wait_for(AnimalBehaviourComponent.State.EAT, 360))
	assert_eq(animal.foraging.target, clear)
	assert_eq(blocked.stock, 120)
	assert_true(blocked.slot_available(0))

func test_removing_pen_releases_slot_and_stops_animal() -> void:
	var station: AnimalTrough = _trough(AnimalTrough.Kind.FOOD, Vector2(160, 70))
	animal.needs.satiety = 30.0
	assert_true(await _wait_for(AnimalBehaviourComponent.State.SEEK_RESOURCE))
	animal.wander.pen = null
	await wait_physics_frames(2)
	assert_eq(animal.behaviour.current_state, AnimalBehaviourComponent.State.IDLE)
	assert_true(station.slot_available(0))
	assert_false(animal.movement.has_target)

func test_farm_contains_working_prefilled_food_and_water_in_the_pen() -> void:
	var world: Node = preload("res://world/main_world.tscn").instantiate()
	add_child_autofree(world)
	var enclosure: AnimalPen = world.get_node("CoopPen") as AnimalPen
	var counts: Vector2i = Vector2i.ZERO
	for child: Node in enclosure.get_children():
		var station: AnimalTrough = child as AnimalTrough
		if station == null:
			continue
		assert_eq(station.pen, enclosure)
		assert_gt(station.stock, 0)
		var usable_slots: int = 0
		for offset: Vector2 in station.access_offsets:
			if enclosure.contains_world(station.to_global(offset), 12.0):
				usable_slots += 1
		# Beside a fence, outward slots are filtered by Foraging; inward slots remain usable.
		assert_gt(usable_slots, 0, "Each prefilled station needs an approach inside the pen")
		if station.kind == AnimalTrough.Kind.FOOD:
			counts.x += 1
		else:
			counts.y += 1
	assert_eq(counts, Vector2i(2, 2))
