extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var land: LandExpansionComponent
var farm: FarmingController
var player: FarmPlayer

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	add_child_autofree(world)
	land = world.land
	farm = world.farming
	player = world.player
	farm.restore_soil([])
	await wait_physics_frames(2)

func test_first_block_tools_rain_and_path_permissions() -> void:
	assert_eq(land.state.unlocked_blocks, 1)
	assert_true(farm.can_till(Vector2i(55, 24), player))
	assert_false(farm.can_till(Vector2i(55, 30), player))
	assert_false(farm.can_till(Vector2i(48, 24), player))
	assert_true(farm.till(Vector2i(55, 24), player))
	farm.rain_water()
	assert_eq(farm.get_soil_state(Vector2i(55, 24)), FarmingController.Soil.WET)
	assert_eq(farm.get_soil_state(Vector2i(55, 30)), FarmingController.Soil.UNTILLED)
	assert_eq(farm.get_soil_state(Vector2i(48, 24)), FarmingController.Soil.UNTILLED)

func test_sign_purchases_whole_block_then_animates_only_that_block() -> void:
	player.global_position = land.interaction_position() + Vector2(0, 16)
	player.wallet.set_balance(100000)
	assert_true(land.open_purchase(player))
	assert_true(land.menu.description.text.contains("64"))
	land.menu.confirm.pressed.emit()
	assert_eq(land.state.unlocked_blocks, 2)
	assert_eq(player.wallet.balance, 40000)
	assert_false(land.sign.visible)
	assert_true(farm.can_till(Vector2i(55, 30), player))
	assert_false(farm.can_till(Vector2i(55, 40), player))
	await wait_seconds(1.0)
	assert_true(land.sign.visible)
	assert_eq(land.state.next_block(), Rect2i(49, 37, 8, 8))

func test_block_save_roundtrip_and_legacy_column_migration() -> void:
	land.state.restore_blocks(2)
	assert_true(farm.till(Vector2i(55, 30), player))
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var snapshot: Dictionary = adapter.capture("block_test", 1, TimeManager.now())
	assert_eq(snapshot.land_blocks, 2)
	assert_eq(snapshot.land_starting_blocks, 1)
	assert_true(SaveSchema.validate(snapshot, adapter.catalog).ok)
	land.state.restore_blocks(1)
	assert_true(adapter.restore(snapshot, TimeManager.now()).ok)
	assert_eq(land.state.unlocked_blocks, 2)
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.version = 39
	legacy["land_columns"] = 4
	legacy["land_starting_columns"] = 4
	legacy.erase("land_blocks")
	legacy.erase("land_starting_blocks")
	var checked: Dictionary = SaveSchema.validate(legacy, adapter.catalog)
	assert_true(checked.ok)
	assert_eq(checked.snapshot.land_blocks, 4)
	assert_eq(legacy.version, 39, "Migration does not mutate its input")
	for invalid: Variant in [0, 25, 1.5, "2", null]:
		snapshot.land_blocks = invalid
		assert_false(SaveSchema.validate(snapshot, adapter.catalog).ok)

func test_gpu_cover_hides_locked_blocks_but_keeps_paths_and_reveal_separate() -> void:
	var effect: ShaderMaterial = ShaderMaterial.new()
	effect.shader = preload("res://shaders/grass_farm.gdshader")
	land.set_grass_effect(effect)
	assert_true(land.grass_cover.active)
	assert_eq(land.grass_cover.canvases.size(), 4)
	assert_eq(land.grass_cover.base_count, 1536 - 64)
	land.state.restore_blocks(2)
	land._reveal_block = 1
	land._reveal_rows(3)
	assert_eq(land.grass_cover.base_count, 1536 - 128)
	assert_eq(land.grass_cover.reveal_count, 40)
	land.reset_presentation()
	assert_eq(land.grass_cover.reveal_count, 0)
	land.state.restore_blocks(24)
	assert_eq(land.grass_cover.base_count, 0)

func test_all_blocks_have_64_tillable_cells_and_paths_block_farming() -> void:
	land.state.restore_blocks(LandExpansionState.BLOCK_COUNT)
	var region: Rect2i = LandExpansionState.REGION
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var cell: Vector2i = Vector2i(x, y)
			assert_eq(farm.can_till(cell, player), LandExpansionState.block_index(cell) >= 0, str(cell))

func test_v41_crop_and_soil_stay_in_their_block_after_resize() -> void:
	land.state.restore_blocks(5)
	var cell: Vector2i = Vector2i(40, 46)
	assert_true(farm.till(cell, player))
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var now: float = TimeManager.now()
	farm.restore_crop(cell, adapter.catalog.crops["carrot"], now, now + 60.0, 0.0, now)
	var snapshot: Dictionary = adapter.capture("block_resize", 1, now)
	snapshot.version = 41
	snapshot.soil[0].cell = [41, 45]
	snapshot.crops[0].cell = [41, 45]
	var checked: Dictionary = SaveSchema.validate(snapshot, adapter.catalog)
	assert_true(checked.ok)
	if checked.ok:
		assert_eq(checked.snapshot.soil[0].cell, [40, 46])
		assert_eq(checked.snapshot.crops[0].cell, [40, 46])
		assert_eq(checked.snapshot.land_blocks, 5)
		assert_true(adapter.restore(snapshot, TimeManager.now()).ok)
		assert_eq(farm.get_soil_state(cell), FarmingController.Soil.DRY)
		assert_not_null(farm.get_crop(cell))
	assert_eq(snapshot.soil[0].cell, [41, 45])
