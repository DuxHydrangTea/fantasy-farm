extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var land: LandExpansionComponent
var farm: FarmingController
var player: FarmPlayer

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	add_child_autofree(world)
	land = world.land
	land.state.restore_columns(1) # Keep the original ownership/migration fixture.
	farm = world.farming
	player = world.player
	player.position = Vector2(900, 310)
	await wait_physics_frames(2)

func test_actual_map_permissions_are_exact_rectangle_and_locked_tools_fail() -> void:
	var count: int = 0
	for cell: Vector2i in farm.farmland.get_used_cells():
		var tile: TileData = farm.farmland.get_cell_tile_data(cell)
		if tile.get_custom_data("can_plant"):
			assert_true(LandExpansionState.REGION.has_point(cell))
			count += 1
	assert_eq(count, 1632)
	assert_true(farm.can_till(Vector2i(56, 20), player))
	assert_false(farm.can_till(Vector2i(55, 20), player))
	assert_false(farm.till(Vector2i(55, 20), player))
	# Even malformed direct runtime soil restoration cannot bypass plant/water rules.
	farm.restore_soil([{"cell": [55, 20], "state": 1}])
	assert_false(farm.can_water(Vector2i(55, 20), player))
	assert_false(farm.can_plant(Vector2i(55, 20), player))
	var seed: ItemDefinition = load("res://items/seeds/wheat_seed.tres") as ItemDefinition
	var now: float = TimeManager.now()
	farm.restore_crop(Vector2i(55, 20), seed.crop, now - 100.0, now - 1.0, 1.0, now)
	assert_false(farm.can_harvest(Vector2i(55, 20)))
	assert_false(farm.harvest(Vector2i(55, 20), player.selection.inventory))
	assert_not_null(farm.get_crop(Vector2i(55, 20)), "Rejected harvest preserves the crop")

func test_sign_interaction_confirm_cancel_reveal_and_full_unlock() -> void:
	player.global_position = land.interaction_position() + Vector2(0, 16)
	player.wallet.set_balance(100000)
	assert_true(player.shop_interaction.try_interact())
	assert_true(land.menu.is_open)
	assert_false(land.menu.status.text.contains("Balance"))
	assert_true(player.selection.is_menu_open())
	assert_eq(land.menu, player.shop_interaction.active_shop)
	land.menu.close()
	assert_eq(player.wallet.balance, 100000)
	assert_eq(land.state.unlocked_columns, 1)
	assert_true(player.shop_interaction.try_interact())
	land.menu.confirm.pressed.emit()
	assert_false(land.menu.is_open)
	assert_false(player.selection.is_menu_open())
	assert_eq(player.wallet.balance, 40000)
	assert_eq(land.state.unlocked_columns, 2)
	assert_false(land.sign.visible)
	await wait_seconds(1.0)
	assert_true(land.sign.visible)
	assert_eq(land.state.next_column(), 54)
	assert_true(farm.can_till(Vector2i(55, 20), player))
	land.state.restore_columns(48)
	assert_false(land.sign.visible)
	assert_false(land.open_purchase(player))

func test_distance_and_funds_guard_menu_and_purchase() -> void:
	player.global_position = land.interaction_position() + Vector2(100, 0)
	assert_false(land.open_purchase(player))
	assert_false(land.purchase(1).ok)
	player.global_position = land.interaction_position() + Vector2(0, 16)
	assert_true(land.open_purchase(player))
	assert_true(land.menu.confirm.disabled)
	land.menu.confirm.pressed.emit()
	assert_eq(player.wallet.balance, WalletComponent.STARTING_COINS)
	assert_eq(land.state.unlocked_columns, 1)

func test_purchase_save_reload_migration_and_corrupt_ownership_preflight() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	player.global_position = land.interaction_position() + Vector2(0, 16)
	player.wallet.set_balance(100000)
	assert_true(land.purchase(1).ok)
	var snapshot: Dictionary = adapter.capture("land_test", 1, TimeManager.now())
	assert_eq(snapshot.land_columns, 2)
	assert_true(SaveSchema.validate(snapshot, catalog).ok)
	var directory: String = "res://.godot/land_save_tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var repository: LocalSaveRepository = LocalSaveRepository.new(directory, catalog)
	assert_true(repository.write_profile("land_test", snapshot, 0).ok)
	var loaded: Dictionary = repository.read_profile("land_test")
	assert_true(loaded.ok)
	assert_eq(int(loaded.snapshot.land_columns), 2)
	snapshot = loaded.snapshot
	DirAccess.remove_absolute(repository.path("land_test"))
	DirAccess.remove_absolute(directory)
	land.state.restore_columns(3)
	assert_true(adapter.restore(snapshot, TimeManager.now()).ok)
	assert_eq(land.state.unlocked_columns, 2)
	assert_eq(player.wallet.balance, 40000)
	assert_eq(land._reveal_column, -1)
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.version = 5
	legacy.erase("land_columns")
	legacy.soil = [{"cell": [9, 19], "state": 1}]
	var migrated: Dictionary = SaveSchema.validate(legacy, catalog)
	assert_true(migrated.ok)
	assert_eq(migrated.snapshot.land_columns, 48)
	assert_false(legacy.has("land_columns"), "Migration never mutates the caller")
	assert_true(adapter.restore(migrated.snapshot, TimeManager.now()).ok)
	assert_eq(farm.get_soil_state(Vector2i(9, 19)), FarmingController.Soil.DRY)
	var corrupt: Dictionary = migrated.snapshot.duplicate(true)
	corrupt.land_columns = 1
	player.wallet.set_balance(777)
	assert_false(adapter.restore(corrupt, TimeManager.now()).ok)
	assert_eq(player.wallet.balance, 777, "Preflight fails before mutating wallet or world")
	assert_eq(land.state.unlocked_columns, 48)

func test_menu_fits_small_window_and_releases_lock_for_load() -> void:
	player.global_position = land.interaction_position() + Vector2(0, 16)
	assert_true(land.open_purchase(player))
	await wait_process_frames(3)
	var rect: Rect2 = land.menu.panel.get_global_rect()
	assert_gte(rect.position.x, 0.0)
	assert_gte(rect.position.y, 0.0)
	assert_lte(rect.end.x, land.menu.root.size.x)
	assert_lte(rect.end.y, land.menu.root.size.y)
	player.shop_interaction.close_for_load()
	assert_false(player.selection.is_menu_open())
	assert_false(land.menu.is_open)

func test_legacy_empty_farm_starts_with_one_column_and_bad_counts_fail() -> void:
	var catalog: SaveCatalog = SaveCatalog.new()
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, catalog)
	var snapshot: Dictionary = adapter.capture("land_test", 1, TimeManager.now())
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.version = 5
	legacy.erase("land_columns")
	assert_eq(SaveSchema.validate(legacy, catalog).snapshot.land_columns, 1)
	legacy.soil = [{"cell": [54, 30], "state": 1}]
	assert_eq(SaveSchema.validate(legacy, catalog).snapshot.land_columns, 3)
	for invalid: Variant in [null, 0, 49, 1.5, "2"]:
		snapshot.land_columns = invalid
		assert_false(SaveSchema.validate(snapshot, catalog).ok)
