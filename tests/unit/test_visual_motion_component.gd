extends GutTest

func test_custom_pivot_stays_fixed_with_transformed_visual_and_parent() -> void:
	var actor: Node2D = Node2D.new()
	actor.position = Vector2(120, 80)
	actor.rotation = 0.25
	actor.scale = Vector2(1.3, 0.9)
	add_child_autofree(actor)
	var visual: Sprite2D = Sprite2D.new()
	visual.position = Vector2(10, -18)
	visual.rotation = 0.3
	visual.scale = Vector2(1.2, 0.8)
	visual.skew = 0.1
	actor.add_child(visual)
	var rest: Transform2D = visual.transform
	var motion: VisualMotionComponent = VisualMotionComponent.new()
	motion.target = visual
	motion.pivot = Vector2(5, 4)
	actor.add_child(motion)
	var anchor_local: Vector2 = rest.affine_inverse() * motion.pivot
	var anchor_world: Vector2 = actor.to_global(motion.pivot)
	motion.react(8.0, -1.0)
	await wait_seconds(0.06)
	assert_false(visual.transform.is_equal_approx(rest))
	assert_almost_eq(visual.to_global(anchor_local).x, anchor_world.x, 0.001)
	assert_almost_eq(visual.to_global(anchor_local).y, anchor_world.y, 0.001)
	motion.play_appear()
	await wait_seconds(0.07)
	assert_almost_eq(visual.to_global(anchor_local).x, anchor_world.x, 0.001)
	assert_almost_eq(visual.to_global(anchor_local).y, anchor_world.y, 0.001)
	await wait_seconds(0.4)
	assert_true(visual.transform.is_equal_approx(rest))
	assert_false(motion.is_animating())

func test_animated_animal_visual_keeps_animation_flip_body_and_collision() -> void:
	var actor: CharacterBody2D = CharacterBody2D.new()
	actor.position = Vector2(300, 200)
	actor.velocity = Vector2(12, -8)
	add_child_autofree(actor)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(12, 6)
	collision.shape = shape
	actor.add_child(collision)
	var visual: AnimatedSprite2D = AnimatedSprite2D.new()
	visual.position = Vector2(0, -5)
	visual.sprite_frames = load("res://sprite_frames/animals/chicken_01_frames.tres") as SpriteFrames
	visual.flip_h = true
	actor.add_child(visual)
	visual.play(&"idle_down")
	var body_pose: Transform2D = actor.global_transform
	var collision_pose: Transform2D = collision.transform
	var rest: Transform2D = visual.transform
	var motion: VisualMotionComponent = VisualMotionComponent.new()
	motion.target = visual
	actor.add_child(motion)
	motion.react(10.0)
	await wait_seconds(0.06)
	assert_gt(absf(visual.rotation), 0.01)
	assert_eq(actor.global_transform, body_pose)
	assert_eq(actor.velocity, Vector2(12, -8))
	assert_eq(collision.transform, collision_pose)
	assert_eq(collision.shape, shape)
	assert_eq(visual.animation, &"idle_down")
	assert_true(visual.is_playing())
	assert_true(visual.flip_h)
	assert_null(visual.material, "Animals do not get wind unless explicitly assigned")
	await wait_seconds(0.5)
	assert_true(visual.transform.is_equal_approx(rest))

func test_removing_component_resets_pose_and_restores_opt_in_material() -> void:
	var actor: Node2D = Node2D.new()
	add_child_autofree(actor)
	var visual: Sprite2D = Sprite2D.new()
	visual.position = Vector2(0, -16)
	var original_material: CanvasItemMaterial = CanvasItemMaterial.new()
	visual.material = original_material
	actor.add_child(visual)
	var rest: Transform2D = visual.transform
	var motion: VisualMotionComponent = VisualMotionComponent.new()
	motion.target = visual
	motion.wind_material = load("res://resources/effects/crop_wind.tres") as ShaderMaterial
	actor.add_child(motion)
	assert_eq(visual.material, motion.wind_material)
	motion.react(7.0)
	await wait_seconds(0.06)
	assert_false(visual.transform.is_equal_approx(rest))
	motion.queue_free()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(actor))
	assert_true(visual.transform.is_equal_approx(rest))
	assert_eq(visual.material, original_material)

func test_disappearance_reports_completion_without_deleting_target_and_reset_reuses_it() -> void:
	var actor: Node2D = Node2D.new()
	add_child_autofree(actor)
	var visual: Sprite2D = Sprite2D.new()
	visual.modulate = Color(0.7, 0.8, 0.9, 0.4)
	actor.add_child(visual)
	var rest: Transform2D = visual.transform
	var motion: VisualMotionComponent = VisualMotionComponent.new()
	motion.target = visual
	actor.add_child(motion)
	watch_signals(motion)
	motion.play_disappear()
	await wait_seconds(0.25)
	assert_true(is_instance_valid(visual))
	assert_signal_emitted_with_parameters(motion, "effect_finished", [&"disappear"])
	assert_signal_emit_count(motion, "effect_finished", 1)
	assert_almost_eq(visual.modulate.a, 0.0, 0.001)
	motion.react()
	assert_false(motion.is_animating(), "A retiring visual cannot restart a reaction")
	motion.reset()
	assert_true(visual.transform.is_equal_approx(rest))
	assert_almost_eq(visual.modulate.a, 0.4, 0.001)
	assert_almost_eq(visual.modulate.r, 0.7, 0.001)
	motion.play_appear()
	await wait_seconds(0.4)
	assert_signal_emitted_with_parameters(motion, "effect_finished", [&"appear"])
	assert_true(visual.transform.is_equal_approx(rest))
