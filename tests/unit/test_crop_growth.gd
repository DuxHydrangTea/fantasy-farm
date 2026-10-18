extends GutTest

const Clock = preload("res://components/time_manager.gd")
const Definition = preload("res://scripts/crop_definition.gd")
const CROP: PackedScene = preload("res://scenes/crops/crop.tscn")
const Crop = preload("res://components/crop.gd")
var timestamp: float = 1000.0
var clock: Clock
var crop: Crop
var definition: Definition

func before_each() -> void:
	timestamp = 1000.0
	clock = Clock.new()
	clock.clock_source = func() -> float: return timestamp
	add_child_autofree(clock)
	clock.set_process(false)
	crop = CROP.instantiate() as Crop
	add_child_autofree(crop)
	definition = (load("res://crops/field/carrot/carrot.tres") as Definition).duplicate()
	definition.growth_seconds = 90.0
	crop.configure(definition, timestamp)

func test_four_stages_at_exact_timestamp_boundaries() -> void:
	for sample: Array in [[0.0, 0], [29.99, 0], [30.0, 1], [59.99, 1], [60.0, 2], [89.99, 2], [90.0, 3]]:
		crop.refresh(timestamp + float(sample[0]))
		assert_eq(crop.stage, int(sample[1]))
		assert_eq(crop.sprite.texture, definition.stage_textures[int(sample[1])])
		assert_almost_eq(crop.progress_bar.value, float(sample[0]) / 90.0, 0.0001)
	assert_true(crop.is_mature())

func test_timestamp_jump_catches_up_without_processing_frames() -> void:
	watch_signals(crop)
	crop.refresh(timestamp + 9000.0)
	assert_eq(crop.stage, 3)
	assert_eq(crop.progress, 1.0)
	crop.refresh(timestamp + 10000.0)
	assert_signal_emit_count(crop, "matured", 1)

func test_backward_clock_cannot_reverse_growth() -> void:
	crop.refresh(timestamp + 60.0)
	crop.refresh(timestamp - 60.0)
	assert_eq(crop.stage, 2)
	assert_almost_eq(crop.progress, 2.0 / 3.0, 0.0001)
	assert_eq(clock.now(), 1000.0)
	timestamp = 900.0
	assert_eq(clock.now(), 1000.0)
	timestamp = 1050.0
	assert_eq(clock.now(), 1050.0)

func test_progress_above_sprite_does_not_capture_mouse() -> void:
	var frame: Control = crop.get_node("Progress")
	var texture: Texture2D = crop.sprite.texture
	var visible_top: float = crop.sprite.position.y - texture.get_height() * 0.5 + texture.get_image().get_used_rect().position.y
	assert_almost_eq(frame.position.y + frame.size.y, visible_top - 2.0, 0.001)
	assert_eq(frame.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(crop.progress_bar.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_existing_crop_catalog_has_four_valid_stages_and_harvest() -> void:
	var directory: DirAccess = DirAccess.open("res://crops/field")
	var checked: int = 0
	for crop_name: String in directory.get_directories():
		var path: String = "res://crops/field/%s/%s.tres" % [crop_name, crop_name]
		var data: Definition = load(path) as Definition
		assert_not_null(data, path)
		if data != null:
			assert_true(data.is_valid(), path)
			assert_true(data.has_valid_harvest(), path)
			checked += 1
	assert_eq(checked, 22)

func test_clock_refresh_broadcasts_current_timestamp() -> void:
	watch_signals(clock)
	timestamp = 1200.0
	clock.refresh()
	assert_signal_emitted_with_parameters(clock, "tick", [1200.0])
