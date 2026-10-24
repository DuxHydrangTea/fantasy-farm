extends GutTest

func _sample(x: float, y: float, tall: bool = true, z: int = 0) -> Dictionary:
	return {"type": 10, "transform": Transform2D(0.0, Vector2(x, y)), "tall": tall, "z_index": z}

func _field(values: Array[Dictionary]) -> GrassChunkField:
	var world: Node2D = Node2D.new()
	world.y_sort_enabled = true
	add_child_autofree(world)
	var field: GrassChunkField = GrassChunkField.new()
	field.chunk_size = 256
	field.samples = values
	field.reserve_chunks = 0
	world.add_child(field)
	field.set_process(false)
	return field

func test_negative_cells_exact_fractional_rows_z_and_low_grass_grouping() -> void:
	var index: GrassChunkIndex = GrassChunkIndex.new()
	index.build([_sample(-0.1, -0.1), _sample(8, 80.25), _sample(16, 80.5), _sample(24, 80.25), _sample(32, 80.25, true, 2), _sample(48, 90, false, -1), _sample(64, 150, false, -1)], GrassSourceCatalog.new(), 256, Transform2D.IDENTITY)
	assert_true(index.chunks.has(Vector2i(-1, -1)))
	assert_eq(index.chunks[Vector2i.ZERO].groups.size(), 4)
	assert_eq(index.chunks[Vector2i.ZERO].groups[Vector3(80.25, 0, 1)].samples.size(), 2)
	assert_eq(index.chunks[Vector2i.ZERO].groups[Vector3(0, -1, 0)].samples.size(), 2)
	assert_eq(index.total_instances, 7)

func test_parent_transform_is_baked_into_sort_space_and_bounds() -> void:
	var index: GrassChunkIndex = GrassChunkIndex.new()
	var value: Dictionary = _sample(10, 20)
	value.transform = Transform2D(0.0, Vector2(-2, 3), 0.0, Vector2(10, 20))
	index.build([value], GrassSourceCatalog.new(), 256, Transform2D(0.0, Vector2(60, 80)))
	var group: Dictionary = index.chunks[Vector2i.ZERO].groups.values()[0]
	assert_eq(group.anchor, Vector2(0, 100))
	assert_eq(group.samples[0].transform.origin, Vector2(70, 0))
	assert_eq(index.extent, 45.0)

func test_static_view_does_not_rebuild_or_query_whole_map() -> void:
	var values: Array[Dictionary] = [_sample(64, 64)]
	for i: int in range(2000):
		values.append(_sample(10000 + i * 32, 64))
	var field: GrassChunkField = _field(values)
	field.select_view(Rect2(0, 0, 128, 128))
	var before: Dictionary = field.renderer.stats()
	for i: int in range(60):
		field.select_view(Rect2(0, 0, 128, 128))
	assert_eq(field.renderer.lookups, int(before.index_queries))
	assert_eq(field.renderer.builds, int(before.builds))
	assert_eq(field.renderer.instances, 1)
	assert_eq(field.get_child_count(), 0)
	assert_eq(field.index_builds, 1)

func test_lru_cache_is_bounded_and_live_rids_accounted_for() -> void:
	var values: Array[Dictionary] = []
	for i: int in range(40):
		values.append(_sample(i * 256 + 64, 64))
	var field: GrassChunkField = _field(values)
	field.max_resident_chunks = 3
	field.max_resident_instances = 3
	field.rebuild()
	for i: int in range(40):
		field.select_view(Rect2(i * 256 + 32, 32, 64, 64))
		assert_lte(field.renderer.resident.size(), 3)
		assert_lte(field.renderer.instances, 3)
		assert_eq(field.renderer.allocated_leaves - field.renderer.freed_leaves, field.renderer.resident.size())
	field.renderer.clear()
	field.renderer.clear()
	assert_eq(field.renderer.allocated_leaves, field.renderer.freed_leaves)
	assert_eq(field.renderer.instances, 0)

func test_budget_overflow_is_explicit_and_never_silently_truncates() -> void:
	var field: GrassChunkField = _field([_sample(64, 64), _sample(320, 64)])
	field.max_resident_chunks = 1
	field.rebuild()
	field.select_view(Rect2(0, 0, 500, 128))
	assert_ne(field.renderer.last_error, "")
	assert_eq(field.renderer.instances, 0)
	assert_eq(field.renderer.resident.size(), 0)

func test_hide_disable_reenter_and_transform_rebuild() -> void:
	var field: GrassChunkField = _field([_sample(64, 64)])
	field.hide()
	assert_false(field.is_processing())
	field.show()
	field.set_enabled(false)
	assert_false(field.is_processing())
	field.set_enabled(true)
	var built: int = field.index_builds
	field.position = Vector2(32, 0)
	field.update_view()
	assert_eq(field.index_builds, built + 1)
	var parent: Node = field.get_parent()
	parent.remove_child(field)
	assert_eq(field.renderer.allocated_leaves, field.renderer.freed_leaves)
	parent.add_child(field)
	assert_gt(field.renderer.instances, 0)
	assert_eq(field.get_child_count(), 0)

func test_fractional_rows_cannot_exceed_the_gpu_batch_budget() -> void:
	var field: GrassChunkField = _field([_sample(64, 64), _sample(64, 64.25), _sample(64, 64.5)])
	field.max_resident_batches = 2
	field.rebuild()
	field.select_view(Rect2(0, 0, 128, 128))
	assert_ne(field.renderer.last_error, "")
	assert_eq(field.renderer.resident.size(), 0)
	assert_eq(field.renderer.allocated_leaves, field.renderer.freed_leaves)

func test_dense_single_chunk_respects_instance_budget() -> void:
	var field: GrassChunkField = _field([_sample(48, 64), _sample(64, 64), _sample(80, 64)])
	field.max_resident_instances = 2
	field.rebuild()
	field.select_view(Rect2(0, 0, 128, 128))
	assert_ne(field.renderer.last_error, "")
	assert_eq(field.renderer.instances, 0)

func test_extreme_zoom_rejects_before_enumerating_millions_of_empty_cells() -> void:
	var field: GrassChunkField = _field([_sample(64, 64)])
	field.select_view(Rect2(0, 0, 1000000, 1000000))
	assert_true(field.renderer.last_error.contains("16384"))
	assert_eq(field.renderer.resident.size(), 0)

func test_query_expands_for_oversized_transformed_grass_and_wind() -> void:
	var index: GrassChunkIndex = GrassChunkIndex.new()
	var value: Dictionary = _sample(272, 64)
	value.transform = Transform2D(0.0, Vector2(8, 8), 0.0, Vector2(272, 64))
	index.build([value], GrassSourceCatalog.new(), 256, Transform2D.IDENTITY)
	var region: Rect2i = index.cell_rect(Rect2(180, 0, 50, 128), 8)
	assert_true(Vector2i(1, 0) in index.lookup(region))
