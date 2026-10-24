extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var orders: OrderService
var ui: OrderUI
var adapter: WorldStateAdapter

func before_each() -> void:
	world = WORLD.instantiate() as FarmWorld
	for child: Node in world.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	add_child_autofree(world)
	world.player.wallet.set_balance(1000)
	await wait_physics_frames(2)
	orders = world.orders.service
	ui = world.orders.menu
	adapter = WorldStateAdapter.new(world, SaveCatalog.new())
	world.player.global_position = world.orders.global_position + Vector2(0, 24)
	world.player.animation.face(Vector2.UP)

func after_each() -> void:
	Language.set_language("en")

func _serial() -> int:
	return int(orders.capture().slots[0].serial)

func _stock() -> void:
	var entry: OrderDefinition = orders.definition(_serial())
	for index: int in range(entry.items.size()):
		orders.inventory.add(entry.items[index], entry.amounts[index])

func test_board_is_separate_reachable_and_uses_shared_interaction_modal() -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(24, 6)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, world.orders.global_position)
	query.collision_mask = 1
	query.exclude = [world.orders.get_rid(), world.player.get_rid()]
	assert_true(world.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), "Board must not overlap existing collisions")
	var target: InteractionTarget = world.player.interactions.resolver.resolve()
	assert_not_null(target)
	if target == null:
		return
	assert_eq(target.node, world.orders)
	assert_eq(world.player.interactions.resolver.clicked(world.orders.sprite.global_position).node, world.orders)
	assert_true(world.player.interactions.execute(target))
	assert_true(ui.is_open)
	assert_true(world.player.selection.shop_open)
	world.objective_ui.open()
	assert_false(world.player.selection.objectives_open)
	world.player.selection.set_inventory_open(true)
	assert_false(world.player.selection.inventory_open)
	ui.close()
	assert_false(world.player.selection.is_menu_open())

func test_all_authored_templates_have_real_world_sources_and_missing_source_is_skipped() -> void:
	var availability: OrderAvailability = OrderAvailability.new(world)
	for entry: OrderDefinition in orders.catalog.entries:
		assert_true(availability.allows(entry), String(entry.order_id))
	var supplier: ShopMerchant = world.get_node("LaiBuon") as ShopMerchant
	var previous: ShopCatalog = supplier.catalog
	supplier.catalog = ShopCatalog.new()
	assert_false(availability.allows(orders.catalog.entries[0]))
	supplier.catalog = previous

func test_confirmation_cancel_inventory_change_double_click_and_localization() -> void:
	_stock()
	assert_true(world.orders.open_board(world.player))
	var before: Dictionary = orders.capture()
	ui.deliver_button.pressed.emit()
	assert_true(ui.confirmation.visible)
	assert_eq(orders.capture(), before)
	ui.cancel_button.pressed.emit()
	assert_false(ui.confirmation.visible)
	assert_eq(world.player.wallet.balance, 1000)
	ui.deliver_button.pressed.emit()
	var entry: OrderDefinition = orders.definition(_serial())
	orders.inventory.remove(entry.items[0].item_id, 1)
	assert_true(ui.confirm_button.disabled)
	ui.confirm_button.pressed.emit()
	assert_eq(world.player.wallet.balance, 1000)
	orders.inventory.add(entry.items[0], 1)
	ui.deliver_button.pressed.emit()
	Language.set_language("vi")
	await wait_process_frames(2)
	assert_eq(ui.confirm_button.text, "Xác nhận giao")
	ui.confirm_button.pressed.emit()
	ui.confirm_button.pressed.emit()
	assert_eq(world.player.wallet.balance, 101000)
	assert_eq(orders.capture().completed, 1)
	assert_eq(ui.status.text, "Đã giao đơn: +100000 xu")

func test_save_load_preserves_orders_and_closes_pending_confirmation() -> void:
	_stock()
	var serial: int = _serial()
	var now: float = TimeManager.now()
	var pending: Dictionary = adapter.capture("orders_test", 1, now)
	assert_true(orders.deliver(serial).ok)
	var claimed: Dictionary = adapter.capture("orders_test", 2, now)
	assert_true(world.orders.open_board(world.player))
	ui.abandon_button.pressed.emit()
	assert_true(ui.confirmation.visible)
	assert_true(adapter.restore(pending, now + 10000).ok)
	assert_false(ui.is_open)
	assert_false(ui.confirmation.visible)
	ui.confirm_button.pressed.emit()
	assert_eq(world.player.wallet.balance, 1000)
	assert_eq(orders.capture(), pending.orders)
	assert_true(adapter.restore(claimed, now + 10000).ok)
	assert_false(orders.deliver(serial).ok)
	assert_eq(world.player.wallet.balance, 101000)
	assert_eq(orders.capture(), claimed.orders)

func test_legacy_v13_migration_and_corrupt_order_preflight_are_pure() -> void:
	var now: float = TimeManager.now()
	var snapshot: Dictionary = adapter.capture("orders_test", 1, now)
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.version = 13
	legacy.erase("orders")
	var checked: Dictionary = SaveSchema.validate(legacy, SaveCatalog.new())
	assert_true(checked.ok)
	assert_false(legacy.has("orders"))
	assert_true(adapter.restore(legacy, now).ok)
	assert_eq(orders.capture().slots.size(), 3)
	assert_false(orders.capture().slots[0].is_empty())
	var bad: Dictionary = snapshot.duplicate(true)
	bad.orders.slots[0].serial = 1.5
	var before: Dictionary = orders.capture()
	assert_false(adapter.restore(bad, now).ok)
	assert_eq(orders.capture(), before)
	assert_eq(world.player.wallet.balance, 1000)
	bad = snapshot.duplicate(true)
	bad.erase("orders")
	assert_false(SaveSchema.validate(bad, SaveCatalog.new()).ok)

func test_sell_all_warns_but_does_not_fulfill_orders() -> void:
	_stock()
	var buyer: ShopMerchant = world.get_node("ProduceBuyer") as ShopMerchant
	var sales: ProduceSalesUI = buyer.menu as ProduceSalesUI
	var before: Dictionary = orders.capture()
	assert_true(sales.open(buyer, world.player))
	assert_true(sales.status.text.contains("Sell all also sells items"))
	sales.sell_quantity()
	assert_true(sales.status.text.contains("Sell all also sells items"), "Warning remains after a partial sale")
	sales.sell_all()
	assert_eq(orders.capture(), before)
	assert_false(orders.quote(_serial()).ok)
	sales.close()

func test_order_and_confirmation_safe_area_in_en_vi_at_density_one_and_three() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.set_meta(&"touch_layout", true)
	viewport.size_2d_override_stretch = true
	viewport.size = Vector2i(844, 390)
	viewport.size_2d_override = Vector2i(2337, 1080)
	add_child_autofree(viewport)
	var farm: FarmWorld = WORLD.instantiate() as FarmWorld
	for child: Node in farm.get_children():
		if String(child.name).begins_with("TreeScatter"):
			child.free()
	viewport.add_child(farm)
	farm.player.global_position = farm.orders.global_position + Vector2(0, 24)
	var page: OrderUI = farm.orders.menu
	for language: String in ["en", "vi"]:
		Language.set_language(language)
		for density: int in [1, 3]:
			for points: Vector2i in [Vector2i(667, 375), Vector2i(740, 360), Vector2i(844, 390)]:
				viewport.set_meta(&"safe_insets", Vector4(44, 0, 44, 21))
				viewport.set_meta(&"ui_point_scale", float(density))
				viewport.size = points * density
				viewport.size_2d_override = Vector2i(roundi(float(points.x) * 1080 / points.y), 1080)
				await wait_seconds(0.15)
				assert_true(farm.orders.open_board(farm.player))
				await wait_process_frames(3)
				var safe: Rect2 = Rect2(Vector2(44, 0) * density, (Vector2(points) - Vector2(88, 21)) * density)
				_assert_layout(viewport, page, safe, density, [page.deliver_button, page.abandon_button, page.close_button, page.rows[0], page.refill_button])
				page.abandon_button.pressed.emit()
				await wait_process_frames(3)
				_assert_layout(viewport, page, safe, density, [page.confirm_button, page.cancel_button])
				page.close()

func _assert_layout(viewport: SubViewport, page: OrderUI, safe: Rect2, density: int, buttons: Array) -> void:
	var pixels: Rect2 = viewport.get_stretch_transform() * page.panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, page.panel.size)
	assert_true(safe.grow(1).encloses(pixels), str(pixels))
	for button: Button in buttons:
		pixels = viewport.get_stretch_transform() * button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
		assert_gte(pixels.size.y / density, 47.9)
		assert_true(safe.grow(1).encloses(pixels), str(pixels))
