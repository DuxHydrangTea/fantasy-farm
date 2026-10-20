extends GutTest
const Fixture = preload("res://tests/support/farming_fixture.gd")
var timestamp: float = 1000.0

func test_farm_updates_at_stage_deadlines_and_focused_progress_stays_current() -> void:
	timestamp = 1000.0
	var clock: FarmClock = FarmClock.new()
	clock.clock_source = func() -> float: return timestamp
	add_child_autofree(clock)
	clock.set_process(false)
	var field: Node2D = Fixture.create_field()
	var farm: FarmingController = field.get_node("FarmingController") as FarmingController
	farm.time_manager = clock
	add_child_autofree(field)
	farm.restore_crop(Vector2i(20, 20), load("res://crops/field/carrot/carrot.tres"), 1000.0, 1120.0, 0.0, 1000.0)
	var crop: Crop = farm.get_crop(Vector2i(20, 20))
	timestamp = 1020.0
	clock.refresh()
	assert_eq(crop.progress, 0.0, "Offscreen crops need no refresh between stage deadlines")
	crop.set_status_focused(true)
	assert_almost_eq(crop.progress, 1.0 / 6.0, 0.001)
	timestamp = 1040.0
	clock.refresh()
	assert_eq(crop.stage, 1)
	timestamp = 1120.0
	clock.refresh()
	assert_true(crop.is_mature())

func test_one_frame_tool_animation_applies_farming_once() -> void:
	var field: Node2D = Fixture.create_field()
	var farm: FarmingController = field.get_node("FarmingController") as FarmingController
	add_child_autofree(field)
	var player: FarmPlayer = preload("res://scenes/characters/player.tscn").instantiate() as FarmPlayer
	player.farming_actions.farming = farm
	player.position = farm.farmland.map_to_local(Vector2i(20, 20))
	Fixture.mark_cell(field, Vector2i(20, 19))
	field.add_child(player)
	player.animation.face(Vector2.UP)
	var frames: SpriteFrames = player.animation.animated_sprite.sprite_frames.duplicate(true)
	while frames.get_frame_count(&"tool_up") > 1:
		frames.remove_frame(&"tool_up", frames.get_frame_count(&"tool_up") - 1)
	frames.set_animation_loop(&"tool_up", false)
	player.animation.animated_sprite.sprite_frames = frames
	watch_signals(farm)
	assert_true(player.state.use_selected_tool())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(farm.get_soil_state(Vector2i(20, 19)), FarmingController.Soil.DRY)
	await wait_physics_frames(20)
	assert_signal_emit_count(farm, "soil_changed", 1)

func test_inventory_queries_are_safe_and_keep_slot_snapshots_isolated() -> void:
	var bag: InventoryComponent = InventoryComponent.new()
	add_child_autofree(bag)
	assert_eq(bag.get_slot_item(0), bag.HOE)
	assert_eq(bag.get_slot_count(0), 1)
	assert_true(bag.is_empty_slot(2))
	assert_null(bag.get_slot_item(-1))
	assert_eq(bag.get_slot_count(500), 0)
	var snapshot: Dictionary = bag.slot(0)
	snapshot.count = 99
	assert_eq(bag.get_slot_count(0), 1)

func test_growth_deadlines_order_cancel_reschedule_and_free_are_safe() -> void:
	var schedule: GrowthSchedule = GrowthSchedule.new()
	var first: Node = Node.new()
	var second: Node = Node.new()
	add_child_autofree(first)
	add_child_autofree(second)
	schedule.schedule(first, 30.0)
	schedule.schedule(second, 10.0)
	assert_true(schedule.take_due(9.0).is_empty())
	assert_eq(schedule.take_due(10.0), [second])
	schedule.cancel(first)
	schedule.schedule(first, 50.0)
	assert_true(schedule.take_due(30.0).is_empty(), "Cancelled ticket cannot fire after rescheduling")
	assert_eq(schedule.take_due(100.0), [first])
	var removed: Node = Node.new()
	schedule.schedule(removed, 110.0)
	removed.free()
	assert_true(schedule.take_due(120.0).is_empty())

func test_growth_heap_handles_large_unsorted_batch_once() -> void:
	var schedule: GrowthSchedule = GrowthSchedule.new()
	var targets: Array[Node] = []
	for index: int in range(250):
		var target: Node = Node.new()
		add_child_autofree(target)
		targets.append(target)
		schedule.schedule(target, float((index * 37) % 250))
	var seen: Dictionary = {}
	for time: int in range(250):
		for target: Node in schedule.take_due(float(time)):
			assert_false(seen.has(target))
			seen[target] = true
	assert_eq(seen.size(), 250)
	assert_true(schedule.take_due(1000.0).is_empty())

func test_impact_frame_clamps_to_last_frame_in_short_animations() -> void:
	var component: AnimationComponent = AnimationComponent.new()
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(&"tool_down")
	var texture: Texture2D = load("res://resources/ui/soil_focus.tres")
	frames.add_frame(&"tool_down", texture)
	frames.set_animation_loop(&"tool_down", false)
	sprite.sprite_frames = frames
	sprite.animation = &"tool_down"
	component.animated_sprite = sprite
	add_child_autofree(sprite)
	add_child_autofree(component)
	assert_true(component.impact_reached(3))
	frames.add_frame(&"tool_down", texture)
	assert_false(component.impact_reached(3))
	sprite.frame = 1
	assert_true(component.impact_reached(3))
