extends GutTest
const Fixture = preload("res://tests/support/farming_fixture.gd")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
var field: Node2D
var farm: FarmingController
var player: FarmPlayer
var origin: Vector2i = Vector2i(20, 24)

func before_each() -> void:
	field = Fixture.create_field()
	add_child_autofree(field)
	farm = field.get_node("FarmingController")
	player = PLAYER.instantiate() as FarmPlayer
	player.position = farm.farmland.map_to_local(origin)
	player.farming_actions.farming = farm
	player.farming_actions.upgrades = ToolUpgradeState.new()
	var progress: Dictionary = ToolUpgradeState.fresh()
	for key: String in progress:
		progress[key] = {"level": 3, "selected_size": 3}
	player.farming_actions.upgrades.restore(progress)
	field.add_child(player)
	await wait_physics_frames(2)

func _mark(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		Fixture.mark_cell(field, cell)

func _seeds(amount: int) -> int:
	var bag: InventoryComponent = player.selection.inventory
	bag.remove(SEED.item_id, bag.count_item(SEED.item_id))
	bag.add(SEED, amount)
	for i: int in range(bag.slot_count):
		if bag.slot(i).item == SEED:
			return i
	return -1

func test_footprints_and_batch_terrain_match_all_sizes_and_four_directions() -> void:
	for facing: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		for size: int in [1, 2, 3, 4, 5, 6]:
			farm.restore_soil([])
			var cells: Array[Vector2i] = FarmingAreaPolicy.cells(origin, facing, size)
			assert_eq(cells.size(), size * size)
			assert_false(cells.has(origin))
			_mark(cells)
			assert_eq(farm.apply_area(&"tool", cells, null, -1, null, player).changed, size * size)
			assert_eq(farm.apply_area(&"water", cells, null, -1, null, player).changed, size * size)
			for cell: Vector2i in cells:
				assert_eq(farm.get_soil_state(cell), FarmingController.Soil.WET)
			assert_eq(farm.apply_area(&"water", cells).changed, 0)
	assert_true(FarmingAreaPolicy.cells(origin, Vector2i.ZERO, 3).is_empty())
	assert_true(FarmingAreaPolicy.cells(origin, Vector2i.DOWN, 7).is_empty())

func test_locked_and_occupied_cells_are_skipped_even_when_front_cell_is_blocked() -> void:
	var cells: Array[Vector2i] = FarmingAreaPolicy.cells(origin, Vector2i.DOWN, 3)
	_mark(cells)
	farm.set_cell_occupied(cells[0], true)
	assert_eq(farm.apply_area(&"tool", cells, null, -1, null, player).changed, 8)
	assert_eq(farm.get_soil_state(cells[0]), FarmingController.Soil.UNTILLED)
	farm.restore_soil([])
	farm.set_cell_occupied(cells[0], false)
	farm.land = LandExpansionState.new()
	cells = FarmingAreaPolicy.cells(Vector2i(54, 24), Vector2i.LEFT, 3)
	_mark(cells)
	assert_eq(farm.apply_area(&"tool", cells).changed, 3)
	for cell: Vector2i in cells:
		assert_eq(farm.get_soil_state(cell), FarmingController.Soil.DRY if cell.x == 53 else FarmingController.Soil.UNTILLED)

func test_five_seeds_preview_and_commit_exactly_five_with_one_atomic_notification() -> void:
	var cells: Array[Vector2i] = FarmingAreaPolicy.cells(origin, Vector2i.DOWN, 3)
	_mark(cells)
	farm.apply_area(&"tool", cells)
	var slot: int = _seeds(5)
	var rows: Array[Dictionary] = FarmingAreaPolicy.evaluate(farm, &"plant", cells, player.selection.inventory, slot, player)
	for i: int in range(9):
		assert_eq(rows[i].ready, i < 5)
	watch_signals(farm)
	watch_signals(player.selection.inventory)
	player.selection.inventory.changed.connect(func() -> void:
		assert_eq(farm.crop_cells().size(), 5)
		assert_eq(farm.apply_area(&"plant", cells, player.selection.inventory, slot, SEED, player).changed, 0)
		assert_false(farm.plant(cells[8], player.selection.inventory, slot, player)))
	var result: Dictionary = farm.apply_area(&"plant", cells, player.selection.inventory, slot, SEED, player)
	assert_eq(result.changed, 5)
	assert_eq(result.seed_spent, 5)
	assert_eq(player.selection.inventory.count_item(SEED.item_id), 0)
	assert_signal_emit_count(farm, "crop_planted", 5)
	assert_signal_emit_count(farm, "action_committed", 1)
	assert_signal_emit_count(player.selection.inventory, "changed", 1)
	for i: int in range(9):
		assert_eq(farm.get_crop(cells[i]) != null, i < 5)
		if i < 5:
			assert_eq(farm.get_crop(cells[i]).planted_at, farm.get_crop(cells[0]).planted_at)

func test_action_freezes_footprint_and_commits_only_once_at_impact() -> void:
	player.animation.face(Vector2.DOWN)
	var targets: Array[Vector2i] = player.farming_actions.target_cells()
	_mark(targets)
	assert_true(player.state.use_selected_tool())
	for cell: Vector2i in targets:
		assert_eq(farm.get_soil_state(cell), FarmingController.Soil.UNTILLED)
	player.animation.face(Vector2.LEFT)
	assert_eq(player.farming_actions.target_cells(), targets)
	player.animation.animated_sprite.stop()
	player.animation.animated_sprite.frame = 3
	player.farming_actions._on_frame_changed()
	assert_eq(player.farming_actions.last_result.changed, 9)
	player.farming_actions._on_frame_changed()
	for cell: Vector2i in targets:
		assert_eq(farm.get_soil_state(cell), FarmingController.Soil.DRY)
	assert_eq(farm.get_soil_state(origin), FarmingController.Soil.UNTILLED)

func test_switching_seed_slot_or_opening_menu_cancels_pending_planting() -> void:
	var targets: Array[Vector2i] = FarmingAreaPolicy.cells(origin, Vector2i.DOWN, 3)
	_mark(targets)
	farm.apply_area(&"tool", targets)
	var slot: int = _seeds(9)
	player.selection.select_slot(slot)
	player.animation.face(Vector2.DOWN)
	assert_true(player.state.use_selected_tool())
	player.selection.select_slot(0)
	player.animation.animated_sprite.stop()
	player.animation.animated_sprite.frame = 3
	player.farming_actions._on_frame_changed()
	assert_eq(farm.crop_cells().size(), 0)
	assert_eq(player.selection.inventory.count_item(SEED.item_id), 9)
	player.state.transition_to(StateComponent.State.IDLE)
	player.selection.select_slot(slot)
	assert_true(player.state.use_selected_tool())
	player.selection.set_inventory_open(true)
	player.farming_actions._on_frame_changed()
	assert_eq(farm.crop_cells().size(), 0)
	assert_eq(player.selection.inventory.count_item(SEED.item_id), 9)

func test_six_by_six_plants_36_crops_and_spends_36_seeds_once() -> void:
	var cells: Array[Vector2i] = FarmingAreaPolicy.cells(origin, Vector2i.DOWN, 6)
	_mark(cells)
	assert_eq(farm.apply_area(&"tool", cells).changed, 36)
	var slot: int = _seeds(36)
	watch_signals(player.selection.inventory)
	var result: Dictionary = farm.apply_area(&"plant", cells, player.selection.inventory, slot, SEED, player)
	assert_eq(result.changed, 36)
	assert_eq(result.seed_spent, 36)
	assert_eq(farm.crop_cells().size(), 36)
	assert_eq(player.selection.inventory.count_item(SEED.item_id), 0)
	assert_signal_emit_count(player.selection.inventory, "changed", 1)
