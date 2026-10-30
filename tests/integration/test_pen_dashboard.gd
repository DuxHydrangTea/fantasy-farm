extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var viewport: SubViewport
var world: FarmWorld

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.set_meta(&"touch_layout", true)
	viewport.size_2d_override_stretch = true
	viewport.size = Vector2i(844, 390)
	viewport.size_2d_override = Vector2i(2337, 1080)
	add_child_autofree(viewport)
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	viewport.add_child(world)
	await wait_physics_frames(3)

func after_each() -> void:
	Language.set_language("en")

func _cow() -> AnimalActor:
	var actor: AnimalActor = preload("res://scenes/animals/animal.tscn").instantiate() as AnimalActor
	actor.definition = preload("res://animals/definitions/cow.tres")
	actor.pen = world.pen_boards[1].pen
	actor.position = actor.pen.bounds.get_center()
	actor.pen.add_child(actor)
	return actor

func _open(board: PenBoard) -> PenDashboard:
	world.player.global_position = board.global_position + Vector2(0, 24)
	world.player.animation.face(Vector2.UP)
	assert_true(board.open_board(world.player))
	return board.menu

func test_signs_exist_before_world_enters_tree_for_editor_preview() -> void:
	var authored: FarmWorld = WORLD.instantiate() as FarmWorld
	for pen_name: String in ["CoopPen", "BarnPen", "PondPen"]:
		var sign: PenBoard = authored.get_node(pen_name + "/ManagementSign") as PenBoard
		assert_not_null(sign)
		assert_not_null(sign.sprite)
		assert_not_null(sign.sprite.texture)
		assert_true(sign.sprite.visible)
		assert_eq(sign.scene_file_path, "res://scenes/animals/pen_board.tscn")
		assert_null(sign.menu, "Only gameplay UI is created at runtime")
	authored.free()

func test_each_pen_has_a_separate_reachable_nonblocking_board() -> void:
	assert_eq(world.pen_boards.size(), 3)
	for board: PenBoard in world.pen_boards:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(6, 6)
		var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(0, board.to_global(Vector2(4, 0)))
		query.collision_mask = 1
		query.exclude = [board.get_rid(), world.player.get_rid()]
		assert_true(world.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), String(board.pen.name))
		world.player.global_position = board.global_position + Vector2(0, 24)
		world.player.animation.face(Vector2.UP)
		var target: InteractionTarget = world.player.interactions.resolver.resolve()
		assert_not_null(target)
		if target != null:
			assert_eq(target.node, board)
			assert_true(world.player.interactions.execute(target))
		assert_true(board.menu.is_open)
		world.objective_ui.open()
		assert_false(world.player.selection.objectives_open)
		board.menu.close()
		await wait_seconds(0.35)
		var hit: InteractionTarget = world.player.interactions.resolver.clicked(board.sprite.global_position)
		assert_not_null(hit)
		if hit != null:
			assert_eq(hit.node, board)
			assert_true(world.player.interactions.execute(hit))
		board.menu.close()
		await wait_seconds(0.35)

func test_cards_are_per_pen_and_portraits_are_independent_idle_animations() -> void:
	var actor: AnimalActor = _cow()
	actor.needs.restore_state(75, 0, TimeManager.now())
	actor.growth.age_seconds = actor.growth.maturity_seconds
	var menu: PenDashboard = _open(world.pen_boards[1])
	assert_eq(menu.cards.size(), 1)
	var card: AnimalCard = menu.cards[actor.get_instance_id()]
	assert_true(card.preview != actor.sprite)
	assert_eq(card.preview.sprite_frames, actor.sprite.sprite_frames)
	assert_true(card.preview.is_playing())
	assert_true(String(card.preview.animation).begins_with("idle"))
	assert_false(actor.persistent_id.is_empty())
	assert_string_contains(card.caption.text, PenStatus.short_id(actor))
	assert_eq(card.food.value, 75.0)
	assert_eq(card.water.value, 0.0)
	assert_string_contains(card.produce.text, "Needs water")
	assert_true(actor.behaviour.request_behaviour(&"walk"))
	actor.set_status_focused(true)
	assert_eq(actor.behaviour.current_state, AnimalBehaviourComponent.State.WALK)
	menu.close()
	await wait_seconds(0.35)
	var pond: PenDashboard = _open(world.pen_boards[2])
	assert_eq(pond.cards.size(), PenStatus.members(world.pen_boards[2].pen).size())
	assert_false(pond.cards.has(actor.get_instance_id()))

func test_trough_percent_is_capacity_weighted_and_excludes_other_pens() -> void:
	var pen: AnimalPen = world.pen_boards[2].pen
	for node: Node in get_tree().get_nodes_in_group(&"animal_troughs"):
		if (node as AnimalTrough).pen == pen and (node as AnimalTrough).kind == AnimalTrough.Kind.WATER:
			(node as AnimalTrough).stock = 0
	var baseline: Dictionary = PenStatus.troughs(pen, AnimalTrough.Kind.WATER)
	var extra: AnimalTrough = AnimalTrough.new()
	extra.pen = pen
	extra.kind = AnimalTrough.Kind.WATER
	extra.capacity = 300
	extra.stock = 300
	pen.add_child(extra)
	var result: Dictionary = PenStatus.troughs(pen, AnimalTrough.Kind.WATER)
	assert_eq(result.stock, 300)
	assert_eq(result.capacity, int(baseline.capacity) + 300)
	assert_almost_eq(result.percent, 30000.0 / float(result.capacity), 0.001)

func test_roster_removes_freed_animals_and_load_closes_dashboard_without_losing_ids() -> void:
	var actor: AnimalActor = _cow()
	var menu: PenDashboard = _open(world.pen_boards[1])
	assert_eq(menu.cards.size(), 1)
	actor.queue_free()
	menu.refresh()
	assert_eq(menu.cards.size(), 0)
	assert_true(menu.empty.visible)
	await wait_process_frames(2)
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var saved: Dictionary = adapter.capture("pen_test", 1, TimeManager.now())
	var ids: Array = []
	for animal: AnimalActor in PenStatus.members(world.pen_boards[2].pen):
		ids.append(String(animal.persistent_id))
	assert_true(adapter.restore(saved, TimeManager.now()).ok)
	assert_false(menu.is_open)
	var restored: Array = []
	for animal: AnimalActor in PenStatus.members(world.pen_boards[2].pen):
		restored.append(String(animal.persistent_id))
	assert_eq(restored, ids)

func test_cards_and_overview_fit_en_vi_phone_safe_areas_at_one_and_three_density() -> void:
	var board: PenBoard = world.pen_boards[2]
	for language: String in ["en", "vi"]:
		Language.set_language(language)
		for density: int in [1, 3]:
			for points: Vector2i in [Vector2i(667, 375), Vector2i(740, 360), Vector2i(844, 390)]:
				viewport.set_meta(&"safe_insets", Vector4(44, 0, 44, 21))
				viewport.set_meta(&"ui_point_scale", float(density))
				viewport.size = points * density
				viewport.size_2d_override = Vector2i(roundi(float(points.x) * 1080 / points.y), 1080)
				await wait_seconds(0.15)
				var menu: PenDashboard = _open(board)
				await wait_seconds(0.4)
				var safe: Rect2 = Rect2(Vector2(44, 0) * density, (Vector2(points) - Vector2(88, 21)) * density)
				var rect: Rect2 = viewport.get_stretch_transform() * menu.panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, menu.panel.size)
				assert_true(safe.grow(1).encloses(rect), str(language, " density=", density, " points=", points, " safe=", safe, " actual=", rect, " root=", menu.root.size))
				assert_gte(menu.close_button.size.y, 48.0)
				assert_gte(menu.grid.columns, 2)
				assert_gt(menu.scroll.size.y, 48.0)
				menu.close()
				await wait_seconds(0.35)
