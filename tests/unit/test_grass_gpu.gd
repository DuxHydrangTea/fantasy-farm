extends GutTest
var catalog: GrassSourceCatalog

func before_each() -> void:
	catalog = GrassSourceCatalog.new()

func test_baked_atlas_keeps_every_pixel_of_all_original_strips() -> void:
	assert_eq(catalog.size(), 18)
	var atlas: Image = Image.load_from_file(ProjectSettings.globalize_path(GrassSourceCatalog.ATLAS_PATH))
	assert_eq(atlas.get_size(), Vector2i(128, 288))
	for index: int in range(catalog.size()):
		var row: Dictionary = catalog.source(index)
		var original: Image = Image.load_from_file(ProjectSettings.globalize_path(row.path))
		original.convert(Image.FORMAT_RGBA8)
		var packed: Image = atlas.get_region(Rect2i(0, index * 16, 128, 16))
		assert_eq(packed.get_data(), original.get_data(), String(row.id))

func test_manifest_root_is_constant_for_every_original_animation_frame() -> void:
	var root_values: Array[int] = []
	for index: int in range(catalog.size()):
		var row: Dictionary = catalog.source(index)
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(row.path))
		root_values.append(int(row.root_y))
		for frame: int in range(8):
			var region: Image = image.get_region(Rect2i(frame * 16, 0, 16, 16))
			assert_eq(region.get_used_rect().end.y, int(row.root_y))
	assert_true(10 in root_values and 12 in root_values and 15 in root_values)

func test_owning_node_has_no_per_tuft_children_or_process_loops() -> void:
	var field: GrassField = GrassField.new()
	field.tuft_count = 500
	add_child_autofree(field)
	assert_eq(field.get_child_count(), 0)
	assert_false(field.is_processing())
	assert_false(field.is_physics_processing())
	assert_eq(field.renderer.instances.instance_count, 500)
	assert_eq(field.renderer.instances.use_custom_data, true)
	field.set_samples([])
	assert_null(field.renderer.instances)
	field.renderer.clear() # Clearing twice must be harmless.

func test_bounds_include_flips_nonuniform_scale_and_transparent_pixels_below_root() -> void:
	var field: GrassField = GrassField.new()
	field.samples = [{"type": 15, "transform": Transform2D(0.0, Vector2(-2, 3), 0.0, Vector2(80, 120)), "phase": 0.0}]
	add_child_autofree(field)
	var rect: Rect2 = field.renderer.bounds
	assert_true(rect.has_point(Vector2(64, 90)))
	assert_true(rect.has_point(Vector2(95.9, 137.9)))
	assert_eq(rect.size, Vector2(32, 48))
