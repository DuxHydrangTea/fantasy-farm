extends GutTest
const FEED: Resource = preload("res://items/feeds/poultry_feed.tres")
var player: CharacterBody2D
var state: StateComponent
var selection: ToolSelectionComponent
var interaction: TroughInteractionComponent
var trough: AnimalTrough

func before_each() -> void:
	player = preload("res://scenes/characters/player.tscn").instantiate() as CharacterBody2D
	player.position = Vector2(200, 200)
	add_child_autofree(player)
	state = player.get_node("StateComponent") as StateComponent
	state.set_physics_process(false)
	selection = player.get_node("ToolSelection") as ToolSelectionComponent
	interaction = player.get_node("TroughInteraction") as TroughInteractionComponent
	interaction.set_physics_process(false)
	trough = preload("res://scenes/animals/feed_trough.tscn").instantiate() as AnimalTrough
	trough.position = player.position + Vector2(0, 20)
	add_child_autofree(trough)
	trough.stock = 0
	await wait_physics_frames(2)

func _impact() -> void:
	state.animation.animated_sprite.set_frame_and_progress(3, 0.0)
	interaction._on_frame_changed()

func test_player_uses_shared_inventory_and_refills_once_at_animation_impact() -> void:
	assert_eq(interaction.selection.inventory, selection.inventory)
	assert_eq(selection.inventory.count_item(FEED.item_id), 5)
	assert_true(state.use_selected_tool(&"harvest"))
	assert_eq(state.active_action, &"refill_food")
	assert_eq(trough.stock, 0)
	_impact()
	_impact()
	assert_eq(trough.stock, 600)
	assert_eq(selection.inventory.count_item(FEED.item_id), 3)
	assert_string_contains(interaction.prompt.text, "600/600")

func test_water_requires_selected_can_and_never_consumes_the_tool() -> void:
	trough.kind = AnimalTrough.Kind.WATER
	interaction.refresh()
	assert_string_contains(interaction.prompt.text, "Select a watering can")
	assert_true(state.use_selected_tool())
	assert_eq(state.current_state, StateComponent.State.IDLE)
	selection.select_slot(1)
	assert_true(state.use_selected_tool())
	assert_eq(state.current_state, StateComponent.State.WATER)
	_impact()
	assert_eq(trough.stock, 30)
	assert_eq(selection.inventory.count_item(&"watering_can"), 1)

func test_inventory_open_cancels_before_spending_any_feed() -> void:
	assert_true(state.use_selected_tool())
	selection.set_inventory_open(true)
	_impact()
	assert_eq(trough.stock, 0)
	assert_eq(selection.inventory.count_item(FEED.item_id), 5)
	interaction.refresh()
	assert_false(interaction.prompt.visible)

func test_moving_out_of_reach_before_impact_spends_nothing() -> void:
	assert_true(state.use_selected_tool())
	trough.position += Vector2(100, 0)
	_impact()
	assert_eq(trough.stock, 0)
	assert_eq(selection.inventory.count_item(FEED.item_id), 5)

func test_deleting_target_before_impact_is_safe() -> void:
	assert_true(state.use_selected_tool())
	trough.free()
	_impact()
	assert_eq(selection.inventory.count_item(FEED.item_id), 5)

func test_water_slot_swap_cannot_redirect_the_action() -> void:
	trough.kind = AnimalTrough.Kind.WATER
	selection.select_slot(1)
	assert_true(state.use_selected_tool())
	selection.inventory.move_slot(1, 10)
	_impact()
	assert_eq(trough.stock, 0)

func test_selecting_another_slot_keeps_original_watering_action() -> void:
	trough.kind = AnimalTrough.Kind.WATER
	selection.select_slot(1)
	assert_true(state.use_selected_tool())
	selection.select_slot(0)
	_impact()
	assert_eq(trough.stock, 30)

func test_full_and_missing_feed_block_farming_and_show_reason() -> void:
	selection.inventory.remove(FEED.item_id, 5)
	interaction.refresh()
	assert_string_contains(interaction.prompt.text, "Requires Poultry Feed")
	assert_true(state.use_selected_tool())
	assert_eq(state.active_action, &"")
	trough.stock = trough.capacity
	interaction.refresh()
	assert_string_contains(interaction.prompt.text, "Trough is full")
	assert_true(state.use_selected_tool())
	assert_eq(state.current_state, StateComponent.State.IDLE)

func test_wall_blocks_refill_and_prompt() -> void:
	var wall: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(40, 4)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = player.position + Vector2(0, 8)
	add_child_autofree(wall)
	await wait_physics_frames(2)
	assert_false(interaction.can_reach(trough))
	interaction.refresh()
	assert_null(interaction.focused_trough)
	assert_false(interaction.prompt.visible)

func test_no_nearby_trough_preserves_farming_action() -> void:
	trough.position += Vector2(200, 0)
	assert_true(state.use_selected_tool())
	assert_eq(state.active_action, &"tool")

func test_e_input_is_routed_to_trough_and_nearest_target_is_stable() -> void:
	var other: AnimalTrough = preload("res://scenes/animals/water_trough.tscn").instantiate() as AnimalTrough
	other.position = player.position + Vector2(0, -29)
	add_child_autofree(other)
	assert_eq(interaction.find_trough(), trough)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	state._unhandled_input(event)
	state._physics_process(1.0 / 60.0)
	assert_eq(state.active_action, &"refill_food")
	_impact()
	assert_eq(trough.stock, 600)
	assert_eq(other.stock, 120)

func test_prompt_fits_two_viewport_sizes() -> void:
	for viewport_size: Vector2i in [Vector2i(640, 480), Vector2i(1280, 720)]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = viewport_size
		viewport.world_2d = World2D.new()
		add_child_autofree(viewport)
		var actor: CharacterBody2D = preload("res://scenes/characters/player.tscn").instantiate() as CharacterBody2D
		actor.position = Vector2(viewport_size) / 2.0
		viewport.add_child(actor)
		(actor.get_node("Camera2D") as Camera2D).enabled = false
		(actor.get_node("StateComponent") as StateComponent).set_physics_process(false)
		var station: AnimalTrough = preload("res://scenes/animals/feed_trough.tscn").instantiate() as AnimalTrough
		station.position = actor.position + Vector2(0, 20)
		viewport.add_child(station)
		station.stock = 400
		var component: TroughInteractionComponent = actor.get_node("TroughInteraction") as TroughInteractionComponent
		component.set_physics_process(false)
		await wait_physics_frames(2)
		component.refresh()
		(actor as FarmPlayer).interactions.refresh()
		var badge: PanelContainer = (actor as FarmPlayer).interactions.presenter.badge
		assert_false(component.prompt.visible, "Only the unified badge is shown")
		assert_true(badge.visible)
		var rect: Rect2 = badge.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, badge.size)
		assert_gt(rect.size.x, 0.0)
		assert_gt(rect.size.y, 0.0)
		assert_true(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(rect), str(viewport_size))
		assert_string_contains((actor as FarmPlayer).interactions.presenter.label.text, "400/600")

func test_actor_faces_trough_and_checks_new_obstacle_again_at_impact() -> void:
	# Leave room for a wall between the player and the vertical trough's edge.
	trough.position = player.position + Vector2(0, -28)
	assert_true(state.use_selected_tool())
	assert_eq(state.animation.facing_vector, Vector2.UP)
	var wall: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(40, 4)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = player.position + Vector2(0, -10)
	add_child_autofree(wall)
	await wait_physics_frames(2)
	_impact()
	assert_eq(trough.stock, 0)
	assert_eq(selection.inventory.count_item(FEED.item_id), 5)
