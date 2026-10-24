extends GutTest

const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const MERCHANT: PackedScene = preload("res://scenes/characters/shop_merchant.tscn")
const SALES: PackedScene = preload("res://scenes/ui/produce_sales.tscn")
var viewport: SubViewport
var player: FarmPlayer
var merchant: ShopMerchant

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.set_meta(&"touch_layout", true)
	viewport.size_2d_override_stretch = true
	_resize(Vector2i(844, 390), Vector4(44, 0, 44, 21))
	add_child_autofree(viewport)
	player = PLAYER.instantiate() as FarmPlayer
	viewport.add_child(player)
	merchant = MERCHANT.instantiate() as ShopMerchant
	viewport.add_child(merchant)
	await wait_process_frames(5)

func after_each() -> void:
	Language.set_language("en")

func _resize(points: Vector2i, insets: Vector4, density: int = 1) -> void:
	viewport.set_meta(&"safe_insets", insets)
	viewport.set_meta(&"ui_point_scale", float(density))
	viewport.size = points * density
	viewport.size_2d_override = Vector2i(roundi(float(points.x) * 1080.0 / points.y), 1080)

func _pixels(control: Control) -> Rect2:
	return viewport.get_stretch_transform() * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _click(control: Control) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_transform_with_canvas() * (control.size * 0.5)
	event.global_position = event.position
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(event, true)
	event.pressed = false
	event.button_mask = 0
	viewport.push_input(event, true)

func test_safe_area_and_touch_targets_survive_high_density_and_resize_in_both_languages() -> void:
	var inventory: InventoryUI = player.get_node("InventoryUI") as InventoryUI
	var hotbar: HotbarUI = player.get_node("Hotbar") as HotbarUI
	for language: String in ["en", "vi"]:
		Language.set_language(language)
		for density: int in [1, 3]:
			for size: Vector2i in [Vector2i(844, 390), Vector2i(667, 375), Vector2i(740, 360)]:
				var insets: Vector4 = Vector4(44, 0, 44, 21) if size.x == 844 else Vector4.ZERO
				if size.x == 740:
					insets = Vector4(20, 0, 20, 16)
				_resize(size, insets, density)
				await wait_seconds(0.15)
				var safe: Rect2 = Rect2(Vector2(insets.x, insets.y) * density, (Vector2(size) - Vector2(insets.x + insets.z, insets.y + insets.w)) * density)
				assert_true(safe.grow(1).encloses(_pixels(hotbar.slots)), str(_pixels(hotbar.slots)))
				for slot: InventorySlot in hotbar.buttons:
					assert_gte(_pixels(slot).size.x / density, 47.9)
					assert_false((slot.get_node("Shortcut") as Label).visible)
				assert_false(hotbar.inventory_button.text.contains("Tab"))
				inventory.open()
				await wait_process_frames(4)
				assert_true(safe.grow(1).encloses(_pixels(inventory.panel)), str(_pixels(inventory.panel)))
				assert_gte(_pixels(inventory.close_button as Control).size.y / density, 47.9)
				assert_gte(_pixels(inventory.buttons[0]).size.x / density, 47.9)
				_click(inventory.buttons[2])
				assert_eq(inventory.inspected_index, 2)
				assert_false(inventory.details.text.is_empty())
				_click(inventory.close_button as Control)
				assert_false(player.selection.is_menu_open())

func test_quantity_buttons_buy_exact_amount_and_preserve_selection_on_resize() -> void:
	merchant.open_shop(player)
	var shop: ShopUI = merchant.shop_ui
	await wait_process_frames(5)
	var controls: TouchQuantityComponent = shop.quantity.get_child(shop.quantity.get_child_count() - 1) as TouchQuantityComponent
	assert_not_null(controls)
	assert_true(controls.increase.visible)
	assert_false(shop.quantity.get_line_edit().virtual_keyboard_enabled)
	var selected: ShopOffer = shop.selected
	_click(controls.increase)
	assert_eq(shop.quantity.value, 2.0)
	assert_eq(player.wallet.balance, 1000)
	_resize(Vector2i(667, 375), Vector4.ZERO)
	Language.set_language("vi")
	await wait_process_frames(5)
	assert_eq(shop.selected, selected)
	assert_eq(shop.quantity.value, 2.0)
	assert_true(Rect2(Vector2.ZERO, Vector2(667, 375)).grow(1).encloses(_pixels(shop.panel)), str(_pixels(shop.panel)))
	assert_gte(_pixels(controls.increase).size.y, 47.9)
	assert_gte(_pixels(shop.buy_button).size.y, 47.9)
	_click(shop.buy_button)
	assert_eq(player.wallet.balance, 1000 - selected.price * 2)
	_click(shop.close_button)
	assert_false(player.selection.is_menu_open())

func test_touch_bag_moves_to_last_slot_without_drag_or_spending_items() -> void:
	var inventory: InventoryUI = player.get_node("InventoryUI") as InventoryUI
	inventory.open()
	await wait_process_frames(4)
	_click(inventory.buttons[0])
	var item: ItemDefinition = player.selection.inventory.get_slot_item(0)
	_click(inventory.move_button)
	var scroll: ScrollContainer = inventory.grid.get_parent().get_parent() as ScrollContainer
	scroll.scroll_vertical = 100000
	await wait_process_frames(4)
	assert_gt(scroll.scroll_vertical, 0)
	assert_true(Rect2(44, 0, 756, 369).grow(1).encloses(_pixels(inventory.buttons[63])))
	_click(inventory.buttons[63])
	assert_null(player.selection.inventory.get_slot_item(0))
	assert_eq(player.selection.inventory.get_slot_item(63), item)
	assert_eq(player.selection.inventory.count_item(item.item_id), 1)
	assert_eq(player.wallet.balance, 1000)
	_click(inventory.move_button)
	inventory.close()
	inventory.open()
	await wait_process_frames(4)
	scroll.scroll_vertical = 0
	await wait_process_frames(3)
	_click(inventory.buttons[1])
	assert_eq(player.selection.inventory.get_slot_item(63), item, "Closing the bag cancels destination mode")

func test_sales_checkout_and_land_confirmation_fit_safe_landscape_height() -> void:
	var sales: ProduceSalesUI = SALES.instantiate() as ProduceSalesUI
	viewport.add_child(sales)
	var produce: ProducePrice = sales.catalog.entries[0]
	player.selection.inventory.add(produce.item, 5)
	sales.open(merchant, player)
	await wait_process_frames(5)
	var safe: Rect2 = Rect2(44, 0, 756, 369)
	assert_true(safe.grow(1).encloses(_pixels(sales.panel)), str(_pixels(sales.panel)))
	assert_gte(_pixels(sales.sell_all_button).size.y, 47.9)
	assert_gte(_pixels(sales.sell_quantity_button).size.y, 47.9)
	assert_gte(sales.items.get_item_rect(0).size.y, 48.0)
	var controls: TouchQuantityComponent = sales.quantity.get_child(sales.quantity.get_child_count() - 1) as TouchQuantityComponent
	_click(controls.increase)
	assert_eq(sales.quantity.value, 2.0)
	_click(sales.sell_quantity_button)
	assert_eq(player.wallet.balance, 1000 + produce.price * 2)
	assert_eq(player.selection.inventory.count_item(produce.item.item_id), 3)
	_click(sales.close_button)
	var land: LandPurchaseUI = LandPurchaseUI.new()
	land.expansion = autofree(LandExpansionComponent.new()) as LandExpansionComponent
	viewport.add_child(land)
	land.open_offer(player)
	await wait_process_frames(4)
	assert_true(safe.grow(1).encloses(_pixels(land.panel)), str(_pixels(land.panel)))
	assert_gte(_pixels(land.close_button).size.y, 47.9)

func test_pen_dashboard_fits_short_vietnamese_screen() -> void:
	_resize(Vector2i(740, 360), Vector4(20, 0, 20, 16))
	Language.set_language("vi")
	var pen: AnimalPen = AnimalPen.new()
	viewport.add_child(pen)
	var board: PenBoard = autofree(PenBoard.new()) as PenBoard
	board.pen = pen
	var menu: PenDashboard = PenDashboard.new()
	menu.board = board
	viewport.add_child(menu)
	assert_true(menu.open(null, player))
	await wait_process_frames(5)
	assert_true(Rect2(20, 0, 700, 344).grow(1).encloses(_pixels(menu.panel)), str(_pixels(menu.panel), " root=", menu.root.size))
	assert_gte(_pixels(menu.close_button).size.y, 47.9)
	assert_true(menu.empty.visible)
