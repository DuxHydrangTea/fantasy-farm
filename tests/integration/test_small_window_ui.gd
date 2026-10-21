extends GutTest
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
const MERCHANT: PackedScene = preload("res://scenes/characters/shop_merchant.tscn")
var viewport: SubViewport
var player: FarmPlayer
var merchant: ShopMerchant

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(500, 281)
	viewport.size_2d_override = Vector2i(1920, 1080)
	viewport.size_2d_override_stretch = true
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	player = PLAYER.instantiate() as FarmPlayer
	viewport.add_child(player)
	merchant = MERCHANT.instantiate() as ShopMerchant
	merchant.position = Vector2(24, 0)
	viewport.add_child(merchant)
	await wait_process_frames(4)

func after_each() -> void:
	Language.set_language("en")
	await wait_process_frames(2)

func _pixels(control: Control) -> Rect2:
	return viewport.get_stretch_transform() * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(event, true)
	event.pressed = false
	event.button_mask = 0
	viewport.push_input(event, true)

func test_small_window_has_readable_scale_contained_menu_and_working_transformed_clicks() -> void:
	var camera_zoom: Vector2 = player.camera.zoom
	merchant.open_shop(player)
	var shop: ShopUI = merchant.shop_ui
	await wait_process_frames(5)
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size))
	assert_true(bounds.encloses(_pixels(shop.panel)), str(_pixels(shop.panel)))
	assert_gt(_pixels(shop.grid.get_child(0) as Control).size.x, 80.0, "A card must be readable at 500 pixels, rather than shrinking to 26 pixels")
	var physical_font: float = shop.buy_button.get_theme_font_size("font_size") * shop.buy_button.get_global_transform_with_canvas().get_scale().x * viewport.get_stretch_transform().get_scale().x
	assert_gte(physical_font, 16.0)
	assert_true(bounds.encloses(_pixels(shop.buy_button)))
	assert_true(bounds.encloses(_pixels(shop.close_button)))
	var chosen: ShopOffer = shop.selected
	_click(shop.buy_button)
	assert_eq(player.wallet.balance, 1000 - chosen.price)
	assert_eq(player.camera.zoom, camera_zoom, "Scaling menu UI never changes world zoom")
	_click(shop.close_button)
	assert_false(shop.is_open)
	assert_false(player.selection.is_menu_open())

func test_resize_and_language_keep_checkout_and_inventory_scrolls_inside_small_window() -> void:
	merchant.open_shop(player)
	var shop: ShopUI = merchant.shop_ui
	shop.show_category(ShopOffer.Category.FEED)
	var selected: ShopOffer = shop.selected
	shop.quantity.value = 3
	for size: Vector2i in [Vector2i(1000, 562), Vector2i(500, 281)]:
		viewport.size = size
		Language.set_language("vi" if size.x == 1000 else "en")
		await wait_process_frames(5)
		assert_eq(shop.selected, selected)
		assert_eq(shop.quantity.value, 3.0)
		assert_true(Rect2(Vector2.ZERO, Vector2(size)).encloses(_pixels(shop.panel)))
		assert_true(Rect2(Vector2.ZERO, Vector2(size)).encloses(_pixels(shop.buy_button)))
	assert_eq(player.wallet.balance, 1000)
	shop.close()
	var inventory: InventoryUI = player.get_node("InventoryUI") as InventoryUI
	inventory.open()
	await wait_process_frames(4)
	assert_true(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(_pixels(inventory.panel)))
	assert_gte(_pixels(inventory.buttons[0]).size.x, 32.0)
	var scroll: ScrollContainer = inventory.grid.get_parent().get_parent() as ScrollContainer
	scroll.scroll_vertical = 10000
	await wait_process_frames(3)
	assert_gt(scroll.scroll_vertical, 0, "All 64 slots remain reachable in the smaller panel")
	assert_true(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(_pixels(inventory.close_button as Control)))
