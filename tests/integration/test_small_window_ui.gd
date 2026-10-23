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

func test_inventory_button_and_balance_fit_and_click_in_both_languages() -> void:
	var hotbar: HotbarUI = player.get_node("Hotbar") as HotbarUI
	var inventory: InventoryUI = player.get_node("InventoryUI") as InventoryUI
	player.wallet.credit(999999000)
	for language: String in ["en", "vi"]:
		Language.set_language(language)
		for size: Vector2i in [Vector2i(500, 281), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			viewport.size = size
			await wait_process_frames(5)
			var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
			assert_true(bounds.encloses(_pixels(hotbar.inventory_button)))
			assert_gte(_pixels(hotbar.inventory_button).size.y, 40.0)
			assert_false(_pixels(hotbar.buttons[5]).intersects(_pixels(hotbar.inventory_button)))
			for slot: InventorySlot in hotbar.buttons:
				var count: Label = slot.get_node("Count") as Label
				if count.visible:
					assert_true(_pixels(slot).encloses(_pixels(count)), "Hotbar quantity stays inside its slot")
			_click(hotbar.inventory_button)
			await wait_process_frames(4)
			assert_true(inventory.root.visible)
			assert_false(hotbar.root.visible)
			assert_true(bounds.encloses(_pixels(inventory.panel)))
			assert_true(bounds.encloses(_pixels(inventory.wallet_label)))
			assert_false(_pixels(inventory.wallet_label).intersects(_pixels(inventory.capacity)))
			assert_true(bounds.encloses(_pixels(inventory.close_button as Control)))
			for slot: InventorySlot in inventory.buttons:
				var count: Label = slot.get_node("Count") as Label
				if count.visible:
					assert_true(_pixels(slot).encloses(_pixels(count)), "Inventory quantity stays inside its slot")
			_click(inventory.close_button as Control)
			await wait_process_frames(2)
			assert_false(inventory.root.visible)
			assert_true(hotbar.root.visible)
	assert_false(player.state.movement.has_target, "Bag clicks never move the player")

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

func test_hover_inspector_never_overlaps_weather_or_hotbar_after_resize_or_translation() -> void:
	var weather: WeatherManager = autofree(WeatherManager.new()) as WeatherManager
	var hud: WeatherHUD = WeatherHUD.new()
	hud.manager = weather
	viewport.add_child(hud)
	var pen: AnimalPen = AnimalPen.new()
	viewport.add_child(pen)
	var actor: AnimalActor = (load("res://scenes/animals/animal.tscn") as PackedScene).instantiate() as AnimalActor
	actor.definition = load("res://animals/definitions/chicken.tres") as AnimalDefinition
	actor.position = Vector2(600, 400)
	pen.add_child(actor)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	actor.growth.age_seconds = actor.growth.maturity_seconds * 0.5
	actor.needs.restore_state(0.0, 0.0, TimeManager.now())
	var context: ContextBarsComponent = player.context_bars
	context.set_physics_process(false)
	var sprite: Node2D = actor.get_status_sprite()
	context.refresh_at(sprite.to_global(context._sprite_bounds(sprite).get_center()))
	var info: AnimalInfoPanel = context.animal_info
	var panel: Control = info.title.get_parent().get_parent() as Control
	var hotbar: HotbarUI = player.get_node("Hotbar") as HotbarUI
	assert_eq(info.animal, actor, "Exercise the real hover path")
	for language: String in ["en", "vi"]:
		Language.set_language(language)
		for screen_size: Vector2i in [Vector2i(500, 281), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			viewport.size = screen_size
			for kind: int in range(4):
				weather.current_weather = kind as WeatherSchedule.Weather
				hud.refresh(TimeManager.now())
				await wait_process_frames(4)
				var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(screen_size))
				assert_true(info.root.visible)
				assert_true(bounds.encloses(_pixels(panel)))
				assert_true(bounds.encloses(_pixels(hud.label.get_parent() as Control)))
				assert_true(bounds.encloses(_pixels(hud.debug_bar)), "Debug controls stay inside the small window")
				assert_false(_pixels(panel).intersects(_pixels(hud.label.get_parent() as Control)), "Hover inspector and weather must have separate space")
				assert_false(_pixels(panel).intersects(_pixels(hud.debug_bar)), "Debug %s must not cover inspector %s" % [_pixels(hud.debug_bar), _pixels(panel)])
				assert_false(_pixels(panel).intersects(_pixels(hotbar.slots)), "Inspector stays above the tool dock")
