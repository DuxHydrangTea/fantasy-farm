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
	(player as FarmPlayer).farming_actions.farming = farm
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
	assert_true(actor.behaviour.request_behaviour(&"walk"), "Removing the player releases animal focus")

func test_hover_holds_only_selected_animal_idle_and_releases_on_leave() -> void:
	var actor: Actor = _animal()
	var other: Actor = _animal("cow")
	other.position.x += 60.0
	assert_true(actor.behaviour.request_behaviour(&"walk"))
	assert_true(other.behaviour.request_behaviour(&"walk"))
	context.refresh_at(_hover_point(actor))
	assert_eq(actor.behaviour.current_state, AnimalBehaviourComponent.State.IDLE)
	assert_false(actor.movement.has_target)
	assert_eq(other.behaviour.current_state, AnimalBehaviourComponent.State.WALK)
	assert_false(actor.behaviour.request_behaviour(&"walk"))
	context.refresh_at(Vector2.ZERO, false)
	assert_true(actor.behaviour.request_behaviour(&"walk"))

func test_focus_and_hover_share_hold_until_both_leave_and_menu_releases_it() -> void:
	var actor: Actor = _animal()
	player.position = actor.global_position + Vector2(0, 24)
	player.get_node("AnimationComponent").face(Vector2.UP)
	context.refresh_at(_hover_point(actor))
	context.refresh_at(Vector2.ZERO, false)
	assert_false(actor.behaviour.request_behaviour(&"walk"), "Focus still holds after mouse leaves")
	player.get_node("AnimationComponent").face(Vector2.DOWN)
	context.refresh_at(_hover_point(actor))
	assert_false(actor.behaviour.request_behaviour(&"walk"), "Hover still holds after turning away")
	player.get_node("ToolSelection").set_inventory_open(true)
	context.refresh_at(_hover_point(actor))
	assert_true(actor.behaviour.request_behaviour(&"walk"), "Menu releases the interaction hold")

func test_hiding_needs_bars_does_not_disable_animal_idle_response() -> void:
	var actor: Actor = _animal()
	actor.show_needs = false
	assert_true(actor.behaviour.request_behaviour(&"walk"))
	context.refresh_at(_hover_point(actor))
	assert_eq(actor.behaviour.current_state, AnimalBehaviourComponent.State.IDLE)
	assert_false(actor.needs_display.visible)
	context.refresh_at(Vector2.ZERO, false)
	assert_true(actor.behaviour.request_behaviour(&"walk"))

func after_each() -> void:
	Language.set_language("en")

func test_animal_inspector_reports_growth_lifetime_cycle_and_all_pause_reasons_without_mutation() -> void:
	var actor: Actor = _animal()
	actor.growth.configure(86400.0, 43200.0, 1209600.0)
	actor.needs.restore_state(0.0, 0.0, TimeManager.now())
	var info: AnimalInfoPanel = context.animal_info
	context.refresh_at(_hover_point(actor))
	assert_true(info.root.visible)
	assert_eq(info.animal, actor)
	assert_string_contains(info.maturity_label.text, "12h 0m")
	assert_string_contains(info.lifetime_label.text, "13d 12h")
	assert_string_contains(info.produce_label.text, "Chicken Egg")
	assert_eq(info.progress.value, 0.0)
	for reason: String in ["Not mature yet", "Needs food", "Needs water"]:
		assert_string_contains(info.state_label.text, reason)
	info.refresh()
	assert_eq(actor.growth.age_seconds, 43200.0)
	assert_eq(actor.needs.satiety, 0.0)
	assert_eq(actor.needs.hydration, 0.0)
	assert_eq(actor.production.progress_seconds, 0.0)
	actor.growth.age_seconds = 86400.0
	actor.needs.restore_state(100.0, 100.0, TimeManager.now())
	actor.production.progress_seconds = actor.production.definition.production_seconds * 0.4
	info.refresh()
	assert_eq(info.maturity_label.text, "Adult")
	assert_eq(info.state_label.text, "Producing", "Focused idle does not block production")
	assert_almost_eq(info.progress.value, 40.0, 0.001)
	assert_string_contains(info.produce_label.text, "40%")
	Language.set_language("vi")
	info.refresh()
	assert_eq(info.state_label.text, "Đang sản xuất")
	assert_string_contains(info.produce_label.text, "Trứng gà")
	assert_almost_eq(info.progress.value, 40.0, 0.001)

func test_inspector_prefers_hover_animal_then_facing_focus_and_clears_for_menus_and_death() -> void:
	var focused: Actor = _animal()
	var hovered: Actor = _animal("cow")
	hovered.position.x += 70.0
	player.position = focused.global_position + Vector2(0, 24)
	player.get_node("AnimationComponent").face(Vector2.UP)
	context.refresh_at(_hover_point(hovered))
	assert_eq(context.animal_info.animal, hovered)
	context.refresh_at(Vector2.ZERO, false)
	assert_eq(context.animal_info.animal, focused)
	player.get_node("ToolSelection").set_shop_open(true)
	context.refresh_at(_hover_point(hovered))
	assert_false(context.animal_info.root.visible)
	player.get_node("ToolSelection").set_shop_open(false)
	context.refresh_at(_hover_point(hovered))
	hovered.free()
	context.animal_info.refresh()
	assert_false(context.animal_info.root.visible)
	context.refresh_at(Vector2.ZERO, false)
	focused.growth.age_seconds = focused.growth.lifespan_seconds
	context.animal_info.refresh()
	assert_false(context.animal_info.root.visible)

func test_inspector_does_not_report_rest_or_stored_output_as_production_blockers() -> void:
	var actor: Actor = _animal("cow")
	actor.growth.age_seconds = actor.growth.maturity_seconds
	actor.needs.restore_state(100.0, 100.0, TimeManager.now())
	actor.production.stored_amount = 20
	var info: AnimalInfoPanel = context.animal_info
	info.inspect(actor)
	assert_eq(info.state_label.text, "Producing")
	actor.needs.restore_state(10.0, 0.0, TimeManager.now())
	info.refresh()
	assert_eq(info.state_label.text, "Paused: Needs water")
	assert_eq(actor.production.stored_amount, 20, "Inspection never collects or discards output")
