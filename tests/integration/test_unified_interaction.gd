extends GutTest
const FIXTURE = preload("res://tests/support/farming_fixture.gd")
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const MERCHANT: PackedScene = preload("res://scenes/characters/shop_merchant.tscn")
var field: Node2D
var player: FarmPlayer
var farm: FarmingController
var controller: PlayerInteractionComponent
var trough: AnimalTrough
var merchant: ShopMerchant

func before_each() -> void:
	field = FIXTURE.create_field()
	add_child_autofree(field)
	farm = field.get_node("FarmingController") as FarmingController
	player = PLAYER.instantiate() as FarmPlayer
	player.position = farm.farmland.map_to_local(Vector2i(20,20))
	player.farming_actions.farming = farm
	field.add_child(player)
	player.animation.face(Vector2.DOWN)
	controller = player.interactions
	trough = preload("res://scenes/animals/feed_trough.tscn").instantiate() as AnimalTrough
	trough.position = player.position + Vector2(0,20)
	field.add_child(trough)
	trough.stock = 450
	merchant = MERCHANT.instantiate() as ShopMerchant
	merchant.position = player.position + Vector2(32,24)
	field.add_child(merchant)
	await wait_physics_frames(3)

func after_each() -> void:
	Input.action_release(&"move_left")
	Language.set_language("en")

func test_priority_is_merchant_then_trough_then_animal_then_crop_and_one_outline() -> void:
	var crop_cell: Vector2i = Vector2i(20,21)
	FIXTURE.mark_cell(field,crop_cell)
	var seed: ItemDefinition = load("res://items/seeds/wheat_seed.tres")
	var now: float = farm.time_manager.now()
	farm.restore_crop(crop_cell,seed.crop,now-100,now-1,1,now)
	var pen: AnimalPen = AnimalPen.new()
	field.add_child(pen)
	var animal: AnimalActor = preload("res://scenes/animals/chicken.tscn").instantiate() as AnimalActor
	pen.add_child(animal)
	animal.wander.set_physics_process(false)
	animal.behaviour.set_physics_process(false)
	animal.global_position = player.global_position + Vector2(0,25)
	controller.refresh()
	assert_eq(controller.focused.node,merchant)
	assert_eq(controller.presenter.outline.get_parent(),merchant.interaction_sprite())
	var only_outline: Sprite2D = controller.presenter.outline
	merchant.hide()
	merchant.collision_layer = 0
	controller.refresh()
	assert_eq(controller.focused.node,trough)
	assert_eq(controller.presenter.outline,only_outline)
	trough.hide()
	trough.collision_layer = 0
	controller.refresh()
	assert_eq(controller.focused.node,animal)
	animal.hide()
	controller.refresh()
	assert_eq(controller.focused.node,farm.get_crop(crop_cell))
	assert_eq(controller.presenter.outline,only_outline)

func test_e_requires_facing_and_obstacle_clearance_and_never_falls_back_to_trough() -> void:
	player.animation.face(Vector2.UP)
	controller.press()
	assert_false(merchant.menu.is_open)
	assert_eq(player.state.current_state,StateComponent.State.IDLE)
	player.animation.face(Vector2.DOWN)
	var wall: StaticBody2D = _wall(player.position + Vector2(0,8),Vector2(100,4))
	await wait_physics_frames(2)
	controller.refresh()
	assert_null(controller.focused)
	controller.press()
	assert_false(merchant.menu.is_open)
	assert_eq(trough.stock,450)
	wall.free()
	await wait_physics_frames(2)
	controller.press()
	assert_true(merchant.menu.is_open)
	assert_eq(trough.stock,450)

func test_badge_has_live_stock_and_auto_fill_without_selecting_feed() -> void:
	merchant.hide()
	player.selection.select_slot(0)
	var before: int = player.selection.inventory.count_item(trough.feed_item.item_id)
	controller.refresh()
	assert_string_contains(controller.presenter.label.text,"450/600")
	assert_true(controller.press())
	await wait_seconds(0.9)
	assert_eq(trough.stock,600)
	assert_eq(trough.feed_reserve,150)
	assert_eq(player.selection.selected_index,0)
	assert_eq(player.selection.inventory.count_item(trough.feed_item.item_id),before-1)
	controller.refresh()
	assert_string_contains(controller.presenter.label.text,"600/600")
	assert_false(player.state.trough_interaction.prompt.visible)
	var count: int = player.selection.inventory.count_item(trough.feed_item.item_id)
	controller.press()
	await wait_seconds(0.2)
	assert_eq(player.selection.inventory.count_item(trough.feed_item.item_id),count)

func test_e_water_finds_can_anywhere_in_bag_and_full_trough_blocks_lower_targets() -> void:
	merchant.hide()
	trough.kind = AnimalTrough.Kind.WATER
	trough.stock = 10
	player.selection.inventory.move_slot(1,12)
	player.selection.select_slot(0)
	controller.refresh()
	assert_eq(controller.focused.node,trough)
	controller.press()
	await wait_seconds(0.9)
	assert_eq(trough.stock,600)
	assert_eq(player.selection.inventory.count_item(&"watering_can"),1)
	controller.refresh()
	assert_string_contains(controller.presenter.label.text,"Trough is full")

func test_click_npc_navigates_around_collision_and_opens_only_at_arrival() -> void:
	trough.hide()
	merchant.position = player.position + Vector2(176,0)
	var wall: StaticBody2D = _wall(player.position + Vector2(70,0),Vector2(12,80))
	await wait_physics_frames(2)
	var point: Vector2 = merchant.interaction_sprite().global_position
	assert_true(controller.click(point))
	assert_not_null(controller.pending)
	assert_false(merchant.menu.is_open)
	await wait_seconds(4.0)
	assert_true(merchant.menu.is_open)
	assert_lte(player.position.distance_to(merchant.interaction_position()),48.0)
	assert_null(controller.pending)
	assert_eq(player.state.current_state,StateComponent.State.IDLE)
	wall.free()

func test_click_trough_remains_explicit_even_when_a_nearby_npc_has_e_priority() -> void:
	merchant.position = player.position + Vector2(0,-24)
	trough.position = player.position + Vector2(120,0)
	trough.stock = 595
	await wait_physics_frames(2)
	assert_true(controller.click(trough.sprite.global_position))
	await wait_seconds(3.0)
	assert_false(merchant.menu.is_open)
	assert_eq(trough.stock,600)
	assert_eq(trough.feed_reserve,295)

func test_new_focus_keyboard_and_deleted_target_cancel_queued_interaction() -> void:
	trough.hide()
	merchant.position = player.position + Vector2(160,0)
	assert_true(controller.click(merchant.interaction_sprite().global_position))
	player.state.navigation.request_focus(player.position + Vector2(-32,0))
	assert_null(controller.pending)
	await wait_seconds(0.8)
	assert_false(merchant.menu.is_open)
	assert_true(controller.click(merchant.interaction_sprite().global_position))
	Input.action_press(&"move_left")
	await wait_physics_frames(2)
	Input.action_release(&"move_left")
	assert_null(controller.pending)
	assert_true(controller.click(merchant.interaction_sprite().global_position))
	merchant.queue_free()
	await wait_physics_frames(3)
	assert_null(controller.pending)
	assert_false(player.selection.is_menu_open())

func test_unreachable_click_does_not_open_or_harvest() -> void:
	trough.hide()
	merchant.position = player.position + Vector2(160,0)
	for offset: Vector2 in [Vector2(0,-48),Vector2(0,48),Vector2(-48,0),Vector2(48,0)]:
		_wall(merchant.position+offset,Vector2(100,12) if offset.x == 0 else Vector2(12,100))
	await wait_physics_frames(2)
	assert_true(controller.click(merchant.interaction_sprite().global_position))
	await wait_seconds(5.0)
	assert_false(merchant.menu.is_open)
	assert_eq(trough.stock,450)

func test_land_price_badge_translation_and_confirm_only_debits() -> void:
	var world: FarmWorld = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	add_child_autofree(world)
	world.player.position = world.land.interaction_position() + Vector2(0,20)
	world.player.animation.face(Vector2.UP)
	world.player.wallet.set_balance(20000)
	world.player.interactions.refresh()
	assert_eq(world.player.interactions.focused.node,world.land)
	assert_string_contains(world.player.interactions.presenter.label.text,"15,000")
	Language.set_language("vi")
	world.player.interactions.refresh()
	assert_string_contains(world.player.interactions.presenter.label.text,"15.000")
	assert_true(world.player.interactions.press())
	assert_true(world.land.menu.is_open)
	assert_eq(world.player.wallet.balance,20000)
	world.land.menu.close()
	assert_eq(world.land.state.unlocked_columns,1)

func _wall(point: Vector2, size: Vector2) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.position = point
	body.add_child(collision)
	field.add_child(body)
	return body

func test_click_mature_crop_walks_then_harvests_once_and_empty_ground_only_focuses() -> void:
	merchant.free()
	trough.free()
	var crop_cell: Vector2i = Vector2i(28,22)
	FIXTURE.mark_cell(field,crop_cell)
	var seed: ItemDefinition = load("res://items/seeds/wheat_seed.tres")
	var now: float = farm.time_manager.now()
	farm.restore_crop(crop_cell,seed.crop,now-100,now-1,1,now)
	var crop: Crop = farm.get_crop(crop_cell)
	var reward: ItemDefinition = crop.definition.harvest_item
	var quantity: int = crop.definition.harvest_amount
	var before: int = player.selection.inventory.count_item(reward.item_id)
	var target: InteractionTarget = InteractionTarget.new(crop,InteractionTarget.Kind.CROP,player)
	var point: Vector2 = crop.sprite.to_global(controller.resolver.visual_rect(target).get_center())
	assert_true(controller.click(point))
	await wait_seconds(3.0)
	assert_null(farm.get_crop(crop_cell))
	assert_eq(player.selection.inventory.count_item(reward.item_id),before+quantity)
	assert_eq(player.state.current_state,StateComponent.State.IDLE)
	assert_null(controller.pending)
	var empty: Vector2 = player.global_position + Vector2(64,0)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = player.get_canvas_transform() * empty
	player.state._unhandled_input(event)
	assert_null(controller.pending)
	assert_eq(player.state.navigation.focus_position,empty)
	await wait_seconds(1.5)
	assert_eq(player.selection.inventory.count_item(reward.item_id),before+quantity)
