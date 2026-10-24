extends GutTest
const FARM_DATA = preload("res://resources/grass/farm_grass_data.gd")
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const REGION: Rect2 = Rect2(1008, 592, 384, 272)

func _scene() -> Node2D:
	var scene: Node2D = WORLD.instantiate() as Node2D
	return scene # Never enter tree; no gameplay or saves.

func test_authored_atlas_keeps_all_original_pixels_and_opaque_roots() -> void:
	var source: Image = Image.load_from_file(ProjectSettings.globalize_path(GrassSourceTransfer.SOURCE))
	var atlas: Image = Image.load_from_file(ProjectSettings.globalize_path("res://resources/grass/farm_grass_atlas.png"))
	source.convert(Image.FORMAT_RGBA8)
	for row: Dictionary in FARM_DATA.TYPES:
		var original: Image = source.get_region(Rect2i(row.source_region[0], row.source_region[1], 16, 16))
		assert_eq(original.get_used_rect().end.y, int(row.root_y))
		for frame: int in range(8):
			assert_eq(original.get_data(), atlas.get_region(Rect2i(frame * 16, int(row.row) * 16, 16, 16)).get_data())

func test_only_safe_grass_cells_in_barn_are_transferred_and_restored() -> void:
	var scene: Node2D = _scene()
	var layer: TileMapLayer = scene.get_node("TinyDecor")
	var transfer: GrassSourceTransfer = GrassSourceTransfer.new()
	var before: int = layer.get_used_cells().size()
	var values: Array[Dictionary] = transfer.prepare(layer, scene, REGION)
	assert_eq(values.size(), 10)
	assert_eq(transfer.retained_overlaps, 3)
	assert_eq(layer.get_cell_atlas_coords(Vector2i(345, 211)), Vector2i(6, 2))
	assert_true(transfer.suppress())
	assert_eq(layer.get_used_cells().size(), before - 10)
	assert_true(layer.visible)
	for record: Dictionary in transfer.records:
		assert_eq(layer.get_cell_source_id(record.cell), -1)
	transfer.restore()
	transfer.restore()
	assert_eq(layer.get_used_cells().size(), before)
	for record: Dictionary in transfer.records:
		assert_eq(layer.get_cell_atlas_coords(record.cell), record.coords)
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
	assert_eq(scene.grass.transfer.records.size(), 10)
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
