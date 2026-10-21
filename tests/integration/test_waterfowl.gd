extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: Node2D
var pen: PondPen
var clock: FarmClock
var timestamp: float = 1000.0
var adapter: WorldStateAdapter

func before_each() -> void:
	timestamp = 1000.0
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return timestamp
	add_child_autofree(clock)
	clock.set_process(false)
	world = WORLD.instantiate() as Node2D
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter") or child.name in [&"CoopPen", &"BarnPen"]:
			child.free()
	pen = world.get_node("PondPen") as PondPen
	world.get_node("FarmingController").time_manager = clock
	world.get_node("FlowerGarden").time_manager = clock
	for actor: AnimalActor in _actors():
		actor.get_node("NeedsComponent").time_manager = clock
	add_child_autofree(world)
	world.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	for actor: AnimalActor in _actors():
		actor.behaviour.set_physics_process(false)
	await wait_physics_frames(3)
	adapter = WorldStateAdapter.new(world, SaveCatalog.new())

func _actors() -> Array[AnimalActor]:
	var result: Array[AnimalActor] = []
	for node: Node in pen.get_children():
		if node is AnimalActor:
			result.append(node)
	return result

func _actor(id: String) -> AnimalActor:
	for actor: AnimalActor in _actors():
		if String(actor.persistent_id) == id:
			return actor
	return null

func test_scene_has_all_five_ducks_and_six_geese_with_valid_spawns() -> void:
	assert_true(pen.navigation_ready)
	assert_eq(_actors().size(), 11)
	var skins: Dictionary = {}
	for actor: AnimalActor in _actors():
		assert_not_null(actor.waterfowl)
		assert_true(pen.contains_world(actor.global_position, actor.wander.margin))
		assert_true(actor.wander._target_is_clear(actor.global_position))
		skins[actor.skin_frames.resource_path] = true
		if not actor.definition.can_swim:
			assert_false(pen.is_water(actor.global_position))
	assert_eq(skins.size(), 11)
	assert_true(skins.has("res://sprite_frames/animals/duck_in_a_hat_frames.tres"))
	assert_eq(int(pen.get_node("FeedTrough").stock), 600)
	assert_eq(int(pen.get_node("WaterTrough").stock), 600)
	assert_eq(world.get_node("Fence").get_cell_source_id(Vector2i(89,38)), -1)
	assert_eq(world.get_node("Fence").get_cell_source_id(Vector2i(89,39)), -1)

func test_duck_uses_swim_idle_swim_sleep_and_returns_to_land_animation() -> void:
	var duck: AnimalActor = pen.get_node("Duck_3") as AnimalActor
	assert_true(pen.is_water(duck.global_position))
	duck.animation.play("walk")
	assert_eq(duck.sprite.animation, &"swim_down")
	duck.animation.play("idle")
	assert_eq(duck.sprite.animation, &"swim_idle_down")
	assert_true(duck.behaviour.request_behaviour(&"sleep"))
	assert_eq(duck.sprite.animation, &"swim_sleep_down")
	assert_true(duck.behaviour.wake())
	duck.global_position = pen.closest_land(duck.global_position)
	duck.waterfowl.refresh_visual()
	duck.animation.play("walk")
	assert_eq(duck.sprite.animation, &"walk_down")

func test_goose_rejects_water_route_while_duck_can_cross_shore() -> void:
	var goose: AnimalActor = pen.get_node("Goose_1") as AnimalActor
	var duck: AnimalActor = pen.get_node("Duck_3") as AnimalActor
	assert_false(pen.route(goose.global_position, duck.global_position, false).size() > 0)
	assert_false(goose.waterfowl.set_destination(duck.global_position))
	var route: PackedVector2Array = pen.route(goose.global_position, duck.global_position, true)
	assert_gt(route.size(), 1)
	var shore: PackedVector2Array = pen.land_route(duck.global_position)
	assert_false(shore.is_empty())
	assert_false(pen.is_water(shore[-1]))

func test_focused_swimming_duck_holds_idle_and_defers_shore_delivery_until_release() -> void:
	var duck: AnimalActor = pen.get_node("Duck_3") as AnimalActor
	assert_true(duck.behaviour.request_behaviour(&"sleep"))
	duck.production.advance(40.0)
	duck.set_status_focused(true)
	duck.behaviour.set_physics_process(true)
	var before: Vector2 = duck.global_position
	await wait_physics_frames(30)
	assert_eq(duck.behaviour.current_state, AnimalBehaviourComponent.State.IDLE)
	assert_eq(duck.sprite.animation, &"swim_idle_down")
	assert_eq(duck.global_position, before)
	assert_false(duck.movement.has_target)
	assert_eq(duck.production.stored_amount, 1)
	assert_null(duck.product_pickup())
	duck.set_status_focused(false)
	for index: int in range(900):
		if duck.product_pickup() != null:
			break
		await wait_physics_frames(1)
	duck.behaviour.set_physics_process(false)
	assert_not_null(duck.product_pickup())
	assert_eq(duck.production.stored_amount, 0)

func test_death_in_water_preserves_completed_eggs_on_shore_without_waiting_for_movement() -> void:
	var duck: AnimalActor = pen.get_node("Duck_3") as AnimalActor
	assert_true(pen.is_water(duck.global_position))
	duck.production.advance(40.0)
	duck.growth.configure(0.0, 19.0, 20.0)
	duck.needs.update_at(timestamp + 2.0)
	assert_true(duck.is_dead())
	assert_true(duck.is_queued_for_deletion())
	var pile: ItemPickup = duck.product_pickup()
	assert_not_null(pile)
	assert_false(pen.is_water(pile.global_position))
	assert_eq(pile.amount, 1)
	assert_false(duck.movement.has_target)
	await wait_physics_frames(2)
	assert_false(is_instance_valid(duck))
	assert_true(is_instance_valid(pile))

func test_egg_waits_in_stock_on_water_then_duck_walks_ashore_to_drop_once() -> void:
	var duck: AnimalActor = pen.get_node("Duck_3") as AnimalActor
	duck.production.advance(40.0)
	assert_eq(duck.production.stored_amount, 1)
	assert_null(duck.product_pickup())
	duck.behaviour.set_physics_process(true)
	for index: int in range(900):
		if duck.product_pickup() != null:
			break
		await wait_physics_frames(1)
	duck.behaviour.set_physics_process(false)
	assert_not_null(duck.product_pickup())
	if duck.product_pickup() != null:
		assert_false(pen.is_water(duck.global_position))
		assert_false(pen.is_water(duck.product_pickup().global_position))
		assert_eq(duck.product_pickup().amount, 1)
		assert_eq(duck.production.stored_amount, 0)
		duck._on_produced(0)
		assert_eq(duck.product_pickup().amount, 1)

func test_goose_egg_always_drops_on_land() -> void:
	var goose: AnimalActor = pen.get_node("Goose_1") as AnimalActor
	goose.production.advance(50.0)
	assert_not_null(goose.product_pickup())
	assert_eq(goose.product_pickup().item.item_id, &"goose_egg")
	assert_false(pen.is_water(goose.product_pickup().global_position))

func test_hungry_duck_navigates_from_water_to_feed_trough() -> void:
	var duck: AnimalActor = pen.get_node("Duck_4") as AnimalActor
	duck.needs.satiety = 0.0
	duck.behaviour.set_physics_process(true)
	for index: int in range(1600):
		if duck.needs.satiety > 0.0:
			break
		await wait_physics_frames(1)
	duck.behaviour.set_physics_process(false)
	assert_gt(duck.needs.satiety, 0.0)
	assert_lt(int(pen.get_node("FeedTrough").stock), 600)
	assert_false(pen.is_water(duck.global_position))

func test_patrol_keeps_geese_on_land_and_every_bird_inside_fence() -> void:
	for actor: AnimalActor in _actors():
		actor.behaviour.set_physics_process(true)
	for index: int in range(240):
		await wait_physics_frames(1)
		for actor: AnimalActor in _actors():
			assert_true(pen.contains_world(actor.global_position, actor.wander.margin))
			if not actor.definition.can_swim:
				assert_false(pen.is_water(actor.global_position))

func test_file_roundtrip_restores_pending_eggs_without_spawning_them_underwater() -> void:
	var duck: AnimalActor = pen.get_node("Duck_3") as AnimalActor
	duck.growth.configure(duck.definition.maturity_seconds, duck.definition.maturity_seconds, duck.definition.lifespan_seconds)
	duck.production.advance(40.0)
	var id: String = String(duck.persistent_id)
	var saved: Dictionary = adapter.capture("test", 1, timestamp)
	var folder: String = "res://.godot/pond_save_" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repo: LocalSaveRepository = LocalSaveRepository.new(folder, SaveCatalog.new())
	assert_true(repo.write_profile("test", saved, 0).ok)
	assert_true(adapter.restore(repo.read_profile("test").snapshot, 1080.0).ok)
	duck = _actor(id)
	assert_not_null(duck)
	assert_eq(duck.production.stored_amount, 3)
	assert_null(duck.product_pickup())
	assert_true(pen.is_water(duck.global_position))
	DirAccess.remove_absolute(repo.path("test"))
	DirAccess.remove_absolute(folder)

func test_old_save_initializes_pond_once_and_later_load_does_not_resurrect_removed_birds() -> void:
	var legacy: Dictionary = adapter.capture("test", 1, timestamp)
	legacy.erase("animal_pens")
	legacy.animals = []
	legacy.troughs = []
	legacy.pickups = []
	assert_true(adapter.restore(legacy, timestamp).ok)
	assert_eq(_actors().size(), 11)
	assert_eq(pen.get_node("PoultryFeed").amount, 5)
	pen.get_node("Duck_1").free()
	var saved: Dictionary = adapter.capture("test", 2, timestamp)
	assert_true(adapter.restore(saved, timestamp).ok)
	assert_eq(_actors().size(), 10)
	assert_null(_actor("pond_duck_01"))

func test_missing_trough_in_an_initialized_pond_rejects_load_atomically() -> void:
	var saved: Dictionary = adapter.capture("test", 1, timestamp)
	saved.troughs.pop_back()
	assert_false(adapter.restore(saved, timestamp).ok)
	assert_eq(_actors().size(), 11)
