extends GutTest

const Fixture = preload("res://tests/support/farming_fixture.gd")
var field: Node2D
var farming: FarmingController
var land: TileMapLayer
var cell: Vector2i = Vector2i(20, 20)

func before_each() -> void:
	field = Fixture.create_field()
	add_child_autofree(field)
	farming = field.get_node("FarmingController")
	land = field.get_node("FarmLand")
	Fixture.mark_cell(field, cell)

func test_only_marked_farmland_is_tillable() -> void:
	assert_true(farming.can_till(cell))
	assert_false(farming.can_till(cell + Vector2i.RIGHT), "Ground grass alone does not grant permission")
	land.set_cell(cell, 0, Vector2i.ZERO)
	assert_false(farming.can_till(cell), "Unmarked atlas tile denies farming")
	assert_false(farming.water(cell))
	assert_false(farming.can_plant(cell))

func test_permission_flags_are_independent() -> void:
	var data: TileData = land.get_cell_tile_data(cell)
	data.set_custom_data("can_till", false)
	assert_false(farming.till(cell))
	data.set_custom_data("can_till", true)
	assert_true(farming.till(cell))
	data.set_custom_data("can_water", false)
	assert_false(farming.water(cell))
	assert_true(farming.can_plant(cell))
	data.set_custom_data("can_plant", false)
	assert_false(farming.can_plant(cell))
	data.set_custom_data("can_water", true)
	assert_true(farming.water(cell))
	assert_false(farming.can_plant(cell), "Wet soil does not override planting permission")

func test_water_and_farmland_borders_do_not_grant_farming_permissions() -> void:
	for source_and_atlas: Array in [[0, Vector2i(0, 0)], [0, Vector2i(0, 5)], [0, Vector2i(1, 5)], [1, Vector2i(1, 1)]]:
		land.set_cell(cell, source_and_atlas[0], source_and_atlas[1])
		var data: TileData = land.get_cell_tile_data(cell)
		for permission: String in ["can_till", "can_water", "can_plant"]:
			assert_true(data.has_custom_data(permission))
			assert_false(data.get_custom_data(permission), "Protected tile: " + permission)
		assert_false(farming.can_till(cell))
		assert_false(farming.till(cell))

func test_soil_lifecycle_is_idempotent_and_preserves_permission_layer() -> void:
	watch_signals(farming)
	var source: int = land.get_cell_source_id(cell)
	var atlas: Vector2i = land.get_cell_atlas_coords(cell)
	assert_eq(farming.get_soil_state(cell), FarmingController.Soil.UNTILLED)
	assert_false(farming.water(cell), "Cannot water uncultivated grass")
	assert_false(farming.can_plant(cell))
	assert_true(farming.till(cell))
	assert_eq(farming.get_soil_state(cell), FarmingController.Soil.DRY)
	assert_false(farming.till(cell))
	assert_true(farming.can_plant(cell))
	assert_true(farming.water(cell))
	assert_eq(farming.get_soil_state(cell), FarmingController.Soil.WET)
	assert_false(farming.water(cell))
	assert_false(farming.till(cell))
	assert_true(farming.can_plant(cell))
	assert_signal_emit_count(farming, "soil_changed", 2)
	assert_eq(land.get_cell_source_id(cell), source)
	assert_eq(land.get_cell_atlas_coords(cell), atlas)

func test_occupation_blocks_all_farming_and_can_be_released() -> void:
	assert_true(farming.till(cell))
	farming.set_cell_occupied(cell, true)
	assert_false(farming.can_till(cell))
	assert_false(farming.can_water(cell))
	assert_false(farming.can_plant(cell))
	farming.set_cell_occupied(cell, false)
	assert_true(farming.can_water(cell))
	assert_true(farming.can_plant(cell))

func test_custom_data_on_overlay_blocks_all_actions() -> void:
	assert_true(farming.till(cell))
	var blocker: TileMapLayer = TileMapLayer.new()
	blocker.tile_set = land.tile_set.duplicate(true)
	field.add_child(blocker)
	blocker.set_cell(cell, 0, Vector2i(1, 6))
	blocker.get_cell_tile_data(cell).set_custom_data("blocks_farming", true)
	assert_false(farming.can_till(cell))
	assert_false(farming.can_water(cell))
	assert_false(farming.can_plant(cell))
	blocker.erase_cell(cell)
	assert_true(farming.can_water(cell))

func test_missing_permission_data_defaults_to_denied() -> void:
	for index: int in range(land.tile_set.get_custom_data_layers_count() - 1, -1, -1):
		land.tile_set.remove_custom_data_layer(index)
	assert_false(farming.till(cell))
	assert_false(farming.can_water(cell))
	assert_false(farming.can_plant(cell))

func test_unconfigured_soil_terrain_does_not_change_state() -> void:
	farming.dry_terrain = 999
	assert_false(farming.till(cell))
	assert_eq(farming.get_soil_state(cell), FarmingController.Soil.UNTILLED)

func test_empty_layers_without_tilesets_do_not_break_farming() -> void:
	for index: int in range(4):
		var empty_layer: TileMapLayer = TileMapLayer.new()
		empty_layer.name = "EmptyLayer" + str(index)
		field.add_child(empty_layer)
	assert_true(farming.can_till(cell))
	assert_true(farming.till(cell))
	assert_true(farming.can_water(cell))
	assert_true(farming.water(cell))
	assert_true(farming.can_plant(cell))

func test_soil_state_queries_ignore_layers_with_missing_tilesets() -> void:
	farming.dry_soil.tile_set = null
	farming.wet_soil.tile_set = null
	assert_eq(farming.get_soil_state(cell), FarmingController.Soil.UNTILLED)
	assert_false(farming.till(cell))
	assert_false(farming.water(cell))
