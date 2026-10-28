extends GutTest

const POT: PackedScene = preload("res://scenes/flowers/flower_pot.tscn")

func _pot() -> FlowerPot:
	var value: FlowerPot = POT.instantiate() as FlowerPot
	add_child_autofree(value)
	return value

func _texture(color: Color) -> ImageTexture:
	var image: Image = Image.create(32, 24, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _plant(pot: FlowerPot) -> void:
	var flower: FlowerDefinition = load("res://flowers/definitions/flower_01.tres")
	pot.restore_state({"planted_at": 1000.0, "growth_started_at": 1000.0, "matures_at": 2000.0, "progress": 0.5}, flower, 1500.0)

func test_empty_and_planted_pots_share_live_texture_without_baking() -> void:
	var shared: PotDefinition = PotDefinition.new()
	shared.texture = _texture(Color.RED)
	var empty: FlowerPot = _pot()
	var planted: FlowerPot = _pot()
	empty.pot_definition = shared
	planted.pot_definition = shared
	_plant(planted)
	var texture: Texture2D = planted.sprite.texture
	assert_eq(empty.get_status_sprite(), empty.visual.pot_sprite)
	assert_false(empty.sprite.visible)
	assert_true(planted.sprite.visible)
	assert_eq(empty.visual.pot_sprite.texture, shared.texture)
	assert_eq(planted.visual.pot_sprite.texture, shared.texture)
	shared.texture = _texture(Color.BLUE)
	assert_eq(empty.visual.pot_sprite.texture.get_image().get_pixel(0, 0), Color.BLUE)
	assert_eq(planted.visual.pot_sprite.texture.get_image().get_pixel(0, 0), Color.BLUE)
	shared.texture = _texture(Color.GREEN)
	assert_eq(empty.visual.pot_sprite.texture, shared.texture)
	assert_eq(planted.visual.pot_sprite.texture, shared.texture)
	assert_eq(planted.sprite.texture, texture)
	assert_eq(planted.progress, 0.5)

func test_skin_change_is_isolated_and_does_not_reset_custom_transforms_or_state() -> void:
	var first: FlowerPot = _pot()
	var second: FlowerPot = _pot()
	_plant(first)
	var events: Array[int] = [0]
	first.changed.connect(func() -> void: events[0] += 1)
	first.visual.position = Vector2(2, -1)
	first.visual.plant_offset.position = Vector2(3, 4)
	first.sprite.position = Vector2(-15, -29)
	var custom: PotDefinition = first.pot_definition.duplicate() as PotDefinition
	custom.pot_id = &"custom"
	custom.texture = _texture(Color.YELLOW)
	custom.plant_socket = Vector2(0, -12)
	first.pot_definition = custom
	custom.plant_socket = Vector2(1, -11)
	first.refresh(1500.0)
	assert_eq(first.visual.position, Vector2(2, -1))
	assert_eq(first.visual.plant_offset.position, Vector2(3, 4))
	assert_eq(first.sprite.position, Vector2(-15, -29))
	assert_eq(first.visual.plant_socket.position, Vector2(1, -11))
	assert_ne(first.visual.pot_sprite.texture, second.visual.pot_sprite.texture)
	assert_eq(second.pot_definition.pot_id, &"clay")
	assert_eq(first.progress, 0.5)
	assert_eq(first.growth_started_at, 1000.0)
	assert_eq(events[0], 0)

func test_editor_preview_is_presentation_only() -> void:
	var pot: FlowerPot = _pot()
	var events: Array[int] = [0]
	pot.changed.connect(func() -> void: events[0] += 1)
	pot.preview_flower = load("res://flowers/definitions/flower_30.tres")
	pot.preview_stage = 3
	pot.apply_editor_preview()
	assert_true(pot.sprite.visible)
	assert_eq(pot.sprite.texture, pot.preview_flower.stage_textures[3])
	assert_null(pot.definition)
	assert_eq(pot.stage, 0)
	assert_eq(pot.planted_at, 0.0)
	assert_eq(pot.growth_started_at, -1.0)
	assert_eq(events[0], 0)
	pot._update_visual()
	assert_false(pot.sprite.visible)

func test_hit_bounds_include_pot_and_flower_and_follow_custom_offset() -> void:
	var pot: FlowerPot = _pot()
	pot.position = Vector2(200, 200)
	var resolver: InteractionResolver = InteractionResolver.new(null)
	var target: InteractionTarget = InteractionTarget.new(pot, InteractionTarget.Kind.FLOWER, null)
	assert_true(resolver.hit(target, pot.to_global(Vector2(0, -10))))
	_plant(pot)
	pot.stage = 4
	pot._update_visual()
	assert_true(resolver.hit(target, pot.to_global(Vector2(0, -10))))
	assert_true(resolver.hit(target, pot.to_global(Vector2(0, -25))))
	var before: Rect2 = pot.get_visual_rect()
	pot.visual.plant_offset.position = Vector2(0, -12)
	var after: Rect2 = pot.get_visual_rect()
	assert_almost_eq(after.position.y, before.position.y-12.0, 0.001)
	assert_true(resolver.hit(target, pot.to_global(Vector2(0, -37))))
	assert_false(resolver.hit(target, pot.to_global(Vector2(100, 100))))

func test_default_pot_points_directly_to_the_editable_texture() -> void:
	var pot: FlowerPot = _pot()
	assert_eq(pot.pot_definition.texture.resource_path, "res://assets/Flowers/Unzoom30/clay_pot_16x16.png")
	assert_eq(pot.visual.pot_sprite.texture, pot.pot_definition.texture)
	assert_eq(pot.visual.plant_socket.position, Vector2(0, -10))
	assert_eq(pot.sprite.position, Vector2(0, -14))
	assert_eq(pot.visual.plant_offset.position, Vector2.ZERO)
	assert_eq(pot.sprite.z_index, pot.visual.pot_sprite.z_index)
	assert_false(pot.visual.y_sort_enabled)

func test_flower_uses_crop_wind_without_moving_the_pot() -> void:
	var first: FlowerPot = _pot()
	var second: FlowerPot = _pot()
	_plant(first)
	_plant(second)
	assert_eq(first.sprite.material, load("res://resources/effects/crop_wind.tres"))
	assert_eq(first.sprite.material, second.sprite.material)
	assert_null(first.visual.pot_sprite.material)
	assert_true(first.sprite.centered)
	assert_eq(first.sprite.position, Vector2(0, -14))
	assert_false(first.is_processing())

func test_hover_reacts_once_around_flower_base_and_preserves_state() -> void:
	var pot: FlowerPot = _pot()
	_plant(pot)
	var rest: Transform2D = pot.sprite.transform
	var base: Vector2 = pot.sprite.to_global(Vector2(0, 16))
	var pot_transform: Transform2D = pot.visual.pot_sprite.transform
	watch_signals(pot.motion)
	pot.set_status_focused(true)
	pot.set_status_focused(true)
	assert_signal_emit_count(pot.motion, "effect_started", 1)
	await wait_seconds(0.06)
	assert_gt(absf(pot.sprite.rotation), 0.001)
	assert_almost_eq(pot.sprite.to_global(Vector2(0, 16)).distance_to(base), 0.0, 0.001)
	assert_eq(pot.visual.pot_sprite.transform, pot_transform)
	assert_eq(pot.progress, 0.5)
	await wait_seconds(0.5)
	assert_eq(pot.sprite.transform, rest)
	pot.set_status_focused(false)
	pot.set_status_focused(true)
	assert_signal_emit_count(pot.motion, "effect_started", 2)
