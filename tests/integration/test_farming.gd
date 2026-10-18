extends GutTest

const Fixture = preload("res://tests/support/farming_fixture.gd")
const Farming = preload("res://components/farming_controller.gd")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
var field: Node2D
var farming: Farming
var player: CharacterBody2D
var state: StateComponent
var animation: AnimationComponent
var cell: Vector2i = Vector2i(20, 20)

func before_each() -> void:
	Input.action_release(&"farmer_tool")
	Input.action_release(&"farmer_water")
	field = Fixture.create_field()
	add_child_autofree(field)
	farming = field.get_node("FarmingController")
	player = PLAYER.instantiate() as CharacterBody2D
	player.position = farming.farmland.map_to_local(cell)
	field.add_child(player)
	state = player.get_node("StateComponent")
	animation = player.get_node("AnimationComponent")
	await wait_physics_frames(2)

func after_each() -> void:
	Input.action_release(&"farmer_tool")
	Input.action_release(&"farmer_water")

func test_tool_then_water_changes_only_facing_tile_at_impact(direction = use_parameters([
	Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT
])) -> void:
	var target: Vector2i = cell + Vector2i(direction)
	Fixture.mark_cell(field, target)
	Fixture.mark_cell(field, cell)
	animation.face(direction)
	watch_signals(farming)
	for index: int in [0, 1]:
		var previous: int = farming.get_soil_state(target)
		player.get_node("ToolSelection").select_slot(index)
		assert_true(state.use_selected_tool())
		await wait_physics_frames(2)
		assert_eq(farming.get_soil_state(target), previous, "No change before impact frame")
		await wait_seconds(0.9)
		assert_eq(farming.get_soil_state(target), previous + 1)
		assert_eq(state.current_state, StateComponent.State.IDLE)
	assert_eq(farming.get_soil_state(cell), Farming.Soil.UNTILLED)
	assert_signal_emit_count(farming, "soil_changed", 2)

func test_dry_and_wet_terrain_join_adjacent_cells(offset = use_parameters([Vector2i.RIGHT, Vector2i.DOWN])) -> void:
	Fixture.mark_cell(field, cell)
	Fixture.mark_cell(field, cell + offset)
	assert_true(farming.till(cell, player))
	var dry_before: Vector2i = farming.dry_soil.get_cell_atlas_coords(cell)
	assert_true(farming.till(cell + offset, player))
	assert_ne(farming.dry_soil.get_cell_atlas_coords(cell), dry_before)
	assert_true(farming.water(cell, player))
	assert_eq(farming.get_soil_state(cell + offset), Farming.Soil.DRY)
	var wet_before: Vector2i = farming.wet_soil.get_cell_atlas_coords(cell)
	assert_true(farming.water(cell + offset, player))
	assert_ne(farming.wet_soil.get_cell_atlas_coords(cell), wet_before)
	var side: int = TileSet.CELL_NEIGHBOR_RIGHT_SIDE if offset.x != 0 else TileSet.CELL_NEIGHBOR_BOTTOM_SIDE
	var opposite: int = TileSet.CELL_NEIGHBOR_LEFT_SIDE if offset.x != 0 else TileSet.CELL_NEIGHBOR_TOP_SIDE
	for layer: TileMapLayer in [farming.dry_soil, farming.wet_soil]:
		assert_eq(layer.get_cell_tile_data(cell).get_terrain_peering_bit(side), 0)
		assert_eq(layer.get_cell_tile_data(cell + offset).get_terrain_peering_bit(opposite), 0)

func test_rectangle_keeps_all_soil_cells_connected() -> void:
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		Fixture.mark_cell(field, cell + offset)
		assert_true(farming.till(cell + offset, player))
		assert_true(farming.water(cell + offset, player))
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		assert_eq(farming.get_soil_state(cell + offset), Farming.Soil.WET)
		assert_eq(farming.dry_soil.get_cell_tile_data(cell + offset).terrain, 0)

func test_tree_collision_blocks_till_water_and_plant() -> void:
	var target: Vector2i = cell + Vector2i.DOWN
	Fixture.mark_cell(field, target)
	assert_true(farming.till(target, player))
	var tree: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(12, 8)
	collision.shape = shape
	tree.add_child(collision)
	tree.position = farming.farmland.map_to_local(target)
	field.add_child(tree)
	await wait_physics_frames(2)
	assert_false(farming.can_till(target, player))
	assert_false(farming.can_water(target, player))
	assert_false(farming.can_plant(target, player))
	assert_false(farming.water(target, player))

func test_cancel_before_impact_does_not_modify_soil() -> void:
	Fixture.mark_cell(field, cell + Vector2i.DOWN)
	state.transition_to(StateComponent.State.TOOL)
	state.transition_to(StateComponent.State.IDLE)
	await wait_seconds(0.9)
	assert_eq(farming.get_soil_state(cell + Vector2i.DOWN), Farming.Soil.UNTILLED)

func test_unmarked_ground_remains_protected_after_actions() -> void:
	state.transition_to(StateComponent.State.TOOL)
	await wait_seconds(0.9)
	state.transition_to(StateComponent.State.WATER)
	await wait_seconds(0.9)
	assert_eq(farming.dry_soil.get_used_cells().size(), 0)
	assert_eq(farming.wet_soil.get_used_cells().size(), 0)

func test_target_mapping_handles_translated_and_scaled_field() -> void:
	field.position = Vector2(100, 60)
	field.scale = Vector2(2, 2)
	Fixture.mark_cell(field, cell + Vector2i.LEFT)
	animation.face(Vector2.LEFT)
	state.transition_to(StateComponent.State.TOOL)
	await wait_seconds(0.9)
	assert_eq(farming.get_soil_state(cell + Vector2i.LEFT), Farming.Soil.DRY)
