extends GutTest

const Fixture = preload("res://tests/support/farming_fixture.gd")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const Farming = preload("res://components/farming_controller.gd")
const Focus = preload("res://components/soil_focus_component.gd")

var field: Node2D
var farming: Farming
var player: CharacterBody2D
var focus: Focus
var state: StateComponent
var animation: AnimationComponent
var cell: Vector2i = Vector2i(20, 20)

func before_each() -> void:
	field = Fixture.create_field()
	add_child_autofree(field)
	farming = field.get_node("FarmingController")
	player = PLAYER.instantiate() as CharacterBody2D
	player.position = farming.farmland.map_to_local(cell)
	field.add_child(player)
	focus = player.get_node("SoilFocus")
	state = player.get_node("StateComponent")
	animation = player.get_node("AnimationComponent")
	await wait_physics_frames(2)

func test_atlas_is_four_corner_highlight_with_transparent_center() -> void:
	var texture: AtlasTexture = focus.marker.texture as AtlasTexture
	assert_not_null(texture)
	assert_eq(texture.region, Rect2(144, 144, 32, 32))
	assert_eq(texture.atlas.resource_path, "res://assets/Ui/Sprite sheet for Basic Pack.png")
	var pixels: Image = texture.get_image()
	assert_eq(pixels.get_size(), Vector2i(32, 32))
	assert_eq(pixels.get_pixel(16, 16).a, 0.0, "Highlight must not obscure the soil")
	assert_gt(pixels.get_pixel(6, 6).a, 0.0, "Corner is visible")

func test_focus_matches_adjacent_action_cell(direction = use_parameters([
	Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT
])) -> void:
	var target: Vector2i = cell + Vector2i(direction)
	Fixture.mark_cell(field, target)
	animation.face(direction)
	focus.refresh()
	assert_true(focus.visible)
	assert_true(focus.actionable)
	assert_eq(focus.focused_cell, target)
	assert_eq(focus.focused_cell, player.get_node("FarmingActionComponent").get_focused_cell())
	assert_eq(focus.global_position, farming.farmland.to_global(farming.farmland.map_to_local(target)))
	assert_eq(focus.marker.texture.get_size() * focus.marker.scale, Vector2(16, 16))

func test_focus_tracks_player_crossing_grid_cells() -> void:
	var before: Vector2i = focus.focused_cell
	player.position += Vector2(16, 0)
	await wait_physics_frames(2)
	assert_eq(focus.focused_cell, before + Vector2i.RIGHT)

func test_unmarked_soil_uses_blocked_color() -> void:
	focus.refresh()
	assert_true(focus.visible)
	assert_false(focus.actionable)
	assert_eq(focus.marker.modulate, focus.blocked_color)
	Fixture.mark_cell(field, cell + Vector2i.DOWN)
	focus.refresh()
	assert_true(focus.actionable)
	assert_eq(focus.marker.modulate, focus.available_color)

func test_focus_color_respects_active_tool_and_soil_state() -> void:
	var target: Vector2i = cell + Vector2i.DOWN
	Fixture.mark_cell(field, target)
	state.transition_to(StateComponent.State.WATER)
	focus.refresh()
	assert_false(focus.actionable, "Water cannot affect untilled soil")
	state.transition_to(StateComponent.State.TOOL)
	focus.refresh()
	assert_true(focus.actionable)
	assert_true(farming.till(target, player))
	focus.refresh()
	assert_false(focus.actionable, "Cannot till the same cell twice")
	state.transition_to(StateComponent.State.WATER)
	focus.refresh()
	assert_true(focus.actionable)
	assert_true(farming.water(target, player))
	focus.refresh()
	assert_false(focus.actionable, "Already wet")

func test_focus_stays_on_action_target_until_animation_finishes() -> void:
	var target: Vector2i = cell + Vector2i.DOWN
	Fixture.mark_cell(field, target)
	state.transition_to(StateComponent.State.TOOL)
	player.position += Vector2(32, 0)
	focus.refresh()
	assert_eq(focus.focused_cell, target)
	await wait_seconds(0.5)
	assert_eq(focus.focused_cell, target, "Impact must not release focus early")
	assert_eq(farming.get_soil_state(target), Farming.Soil.DRY)
	await wait_seconds(0.5)
	assert_eq(focus.focused_cell, target + Vector2i(2, 0))

func test_focus_hides_outside_map_or_without_ground_tileset() -> void:
	player.position = Vector2(-100, -100)
	focus.refresh()
	assert_false(focus.visible)
	player.position = farming.farmland.map_to_local(cell)
	field.get_node("Ground").tile_set = null
	focus.refresh()
	assert_false(focus.visible)

func test_standalone_player_hides_focus_without_farming_world() -> void:
	farming.remove_from_group("farming_controller")
	var standalone: CharacterBody2D = PLAYER.instantiate() as CharacterBody2D
	add_child_autofree(standalone)
	var standalone_focus: Focus = standalone.get_node("SoilFocus")
	standalone_focus.refresh()
	assert_false(standalone_focus.visible)

func test_focus_stays_aligned_with_map_scale_and_camera_zoom() -> void:
	field.position = Vector2(80, 40)
	field.scale = Vector2(2, 2)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.zoom = Vector2(4, 4)
	Fixture.mark_cell(field, cell + Vector2i.DOWN)
	focus.refresh()
	assert_eq(focus.global_position, farming.farmland.to_global(farming.farmland.map_to_local(cell + Vector2i.DOWN)))
	assert_eq(focus.global_transform.x, farming.farmland.global_transform.x)
	assert_eq(focus.global_transform.y, farming.farmland.global_transform.y)
	assert_eq(focus.marker.texture.get_size() * focus.marker.scale, Vector2(16, 16))

func test_blocking_custom_data_changes_focus_color() -> void:
	var target: Vector2i = cell + Vector2i.DOWN
	Fixture.mark_cell(field, target)
	farming.farmland.get_cell_tile_data(target).set_custom_data("blocks_farming", true)
	focus.refresh()
	assert_true(focus.visible)
	assert_false(focus.actionable)
	assert_eq(focus.marker.modulate, focus.blocked_color)

func test_highlight_matches_selected_tool_in_hotbar() -> void:
	var target: Vector2i = cell + Vector2i.DOWN
	Fixture.mark_cell(field, target)
	focus.refresh()
	assert_true(focus.actionable)
	state.tool_selection.select_slot(1)
	focus.refresh()
	assert_false(focus.actionable, "Selected watering can cannot water untilled grass")
	assert_true(farming.till(target, player))
	focus.refresh()
	assert_true(focus.actionable)
	state.tool_selection.select_slot(3)
	focus.refresh()
	assert_false(focus.visible, "No farming highlight for an empty slot")
