extends GutTest
const FARM_DATA = preload("res://resources/grass/farm_grass_data.gd")
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const REGION: Rect2 = Rect2(1008, 592, 384, 272)

func _scene() -> Node2D:
	var scene: Node2D = WORLD.instantiate() as Node2D
	return scene # Never enter tree; no gameplay or saves.

func _authored_count(layer: TileMapLayer) -> int:
	var coords: Array[Vector2i] = []
	for row: Dictionary in FARM_DATA.TYPES:
		coords.append(Vector2i(row.coords[0], row.coords[1]))
	var count: int = 0
	for cell: Vector2i in layer.get_used_cells_by_id(4):
		if layer.get_cell_atlas_coords(cell) in coords:
			count += 1
	return count

func test_palette_contains_all_single_tile_foliage_and_excludes_objects() -> void:
	assert_eq(FARM_DATA.TYPES.size(), 80)
	var scene: Node2D = _scene()
	var layer: TileMapLayer = scene.get_node("TinyDecor")
	var source: TileSetAtlasSource = layer.tile_set.get_source(4) as TileSetAtlasSource
	var coords: Array[Vector2i] = []
	for row: Dictionary in FARM_DATA.TYPES:
		var point: Vector2i = Vector2i(row.coords[0], row.coords[1])
		assert_false(point in coords)
		coords.append(point)
		assert_true(source.has_tile(point))
		var size: Vector2i = Vector2i(row["size"][0], row["size"][1])
		assert_eq(source.get_tile_texture_region(point).size, size)
		assert_true(size in [Vector2i(16, 16), Vector2i(16, 32), Vector2i(32, 32)])
	for shrub: Vector2i in [Vector2i(5, 5), Vector2i(3, 9), Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9)]:
		assert_true(shrub in coords, "Green shrubs included")
	for mushroom: Vector2i in [Vector2i(7, 2), Vector2i(8, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(2, 5), Vector2i(2, 6)]:
		assert_true(mushroom in coords, "Mushroom variant included")
	for flower: Vector2i in [Vector2i(5, 21), Vector2i(7, 21), Vector2i(8, 21), Vector2i(5, 23), Vector2i(7, 23), Vector2i(8, 23)]:
		assert_true(flower in coords, "Tall flower included")
		assert_eq(source.get_tile_texture_region(flower).size.y, 32)
	for excluded: Vector2i in [Vector2i(4, 4), Vector2i(0, 7), Vector2i(4, 9), Vector2i(0, 12)]:
		assert_false(excluded in coords, "Rock/log/fence excluded")
	scene.free()

func test_authored_atlas_keeps_all_original_pixels_and_opaque_roots() -> void:
	var source: Image = Image.load_from_file(ProjectSettings.globalize_path(GrassSourceTransfer.SOURCE))
	var atlas: Image = Image.load_from_file(ProjectSettings.globalize_path("res://resources/grass/farm_grass_atlas.png"))
	source.convert(Image.FORMAT_RGBA8)
	for row: Dictionary in FARM_DATA.TYPES:
		var size: Vector2i = Vector2i(row["size"][0], row["size"][1])
		var original: Image = source.get_region(Rect2i(Vector2i(row.source_region[0], row.source_region[1]), size))
		assert_eq(original.get_used_rect().end.y, int(row.root_y))
		for frame: int in range(8):
			var stride: int = int(row.diagnostic_stride)
			assert_eq(original.get_data(), atlas.get_region(Rect2i(Vector2i(frame * stride, int(row.row) * stride), size)).get_data())

func test_only_safe_grass_cells_in_barn_are_transferred_and_restored() -> void:
	var scene: Node2D = _scene()
	var layer: TileMapLayer = scene.get_node("TinyDecor")
	var transfer: GrassSourceTransfer = GrassSourceTransfer.new()
	var before: int = layer.get_used_cells().size()
	var values: Array[Dictionary] = transfer.prepare(layer, scene, REGION)
	assert_gt(values.size() + transfer.retained_overlaps, 13)
	var selected: int = values.size()
	assert_eq(layer.get_cell_atlas_coords(Vector2i(345, 211)), Vector2i(6, 2))
	assert_true(transfer.suppress())
	assert_eq(layer.get_used_cells().size(), before - selected)
	assert_true(layer.visible)
	for record: Dictionary in transfer.records:
		assert_eq(layer.get_cell_source_id(record.cell), -1)
	transfer.restore()
	transfer.restore()
	assert_eq(layer.get_used_cells().size(), before)
	for record: Dictionary in transfer.records:
		assert_eq(layer.get_cell_atlas_coords(record.cell), record.coords)
	scene.free()

func test_default_scans_the_entire_map_and_newly_painted_grass() -> void:
	var scene: Node2D = _scene()
	var layer: TileMapLayer = scene.get_node("TinyDecor")
	var transfer: GrassSourceTransfer = GrassSourceTransfer.new()
	var samples: Array[Dictionary] = transfer.prepare(layer, scene)
	var original_count: int = samples.size()
	assert_eq(original_count + transfer.retained_overlaps, _authored_count(layer))
	assert_gt(original_count, 100)
	var authored_count: int = layer.get_used_cells().size()
	var source: int = transfer.records[0].source
	var added_cell: Vector2i = Vector2i(-2000, -2000)
	layer.set_cell(added_cell, source, Vector2i(6, 2))
	samples = transfer.prepare(layer, scene)
	assert_eq(samples.size(), original_count + 1)
	assert_true(transfer.suppress())
	assert_eq(layer.get_cell_source_id(added_cell), -1)
	assert_eq(layer.get_used_cells().size(), authored_count - original_count)
	transfer.restore()
	assert_eq(layer.get_cell_atlas_coords(added_cell), Vector2i(6, 2))
	assert_eq(layer.get_used_cells().size(), authored_count + 1)
	scene.free()

func test_source_change_aborts_transaction_before_erasing_any_other_cell() -> void:
	var scene: Node2D = _scene()
	var layer: TileMapLayer = scene.get_node("TinyDecor")
	var transfer: GrassSourceTransfer = GrassSourceTransfer.new()
	transfer.prepare(layer, scene, REGION)
	var changed: Dictionary = transfer.records[0]
	layer.erase_cell(changed.cell)
	var count: int = layer.get_used_cells().size()
	assert_false(transfer.suppress())
	assert_eq(layer.get_used_cells().size(), count)
	assert_false(transfer.suppressed)
	scene.free()

func test_mixed_row_materials_are_local_and_fallback_restores_original_tileset() -> void:
	var scene: Node2D = _scene()
	var layer: TileMapLayer = scene.get_node("TinyDecor")
	var original: TileSet = layer.tile_set
	var helper: GrassTileMaterials = GrassTileMaterials.new()
	assert_true(helper.install(layer))
	assert_ne(layer.tile_set, original)
	assert_eq(helper.materials.size(), FARM_DATA.TYPES.size())
	var source: TileSetAtlasSource = original.get_source(4) as TileSetAtlasSource
	assert_null(source.get_tile_data(Vector2i(6, 2), 0).material)
	var effect: ShaderMaterial = ShaderMaterial.new()
	effect.shader = load("res://shaders/grass_farm.gdshader")
	effect.set_shader_parameter(&"wind_strength", 2.8)
	effect.set_shader_parameter(&"actor_count", 0)
	helper.sync_from(effect)
	for material: ShaderMaterial in helper.materials:
		assert_eq(material.get_shader_parameter(&"wind_strength"), 2.8)
	helper.restore()
	helper.restore()
	assert_eq(layer.tile_set, original)
	assert_true(helper.materials.is_empty())
	scene.free()

func test_restore_does_not_overwrite_external_edit() -> void:
	var scene: Node2D = _scene()
	var layer: TileMapLayer = scene.get_node("TinyDecor")
	var transfer: GrassSourceTransfer = GrassSourceTransfer.new()
	transfer.prepare(layer, scene, REGION)
	transfer.suppress()
	var changed: Dictionary = transfer.records[0]
	layer.set_cell(changed.cell, changed.source, Vector2i(0, 0))
	transfer.restore()
	assert_eq(layer.get_cell_atlas_coords(changed.cell), Vector2i(0, 0))
	assert_eq(transfer.restore_conflicts, 1)
	scene.free()

func test_arbitrary_region_and_non_grass_tile_are_not_accepted() -> void:
	var scene: Node2D = _scene()
	var layer: TileMapLayer = scene.get_node("TinyDecor")
	var transfer: GrassSourceTransfer = GrassSourceTransfer.new()
	assert_true(transfer.prepare(layer, scene, Rect2(-10000, -10000, 16, 16)).is_empty())
	var count: int = layer.get_used_cells().size()
	assert_true(transfer.suppress())
	assert_eq(layer.get_used_cells().size(), count)
	scene.free()

func test_authored_sort_origin_is_separate_from_opaque_ground() -> void:
	var index: GrassChunkIndex = GrassChunkIndex.new()
	var catalog: GrassSourceCatalog = GrassSourceCatalog.new()
	index.build([{"type": 10, "transform": Transform2D(0.0, Vector2(50, 100)), "sort_origin": Vector2(50, 120)}], catalog, 512, Transform2D.IDENTITY)
	var group: Dictionary = index.chunks[Vector2i.ZERO].groups.values()[0]
	assert_eq(group.anchor.y, 120.0)
	assert_eq(group.samples[0].transform.origin, Vector2(50, -20))

func test_headless_world_keeps_original_grass_without_runtime_gpu_buffers() -> void:
	if DisplayServer.get_name() != "headless":
		pending("This fixture verifies headless fallback")
		return
	var scene: FarmWorld = WORLD.instantiate() as FarmWorld
	add_child(scene)
	assert_false(scene.grass.active)
	assert_true(scene.grass.fallback_reason.contains("Headless"))
	assert_gt(scene.grass.transfer.records.size(), 10)
	assert_eq(scene.grass.renderer.instances, 0)
	assert_eq((scene.get_node("TinyDecor") as TileMapLayer).get_used_cells().size(), 1130)
	scene.free()
	await get_tree().process_frame

func test_hidden_or_disabled_authoring_layer_is_not_replaced() -> void:
	var scene: Node2D = _scene()
	var layer: TileMapLayer = scene.get_node("TinyDecor")
	var transfer: GrassSourceTransfer = GrassSourceTransfer.new()
	layer.enabled = false
	assert_true(transfer.prepare(layer, scene, REGION).is_empty())
	layer.enabled = true
	layer.hide()
	assert_true(transfer.prepare(layer, scene, REGION).is_empty())
	scene.free()
