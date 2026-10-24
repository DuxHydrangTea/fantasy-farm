extends GutTest

var router: TouchGestureRouter

func before_each() -> void:
	router = TouchGestureRouter.new()
	router.joystick_center = Vector2(40, 40)
	watch_signals(router)

func test_joystick_keeps_its_finger_outside_zone_and_second_finger_acts_once() -> void:
	router.begin(4, Vector2(40, 40), &"joystick")
	router.drag(4, Vector2(500, 40))
	assert_eq(router.direction, Vector2.RIGHT)
	router.begin(8, Vector2(700, 300), &"tool")
	router.drag(8, Vector2(400, 200))
	router.end(8, Vector2(400, 200))
	assert_signal_emit_count(router, "action_requested", 1)
	assert_eq(router.joystick_id, 4)
	assert_eq(router.direction, Vector2.RIGHT)
	router.end(4, Vector2(900, 40))
	assert_eq(router.direction, Vector2.ZERO)
	assert_signal_not_emitted(router, "tapped")

func test_only_short_stationary_world_release_is_a_tap() -> void:
	router.begin(0, Vector2(200, 100), &"world")
	assert_signal_not_emitted(router, "tapped")
	router.end(0, Vector2(202, 100))
	assert_signal_emit_count(router, "tapped", 1)
	router.begin(0, Vector2(200, 100), &"world")
	router.drag(0, Vector2(250, 100))
	router.drag(0, Vector2(200, 100))
	router.end(0, Vector2(200, 100))
	router.begin(1, Vector2(200, 100), &"world")
	router.end(1, Vector2(200, 100), true)
	router.begin(2, Vector2(200, 100), &"world")
	router.fingers[2].started = Time.get_ticks_msec() - 700
	router.end(2, Vector2(200, 100))
	assert_signal_emit_count(router, "tapped", 1)

func test_pinch_suppresses_both_taps_and_rebases_when_finger_pair_changes() -> void:
	router.begin(0, Vector2(200, 100), &"world")
	router.begin(1, Vector2(300, 100), &"world")
	router.drag(1, Vector2(400, 100))
	assert_signal_emitted_with_parameters(router, "pinched", [2.0])
	assert_signal_emit_count(router, "pinch_started", 1)
	router.begin(2, Vector2(600, 100), &"world")
	router.end(1, Vector2(400, 100))
	assert_signal_emit_count(router, "pinched", 1, "Changing a pair must not jump the zoom")
	router.drag(2, Vector2(640, 100))
	assert_signal_emitted_with_parameters(router, "pinched", [1.1])
	router.end(2, Vector2(640, 100))
	router.end(0, Vector2(200, 100))
	assert_signal_not_emitted(router, "tapped")

func test_ui_and_action_fingers_cannot_turn_into_world_pinch_or_tap() -> void:
	router.begin(0, Vector2(200, 100), &"ui")
	router.begin(1, Vector2(300, 100), &"world")
	router.drag(0, Vector2(700, 100))
	router.begin(2, Vector2(700, 300), &"interact")
	router.drag(2, Vector2(300, 100))
	router.end(0, Vector2(700, 100))
	router.end(2, Vector2(300, 100))
	assert_signal_not_emitted(router, "pinched")
	assert_signal_not_emitted(router, "tapped")
	assert_signal_emit_count(router, "action_requested", 1)
	router.end(1, Vector2(300, 100))
	assert_signal_emit_count(router, "tapped", 1)

func test_cancel_forgets_all_touches_and_late_releases_do_nothing() -> void:
	router.begin(0, Vector2(70, 40), &"joystick")
	router.begin(1, Vector2(200, 100), &"world")
	router.cancel()
	assert_eq(router.direction, Vector2.ZERO)
	assert_true(router.fingers.is_empty())
	router.end(1, Vector2(200, 100))
	router.drag(0, Vector2(500, 40))
	assert_eq(router.direction, Vector2.ZERO)
	assert_signal_not_emitted(router, "tapped")
