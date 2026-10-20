extends GutTest
const Fixture = preload("res://tests/support/farming_fixture.gd")
const Farming = preload("res://components/farming_controller.gd")
const Context = preload("res://components/context_bars_component.gd")
const Actor = preload("res://components/animals/animal_actor.gd")
const Pen = preload("res://components/animals/animal_pen.gd")
const Garden = preload("res://components/flowers/flower_garden.gd")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const ANIMAL: PackedScene = preload("res://scenes/animals/animal.tscn")
var field: Node2D
var farm: Farming
var player: CharacterBody2D
var context: Context

func before_each() -> void:
	field = Fixture.create_field()
	add_child_autofree(field)
	farm = field.get_node("FarmingController") as Farming
	player = PLAYER.instantiate() as CharacterBody2D
	player.position = Vector2(-1000, -1000)
	field.add_child(player)
	player.get_node("StateComponent").set_physics_process(false)
	context = player.get_node("ContextBars") as Context
	context.set_physics_process(false)

func _crop(cell: Vector2i = Vector2i(20, 20)) -> Node2D:
	Fixture.mark_cell(field, cell)
	farm.restore_crop(cell, load("res://crops/field/carrot/carrot.tres"), 1000.0, 1120.0, 0.5, 1060.0)
	return farm.get_crop(cell)

func _animal(id: String = "chicken") -> Actor:
	var pen: Pen = Pen.new()
	pen.position = Vector2(700, 700)
	pen.bounds = Rect2(-100, -100, 200, 200)
	field.add_child(pen)
	var actor: Actor = ANIMAL.instantiate() as Actor
	var path: String = "res://animals/definitions/%s.tres" % id
	actor.definition = load(path)
	pen.add_child(actor)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	return actor

func _hover_point(target: Node2D) -> Vector2:
	var sprite: Node2D = target.get_status_sprite()
	return sprite.to_global(context._sprite_bounds(sprite).get_center())

func test_crops_are_hidden_until_hover_and_hide_when_pointer_leaves() -> void:
	var crop: Node2D = _crop()
	assert_false(crop.get_node("Progress").visible)
	var point: Vector2 = _hover_point(crop)
	context.refresh_at(point)
	assert_true(crop.get_node("Progress").visible)
	crop.refresh(1120.0)
	assert_true(crop.get_node("Progress").visible, "Maturity cannot override focus visibility")
	context.refresh_at(point + Vector2(100, 100))
	assert_false(crop.get_node("Progress").visible)
	assert_true(crop.is_mature(), "Visibility cannot change growth")

func test_facing_crop_is_visible_without_hover_then_hides_on_turn() -> void:
	var crop: Node2D = _crop()
	player.position = farm.farmland.map_to_local(Vector2i(20, 21))
	player.get_node("AnimationComponent").face(Vector2.UP)
	context.refresh_at(Vector2.ZERO, false)
	assert_true(crop.get_node("Progress").visible)
	player.get_node("AnimationComponent").face(Vector2.DOWN)
	context.refresh_at(Vector2.ZERO, false)
	assert_false(crop.get_node("Progress").visible)

func test_all_animal_species_hide_needs_until_hover_and_preserve_values(id = use_parameters([
	"chicken", "cow", "sheep", "duck", "goose", "pig", "horse"
])) -> void:
	var actor: Actor = _animal(id)
	var display: Node2D = actor.get_node("NeedsDisplay") as Node2D
	assert_false(display.visible)
	context.refresh_at(_hover_point(actor))
	assert_true(display.visible)
	actor._update_needs_display(42.0, 37.0)
	assert_eq(actor.get_node("NeedsDisplay/Satiety").value, 42.0)
	assert_eq(actor.get_node("NeedsDisplay/Hydration").value, 37.0)
	context.refresh_at(Vector2(-2000, -2000))
	assert_false(display.visible)
	assert_eq(actor.get_node("NeedsDisplay/Satiety").value, 42.0)

func test_nearby_animal_in_front_is_focused_and_show_needs_remains_master_switch() -> void:
	var actor: Actor = _animal()
	player.position = actor.global_position + Vector2(0, 24)
	player.get_node("AnimationComponent").face(Vector2.UP)
	context.refresh_at(Vector2.ZERO, false)
	assert_true(actor.get_node("NeedsDisplay").visible)
	player.get_node("AnimationComponent").face(Vector2.DOWN)
	context.refresh_at(Vector2.ZERO, false)
	assert_false(actor.get_node("NeedsDisplay").visible)
	actor.show_needs = false
	context.refresh_at(_hover_point(actor))
	assert_false(actor.get_node("NeedsDisplay").visible)

func test_focus_and_mouse_may_reveal_two_targets_but_other_crops_stay_hidden() -> void:
	var crop: Node2D = _crop()
	var other: Node2D = _crop(Vector2i(30, 20))
	var actor: Actor = _animal()
	player.position = farm.farmland.map_to_local(Vector2i(20, 21))
	player.get_node("AnimationComponent").face(Vector2.UP)
	context.refresh_at(_hover_point(actor))
	assert_true(crop.get_node("Progress").visible)
	assert_true(actor.get_node("NeedsDisplay").visible)
	assert_false(other.get_node("Progress").visible)
	player.get_node("ToolSelection").set_inventory_open(true)
	context.refresh_at(_hover_point(actor))
	assert_false(crop.get_node("Progress").visible)
	assert_false(actor.get_node("NeedsDisplay").visible)

func test_mouse_near_visible_leaves_respects_zoom_and_map_transform() -> void:
	field.position = Vector2(110, -70)
	field.scale = Vector2(1.5, 1.5)
	player.get_node("Camera2D").zoom = Vector2(1.2, 1.2)
	var crop: Node2D = _crop()
	var sprite: Node2D = crop.get_status_sprite()
	var rect: Rect2 = context._sprite_bounds(sprite)
	context.refresh_at(sprite.to_global(Vector2(rect.end.x + 2.0, rect.get_center().y)))
	assert_true(crop.get_node("Progress").visible, "Near the leaves also counts as hover")
	context.refresh_at(_hover_point(crop), false)
	assert_false(crop.get_node("Progress").visible, "Pointer outside the viewport cannot reveal bars")

func test_potted_flower_hover_does_not_create_focus_marker_and_empty_pots_have_no_bar() -> void:
	var garden: Garden = preload("res://scenes/flowers/flower_garden.tscn").instantiate() as Garden
	field.add_child(garden)
	var pot: Node2D = garden.pots[Vector2i.ZERO]
	pot.restore_state({"planted_at": 1000.0, "growth_started_at": 1000.0, "matures_at": 1120.0, "progress": 0.5}, load("res://flowers/definitions/flower_01.tres"), 1060.0)
	assert_false(pot.get_node("Progress").visible)
	context.refresh_at(_hover_point(pot))
	assert_true(pot.get_node("Progress").visible)
	assert_false(pot.get_node("Focus").visible)
	pot.refresh(1120.0)
	assert_true(pot.get_node("Progress").visible)
	pot.clear()
	context.refresh_at(pot.global_position)
	assert_false(pot.get_node("Progress").visible)

func test_freeing_hovered_crop_and_leaving_scene_clears_bars_safely() -> void:
	var crop: Node2D = _crop()
	context.refresh_at(_hover_point(crop))
	crop.free()
	context.refresh_at(Vector2.ZERO, false)
	var actor: Actor = _animal()
	context.refresh_at(_hover_point(actor))
	assert_true(actor.get_node("NeedsDisplay").visible)
	player.remove_child(context)
	context.free()
	assert_false(actor.get_node("NeedsDisplay").visible)
