extends GutTest
const CROP: PackedScene = preload("res://scenes/crops/crop.tscn")

func _crop() -> Crop:
	var crop: Crop = CROP.instantiate() as Crop
	assert_not_null(crop.motion)
	assert_eq(crop.motion.target, crop.sprite)
	add_child_autofree(crop)
	crop.configure(load("res://crops/field/carrot/carrot.tres"), 1000.0)
	return crop

func test_reaction_rotates_about_stem_and_returns_to_rest_without_changing_growth() -> void:
	var crop: Crop = _crop()
	var origin: Vector2 = crop.global_position
	var center: Vector2 = crop.sprite.position
	crop.react(7.0)
	await wait_seconds(0.06)
	assert_gt(absf(crop.sprite.rotation), 0.01)
	var stem: Vector2 = crop.sprite.to_global(Vector2(0, crop.sprite.texture.get_height() * 0.5))
	assert_almost_eq(stem.x, origin.x, 0.001)
	assert_almost_eq(stem.y, origin.y, 0.001)
	assert_eq(crop.planted_at, 1000.0)
	assert_eq(crop.progress, 0.0)
	await wait_seconds(0.5)
	assert_almost_eq(crop.sprite.rotation, 0.0, 0.001)
	assert_eq(crop.sprite.position, center)
	assert_eq(crop.sprite.scale, Vector2.ONE)

func test_repeated_focus_does_not_restart_reaction_or_permanently_distort_crop() -> void:
	var crop: Crop = _crop()
	watch_signals(crop.motion)
	crop.set_status_focused(true)
	for index: int in range(4):
		crop.set_status_focused(true)
	assert_signal_emit_count(crop.motion, "effect_started", 1)
	crop.react(5.0)
	crop.play_sprout()
	await wait_seconds(0.5)
	assert_eq(crop.sprite.scale, Vector2.ONE)
	assert_almost_eq(crop.sprite.rotation, 0.0, 0.001)

func test_shared_wind_material_and_retiring_crop_has_no_progress_bar() -> void:
	var first: Crop = _crop()
	var second: Crop = _crop()
	assert_eq(first.sprite.material, second.sprite.material)
	assert_false(first.is_processing(), "Wind uses GPU TIME; no per-crop process callback")
	first.set_status_focused(true)
	first.retire_after_harvest()
	assert_true(first.is_retiring())
	first.set_status_focused(true)
	assert_false(first.progress_frame.visible)
	await wait_seconds(0.25)
	assert_false(is_instance_valid(first))
	assert_true(is_instance_valid(second))

func test_crop_gameplay_still_works_if_optional_motion_component_is_removed() -> void:
	var crop: Crop = _crop()
	crop.motion.free()
	crop.set_status_focused(true)
	crop.react()
	crop.play_sprout()
	crop.refresh(1010.0)
	assert_true(crop.is_mature())
	assert_true(crop.progress_frame.visible)
	crop.retire_after_harvest()
	await wait_physics_frames(2)
	assert_false(is_instance_valid(crop))

func test_high_yield_burst_caps_visuals_and_handles_target_removal() -> void:
	var target: Node2D = Node2D.new()
	add_child(target)
	var burst: HarvestBurst = HarvestBurst.new()
	burst.item = load("res://items/harvest_produces/carrot_produces.tres")
	burst.amount = 100000
	burst.target = weakref(target)
	add_child_autofree(burst)
	assert_eq(burst.icons.size(), 3)
	await wait_seconds(0.1)
	assert_lt(burst.icons[0].position.y, 0.0)
	target.free()
	await wait_seconds(0.8)
	assert_false(is_instance_valid(burst))
