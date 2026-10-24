extends GutTest
var feed: GrassInteractionFeed
var material: ShaderMaterial
var world: Node2D

func before_each() -> void:
	feed = GrassInteractionFeed.new()
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/grass_field.gdshader")
	world = Node2D.new()
	add_child_autofree(world)

func after_each() -> void:
	feed.detach()

func _actor(point: Vector2) -> Node2D:
	var actor: Node2D = Node2D.new()
	actor.position = point
	world.add_child(actor)
	feed.register_actor(actor, 10)
	return actor

func _tick(delta: float = 0.016667, force: bool = true) -> void:
	feed.tick(delta, Rect2(0, 0, 512, 512), material, force)

func test_all_87_and_96_slots_are_preserved_and_overflow_is_explicit() -> void:
	for i: int in range(87):
		_actor(Vector2(100, 100))
	_tick()
	assert_eq(feed.eligible, 87)
	assert_eq(feed.uploaded, 87)
	for i: int in range(9):
		_actor(Vector2(100, 100))
	_tick()
	assert_eq(feed.uploaded, 96)
	_actor(Vector2(100, 100))
	_tick()
	assert_eq(feed.eligible, 97)
	assert_eq(feed.uploaded, 0)
	assert_true(feed.last_error.contains("97"))

func test_fast_sweep_stationary_contact_and_teleport_reset() -> void:
	var actor: Node2D = _actor(Vector2(50, 100))
	_tick()
	actor.position.x = 100
	_tick()
	assert_eq(feed.segments[0], Vector4(50, 100, 100, 100))
	_tick(0.2)
	assert_eq(feed.uploaded, 1)
	assert_gt(feed.clock - feed.parameters[0].z, 0.18)
	actor.position.x = 400
	_tick()
	assert_eq(feed.segments[0], Vector4(400, 100, 400, 100))
	assert_eq(feed.teleports, 1)
	actor.position.x = 410
	feed.reset_motion(actor)
	_tick()
	assert_eq(feed.segments[0], Vector4(410, 100, 410, 100))

func test_swept_contact_is_eligible_even_when_both_ends_are_outside_view() -> void:
	var actor: Node2D = _actor(Vector2(0, 100))
	actor.position.x = 80
	feed.tick(0.02, Rect2(30, 90, 10, 20), material, true)
	assert_eq(feed.eligible, 1)
	assert_eq(feed.segments[0], Vector4(0, 100, 80, 100))

func test_upload_rates_have_bounded_latency_and_no_catchup_loop() -> void:
	_actor(Vector2(100, 100))
	for rate: int in [30, 60]:
		feed.upload_hz = rate
		_tick(0.0)
		var before: int = feed.uploads
		for i: int in range(120):
			_tick(1.0 / 120.0, false)
		assert_eq(feed.uploads - before, rate)

func test_scope_spawn_removal_and_hidden_actor_do_not_leave_stale_slots() -> void:
	feed.attach(world)
	var actor: Node2D = Node2D.new()
	actor.add_to_group(&"grass_interactors")
	actor.position = Vector2(100, 100)
	world.add_child(actor)
	await get_tree().process_frame
	_tick()
	assert_eq(feed.uploaded, 1)
	actor.hide()
	_tick()
	assert_eq(feed.uploaded, 0)
	actor.show()
	_tick()
	actor.free()
	_tick()
	assert_eq(feed.entries.size(), 0)
	assert_eq(feed.uploaded, 0)
	assert_eq(int(material.get_shader_parameter(&"actor_count")), 0)

func test_uniform_clock_rebase_preserves_motion_age() -> void:
	var actor: Node2D = _actor(Vector2(100, 100))
	feed.clock = 1023.95
	actor.position.x = 110
	_tick(0.01)
	_tick(0.1)
	assert_lt(feed.clock, 1024.0)
	assert_almost_eq(feed.clock - feed.parameters[0].z, 0.1, 0.0001)

func test_registration_uses_global_feet_and_scaled_radius() -> void:
	world.position = Vector2(50, 70)
	world.scale = Vector2(2, 3)
	_actor(Vector2(20, 20))
	_tick()
	assert_eq(feed.segments[0], Vector4(90, 130, 90, 130))
	assert_eq(feed.parameters[0].x, 30.0)

func test_hidden_actor_reappears_without_a_phantom_sweep() -> void:
	var actor: Node2D = _actor(Vector2(100, 100))
	_tick()
	actor.hide()
	_tick()
	actor.position.x = 160
	actor.show()
	_tick()
	assert_eq(feed.segments[0], Vector4(160, 100, 160, 100))

func test_resume_reset_discards_old_movement_for_every_actor() -> void:
	var actor: Node2D = _actor(Vector2(100, 100))
	_tick()
	actor.position.x = 160
	feed.reset_all_motion()
	_tick()
	assert_eq(feed.segments[0], Vector4(160, 100, 160, 100))
