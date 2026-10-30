extends GutTest
const Bubbles = preload("res://components/condition_badges.gd")
var bubble: Bubbles

func before_each() -> void:
	bubble = Bubbles.new()
	add_child_autofree(bubble)

func test_healthy_subject_has_no_visible_popup() -> void:
	bubble.set_statuses(false, false, false)
	assert_false(bubble.visible)
	assert_true(bubble.active_statuses.is_empty())

func test_crop_bubble_matches_approved_order_and_two_icon_width() -> void:
	bubble.set_statuses(true, true, false)
	assert_true(bubble.visible)
	assert_eq_deep(bubble.active_statuses, [&"weeds", &"pests"])
	assert_eq(bubble._background.texture.get_size(), Vector2(48, 27))
	assert_eq(bubble._background.position, Vector2(-24, -27))
	assert_eq(bubble._icons[0].texture.resource_path, "res://assets/Ui/status_bubbles/weeds.png")
	assert_eq(bubble._icons[1].texture.resource_path, "res://assets/Ui/status_bubbles/worm.png")

func test_animal_bubble_shows_all_three_independent_states() -> void:
	bubble.set_statuses(false, false, true, true, true)
	assert_eq_deep(bubble.active_statuses, [&"sick", &"hungry", &"thirsty"])
	assert_eq(bubble._background.texture.get_size(), Vector2(68, 27))
	for index: int in range(2, 5):
		assert_true(bubble._icons[index].visible)
		var icon_rect: Rect2 = Rect2(bubble._icons[index].position, Vector2(16, 16))
		assert_true(Rect2(bubble._background.position, Vector2(68, 23)).encloses(icon_rect))

func test_curing_one_state_keeps_the_others_and_resizes_popup() -> void:
	bubble.set_statuses(false, false, true, true, true)
	bubble.set_statuses(false, false, false, true, true)
	assert_true(bubble.visible)
	assert_eq_deep(bubble.active_statuses, [&"hungry", &"thirsty"])
	assert_false(bubble._icons[2].visible)
	assert_eq(bubble._background.texture.get_size(), Vector2(48, 27))
	bubble.set_statuses(false, false, false, false, true)
	assert_eq(bubble._background.texture.get_size(), Vector2(28, 27))
	bubble.set_statuses(false, false, false, false, false)
	assert_false(bubble.visible)
	assert_true(bubble.active_statuses.is_empty())

func test_repeated_clock_refresh_does_not_restart_pop_animation() -> void:
	bubble.set_statuses(true, false, false)
	var entrance: Tween = bubble._entrance
	assert_not_null(entrance)
	for i: int in range(20):
		bubble.set_statuses(true, false, false)
	assert_eq(bubble._entrance, entrance)
	entrance.custom_step(0.3)
	assert_true(bubble._visual.scale.is_equal_approx(Vector2.ONE))
	bubble.set_statuses(false, false, false)
	bubble.set_statuses(false, true, false)
	assert_ne(bubble._entrance, entrance, "A new popup can animate after the old one disappears")

func test_all_icons_are_native_transparent_16px_and_pixel_filtered() -> void:
	bubble.set_statuses(false, false, true)
	assert_eq(bubble.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	for texture: Texture2D in Bubbles.TEXTURES:
		assert_eq(texture.get_size(), Vector2(16, 16))
		var image: Image = texture.get_image()
		assert_false(image.is_empty())
		assert_true(image.get_pixel(0, 0).a == 0.0)
