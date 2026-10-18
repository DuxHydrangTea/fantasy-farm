extends GutTest
const CHICKEN: PackedScene = preload("res://scenes/animals/chicken.tscn")
const BASE: PackedScene = preload("res://scenes/animals/animal.tscn")
const Actor = preload("res://components/animals/animal_actor.gd")
const Pen = preload("res://components/animals/animal_pen.gd")
const Definition = preload("res://scripts/animals/animal_definition.gd")
var field: Node2D
var pen: Pen
var chicken: Actor

func before_each() -> void:
	field = Node2D.new()
	add_child_autofree(field)
	pen = Pen.new()
	pen.bounds = Rect2(0, 0, 240, 180)
	field.add_child(pen)
	chicken = CHICKEN.instantiate() as Actor
	chicken.pen = pen
	chicken.position = Vector2(100, 90)
	chicken.get_node("WanderComponent").random_seed = 123
	field.add_child(chicken)
	await wait_physics_frames(2)

func test_chicken_walks_and_stays_inside_pen_over_time() -> void:
	var origin: Vector2 = chicken.position
	var furthest: float = 0.0
	for index: int in range(180):
		await wait_physics_frames(1)
		furthest = maxf(furthest, chicken.position.distance_to(origin))
		assert_true(pen.contains_world(chicken.global_position, chicken.wander.margin))
		if chicken.movement.has_target:
			assert_true(pen.contains_world(chicken.movement.target_position, chicken.wander.margin))
	assert_gt(furthest, 8.0)

func test_forced_escape_and_outside_target_are_constrained() -> void:
	chicken.position = Vector2(-300, 800)
	chicken.movement.set_target(Vector2(2000, -2000))
	await wait_physics_frames(2)
	assert_true(pen.contains_world(chicken.global_position, chicken.wander.margin))
	if chicken.movement.has_target:
		assert_true(pen.contains_world(chicken.movement.target_position, chicken.wander.margin))

func test_single_direction_sprite_flips_correctly_and_stops_when_no_pen() -> void:
	chicken.movement.set_target(chicken.position + Vector2(-40, 0))
	await wait_physics_frames(6)
	assert_eq(chicken.sprite.animation, &"walk_down")
	assert_false(chicken.sprite.flip_h)
	chicken.movement.stop()
	chicken.movement.set_target(chicken.position + Vector2(40, 0))
	await wait_physics_frames(6)
	assert_true(chicken.sprite.flip_h)
	chicken.wander.pen = null
	var before: Vector2 = chicken.position
	await wait_physics_frames(6)
	assert_eq(chicken.position, before)
	assert_eq(chicken.sprite.animation, &"idle_down")
	assert_false(chicken.movement.has_target)

func test_wall_collision_and_target_sampling_do_not_enter_obstacle() -> void:
	var wall: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(20, 160)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = Vector2(150, 90)
	field.add_child(wall)
	chicken.movement.speed = 100.0
	chicken.movement.set_target(Vector2(210, 90))
	await wait_physics_frames(40)
	assert_lt(chicken.position.x, 136.0, "Feet cannot pass through the coop/wall collider")
	assert_false(chicken.wander._target_is_clear(wall.global_position))

func test_base_animal_supports_other_species_data(species_name = use_parameters(["cow", "sheep", "pig"])) -> void:
	var animal: Actor = BASE.instantiate() as Actor
	var path: String = "res://animals/definitions/%s.tres" % species_name
	animal.definition = load(path) as Definition
	animal.position = Vector2(40, 40)
	field.add_child(animal)
	assert_true(animal.definition.is_valid())
	assert_eq(animal.sprite.sprite_frames, animal.definition.adult_frames)
	assert_eq(animal.movement.speed, animal.definition.move_speed)
	assert_eq(animal.needs.satiety_depletion_seconds, animal.definition.satiety_depletion_seconds)
	assert_eq(animal.sprite.animation, &"idle_down")
	assert_false(animal.movement.has_target, "No assigned pen means no wandering")
	assert_ne(animal.get_node("CollisionShape2D").shape, chicken.get_node("CollisionShape2D").shape)

func test_skin_override_and_needs_display_follow_individual_animal() -> void:
	var other: Actor = CHICKEN.instantiate() as Actor
	other.skin_frames = load("res://sprite_frames/animals/chicken_18_frames.tres") as SpriteFrames
	other.position = Vector2(40, 40)
	field.add_child(other)
	assert_eq(other.sprite.sprite_frames, other.skin_frames)
	other.needs.update_at(other.needs.time_manager.now() + 150.0)
	assert_almost_eq(other.get_node("NeedsDisplay/Hydration").value, 50.0, 0.001)
	assert_gt(chicken.needs.hydration, 99.0)

func test_parent_pen_is_used_automatically_and_sorting_is_preserved() -> void:
	var enclosure: Node2D = preload("res://scenes/animals/animal_pen.tscn").instantiate() as Node2D
	enclosure.position = Vector2(500, 400)
	enclosure.scale = Vector2(1.5, 1.5)
	field.add_child(enclosure)
	var animal: Actor = CHICKEN.instantiate() as Actor
	animal.position = Vector2(100, 80)
	enclosure.add_child(animal)
	await wait_physics_frames(3)
	assert_eq(animal.pen, enclosure)
	assert_eq(animal.wander.pen, enclosure)
	assert_true(enclosure.y_sort_enabled)
	assert_true(animal.pen.contains_world(animal.global_position, animal.wander.margin))

func test_invalid_skin_falls_back_to_valid_species_frames() -> void:
	var animal: Actor = CHICKEN.instantiate() as Actor
	animal.skin_frames = SpriteFrames.new()
	field.add_child(animal)
	assert_eq(animal.sprite.sprite_frames, animal.definition.adult_frames)

func test_world_has_nine_distinct_chicken_skins_without_duplicate_spawns() -> void:
	var world: Node = preload("res://world/main_world.tscn").instantiate()
	var skins: Dictionary[String, int] = {}
	var count: int = 0
	for child: Node in world.get_node("CoopPen").get_children():
		if child.scene_file_path != CHICKEN.resource_path:
			continue
		var animal: Actor = child as Actor
		var frames: SpriteFrames = animal.skin_frames if animal.skin_frames != null else animal.definition.adult_frames
		skins[frames.resource_path] = skins.get(frames.resource_path, 0) + 1
		count += 1
	assert_eq(count, 9)
	for index: int in range(1, 10):
		var path: String = "res://sprite_frames/animals/chicken_%02d_frames.tres" % index
		assert_eq(skins.get(path, 0), 1, "Exactly one chicken for each requested skin")
	world.free()

func test_needs_bars_use_the_same_pixel_frame_as_crop_progress() -> void:
	var crop: Node = preload("res://scenes/crops/crop.tscn").instantiate()
	var crop_frame: TextureRect = crop.get_node("Progress")
	for prefix: String in ["Satiety", "Hydration"]:
		var frame: TextureRect = chicken.get_node("NeedsDisplay/" + prefix + "Frame")
		var bar: ProgressBar = chicken.get_node("NeedsDisplay/" + prefix)
		assert_eq(frame.texture, crop_frame.texture)
		assert_eq(frame.size, Vector2(15, 7))
		assert_true(frame.get_global_rect().encloses(bar.get_global_rect()))
		assert_eq(frame.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_false(bar.show_percentage)
	crop.free()
