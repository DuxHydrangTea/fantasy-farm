extends GutTest

const ROAMER: Script = preload("res://components/landscape/butterfly_roamer.gd")
const SWARM: PackedScene = preload("res://world/butterfly_swarm.tscn")
const GARDEN: Rect2 = Rect2(1432, 296, 368, 256)

func _butterfly(at: Vector2) -> AnimatedSprite2D:
	var butterfly: AnimatedSprite2D = ROAMER.new() as AnimatedSprite2D
	butterfly.sprite_frames = preload("res://sprite_frames/animals/butterfly_01_frames.tres")
	butterfly.position = at
	butterfly.set("phase", 0.5)
	add_child_autofree(butterfly)
	butterfly.set_process(false)
	return butterfly

func _advance(butterfly: AnimatedSprite2D, seconds: float, fps: int = 60) -> void:
	for frame: int in range(roundi(seconds * fps)):
		butterfly.call("_process", 1.0 / fps)

func test_swarm_starts_with_48_animated_butterflies_across_map() -> void:
	var swarm: Node2D = SWARM.instantiate() as Node2D
	swarm.set("random_seed", 42)
	add_child_autofree(swarm)
	swarm.set_process(false)
	assert_eq(swarm.get_child_count(), 48)
	var occupied: Dictionary = {}
	for child: Node in swarm.get_children():
		var butterfly: AnimatedSprite2D = child as AnimatedSprite2D
		butterfly.set_process(false)
		assert_true(butterfly.is_playing())
		assert_true((butterfly.get("roam_bounds") as Rect2).has_point(butterfly.position))
		occupied[Vector2i(floori(butterfly.position.x / 320), floori(butterfly.position.y / 280))] = true
	assert_gt(occupied.size(), 30, "Butterflies start distributed, not piled at the flowers")

func test_garden_visit_deadline_is_not_refreshed_and_forces_exit() -> void:
	for fps: int in [15, 60, 144]:
		var butterfly: AnimatedSprite2D = _butterfly(GARDEN.get_center())
		butterfly.call("_process", 1.0 / fps)
		assert_eq(int(butterfly.get("flight_state")), ROAMER.FlightState.GARDEN)
		var deadline: float = butterfly.get("_visit_until")
		_advance(butterfly, 29.0, fps)
		assert_eq(int(butterfly.get("flight_state")), ROAMER.FlightState.GARDEN)
		assert_eq(float(butterfly.get("_visit_until")), deadline, "Changing flower targets must not extend a visit")
		_advance(butterfly, 1.1, fps)
		assert_eq(int(butterfly.get("flight_state")), ROAMER.FlightState.LEAVING)
		assert_almost_eq(float(butterfly.get("_cooldown_until")), deadline + 300.0, 0.001)
		_advance(butterfly, 20.0, fps)
		assert_eq(int(butterfly.get("flight_state")), ROAMER.FlightState.ROAM)
		assert_false(GARDEN.grow(48.0).has_point(butterfly.position), "Must actually fly away after the visit")

func test_passing_garden_during_five_minute_cooldown_cannot_retrigger() -> void:
	var butterfly: AnimatedSprite2D = _butterfly(GARDEN.get_center())
	_advance(butterfly, 31.0)
	# Complete its exit, then repeatedly fly over the garden during cooldown.
	_advance(butterfly, 20.0)
	assert_eq(int(butterfly.get("flight_state")), ROAMER.FlightState.ROAM)
	var unlock_at: float = butterfly.get("_cooldown_until")
	while float(butterfly.get("_elapsed")) + 0.5 < unlock_at:
		_hold_at_garden(butterfly)
		butterfly.call("_process", 0.5)
		assert_eq(int(butterfly.get("flight_state")), ROAMER.FlightState.ROAM)
	_hold_at_garden(butterfly)
	butterfly.call("_process", unlock_at - float(butterfly.get("_elapsed")) + 0.01)
	assert_eq(int(butterfly.get("flight_state")), ROAMER.FlightState.GARDEN, "Can visit again once five minutes have passed")

func _hold_at_garden(butterfly: AnimatedSprite2D) -> void:
	butterfly.position = GARDEN.get_center()
	butterfly.set("_to", GARDEN.get_center())
	butterfly.set("_hovering", true)
	butterfly.set("_hover_time", 0.0)

func test_roaming_moves_beyond_old_home_radius_and_stays_within_map() -> void:
	var butterfly: AnimatedSprite2D = _butterfly(Vector2(400, 1200))
	var home: Vector2 = butterfly.position
	var bounds: Rect2 = butterfly.get("roam_bounds")
	var largest_distance: float = 0.0
	var largest_step: float = 0.0
	var escaped: bool = false
	for frame: int in range(60 * 120):
		var before: Vector2 = butterfly.position
		butterfly.call("_process", 1.0 / 60.0)
		largest_distance = maxf(largest_distance, butterfly.position.distance_to(home))
		largest_step = maxf(largest_step, butterfly.position.distance_to(before))
		escaped = escaped or not bounds.grow(0.01).has_point(butterfly.position)
	assert_gt(largest_distance, 200.0)
	assert_lt(largest_step, 3.0, "Changing state or destination must not teleport")
	assert_false(escaped)
