extends GutTest
const Fixture = preload("res://tests/support/farming_fixture.gd")
const CareBubble = preload("res://components/animals/animal_care_bubble.gd")
var field: Node2D
var player: FarmPlayer
var animal: AnimalActor
var pen: AnimalPen
var clock: FarmClock

func before_each() -> void:
	clock = FarmClock.new()
	clock.clock_source = func() -> float: return 1000.0
	add_child_autofree(clock)
	clock.set_process(false)
	field = Fixture.create_field()
	add_child_autofree(field)
	player = preload("res://scenes/characters/player.tscn").instantiate() as FarmPlayer
	player.farming_actions.farming = field.get_node("FarmingController") as FarmingController
	player.position = Vector2(200, 200)
	field.add_child(player)
	pen = AnimalPen.new()
	pen.bounds = Rect2(0, 0, 400, 400)
	field.add_child(pen)
	animal = preload("res://scenes/animals/chicken.tscn").instantiate() as AnimalActor
	animal.definition = preload("res://animals/definitions/cow.tres")
	animal.pen = pen
	animal.position = player.position + Vector2(0, 24)
	(animal.get_node("NeedsComponent") as AnimalNeedsComponent).time_manager = clock
	field.add_child(animal)
	animal.production.definition = animal.production.definition.duplicate() as AnimalProductionDefinition
	animal.production.definition.collection_mode = AnimalProductionDefinition.CollectionMode.DIRECT_COLLECTION
	field.process_mode = Node.PROCESS_MODE_DISABLED
	Sound.stop_all()

func _bubble() -> Node2D:
	for child: Node in animal.get_children():
		if child.get_meta(&"animal_care_feedback", false) and not child.is_queued_for_deletion():
			return child as Node2D
	return null

func _serve(kind: AnimalTrough.Kind) -> AnimalTrough:
	var path: String = "res://scenes/animals/feed_trough.tscn" if kind == AnimalTrough.Kind.FOOD else "res://scenes/animals/water_trough.tscn"
	var trough: AnimalTrough = (load(path) as PackedScene).instantiate() as AnimalTrough
	trough.pen = pen
	trough.position = animal.position - trough.access_offsets[0]
	field.add_child(trough)
	assert_true(trough.claim(animal, 0, animal.definition))
	animal.foraging.target = trough
	animal.foraging.target_slot = 0
	return trough

func test_real_direct_collection_reports_only_accepted_amount_and_cannot_reward_twice() -> void:
	var milk: ItemDefinition = animal.production.definition.production_item
	animal.production.stored_amount = 7
	player.global_position = animal.global_position + Vector2(0, 24)
	var target: InteractionTarget = InteractionTarget.new(animal, InteractionTarget.Kind.ANIMAL, player)
	assert_true(player.interactions.execute(target))
	assert_eq(player.selection.inventory.count_item(milk.item_id), 7)
	assert_eq(animal.production.stored_amount, 0)
	assert_eq(player.item_feedback._popups.size(), 1)
	assert_eq(player.item_feedback._popups[0].amount, 7)
	assert_eq(player.item_feedback._popups[0].icon.texture, milk.icon)
	assert_eq(player.item_feedback._bursts.size(), 1)
	assert_eq(player.item_feedback._bursts[0].icons.size(), 3, "Bounded representatives for any yield")
	player.interactions.execute(target)
	assert_eq(player.selection.inventory.count_item(milk.item_id), 7)
	assert_eq(player.item_feedback._popups.size(), 1)

func test_full_bag_shows_no_positive_collection_effect() -> void:
	animal.production.stored_amount = 5
	var bag: InventoryComponent = player.selection.inventory
	bag.add(preload("res://items/tools/hoe.tres"), 10000)
	player.global_position = animal.global_position + Vector2(0, 24)
	player.interactions.execute(InteractionTarget.new(animal, InteractionTarget.Kind.ANIMAL, player))
	assert_eq(animal.production.stored_amount, 5)
	assert_true(player.item_feedback._bursts.is_empty())
	for popup: ItemGainPopup in player.item_feedback._popups:
		assert_eq(popup.amount, 0)

func test_food_and_water_feedback_only_after_success_and_reuses_one_bubble() -> void:
	animal.needs.satiety = 30.0
	var trough: AnimalTrough = _serve(AnimalTrough.Kind.FOOD)
	assert_null(_bubble())
	assert_gt(animal.foraging.finish(), 0.0)
	var bubble: Node2D = _bubble()
	assert_not_null(bubble)
	assert_eq(bubble.get("feedback_icon"), trough.feed_item.icon)
	assert_eq(bubble.get("text_key"), "Had a meal!")
	animal.foraging.cancel()
	trough.queue_free()
	animal.needs.hydration = 30.0
	_serve(AnimalTrough.Kind.WATER)
	assert_gt(animal.foraging.finish(), 0.0)
	assert_same(_bubble(), bubble)
	assert_eq(bubble.get("text_key"), "Drank water!")
	assert_eq(bubble.get("feedback_icon"), AnimalActor.WATER_FEEDBACK)

func test_failed_meal_and_restored_needs_create_no_success_bubble() -> void:
	var trough: AnimalTrough = _serve(AnimalTrough.Kind.FOOD)
	trough.stock = 0
	assert_eq(animal.foraging.finish(), 0.0)
	assert_null(_bubble())
	animal.needs.restore_state(100, 100, 1000)
	assert_null(_bubble())

func test_care_icons_refresh_expire_and_follow_the_animal() -> void:
	var icon: Texture2D = preload("res://items/boosters/animal_medicine.tres").icon
	var bubble: Node2D = CareBubble.present(animal, icon)
	for index: int in range(20):
		assert_same(CareBubble.present(animal, icon), bubble)
	var row: HBoxContainer = bubble.get_node("BubbleVisual/BubblePanel/Row") as HBoxContainer
	assert_eq((row.get_node("Icon") as TextureRect).texture, icon)
	assert_eq((row.get_node("Icon") as TextureRect).texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	var before: Vector2 = bubble.global_position
	animal.position += Vector2(20, 0)
	assert_eq(bubble.global_position - before, Vector2(20, 0))
	bubble.call("_process", 2.1)
	assert_true(bubble.is_queued_for_deletion())

func test_flower_feedback_uses_the_shared_bounded_reward_effect() -> void:
	var item: ItemDefinition = preload("res://items/animal_produces/chicken_egg.tres")
	player.item_feedback._on_flower_harvest(item, 400, player.position + Vector2(20, 0), player.selection.inventory, field)
	assert_eq(player.item_feedback._bursts.size(), 1)
	assert_eq(player.item_feedback._bursts[0].icons.size(), 3)
	assert_eq(player.item_feedback._popups[0].amount, 400)
	player.item_feedback.clear()
	assert_true(player.item_feedback._popups.is_empty())
	assert_true(player.item_feedback._bursts.is_empty())

func test_partial_collection_shows_only_the_units_that_fit_in_the_bag() -> void:
	var milk: ItemDefinition = animal.production.definition.production_item
	var bag: InventoryComponent = player.selection.inventory
	bag.add(milk, 1)
	bag.add(preload("res://items/tools/hoe.tres"), 10000)
	var space: int = bag.capacity_for(milk)
	assert_gt(space, 1)
	bag.add(milk, space - 1)
	player.item_feedback.clear()
	var before: int = bag.count_item(milk.item_id)
	animal.production.stored_amount = 7
	player.global_position = animal.global_position + Vector2(0, 24)
	assert_true(player.interactions.execute(InteractionTarget.new(animal, InteractionTarget.Kind.ANIMAL, player)))
	assert_eq(bag.count_item(milk.item_id) - before, 1)
	assert_eq(animal.production.stored_amount, 6)
	var gains: Array[ItemGainPopup] = []
	for popup: ItemGainPopup in player.item_feedback._popups:
		if popup.amount > 0:
			gains.append(popup)
	assert_eq(gains.size(), 1)
	assert_eq(gains[0].amount, 1)
	assert_eq(player.item_feedback._bursts[0].amount, 1)
