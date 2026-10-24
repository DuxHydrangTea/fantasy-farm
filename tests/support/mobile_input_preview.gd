extends Node
## Run against the isolated Web staging project with a display. Never binds a save.
var world: FarmWorld
var failures: Array[String] = []
var checks: int = 0
var root: Window
var _points: Dictionary[int, Vector2] = {}

func _ready() -> void:
	root = get_tree().root
	root.set_meta(&"touch_layout", true)
	root.set_meta(&"safe_insets", Vector4(44, 0, 44, 21))
	DisplayServer.window_set_size(Vector2i(844, 390))
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _physical(control: Control) -> Vector2:
	return root.get_stretch_transform() * control.get_global_transform_with_canvas() * (control.size * 0.5)

func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	if pressed:
		_points[index] = point
	else:
		_points.erase(index)
	Input.parse_input_event(event)
	await get_tree().process_frame

func _drag(index: int, point: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = point - _points.get(index, point)
	event.screen_relative = event.relative
	_points[index] = point
	Input.parse_input_event(event)
	await get_tree().process_frame

func _tap(control: Control) -> void:
	var point: Vector2 = _physical(control)
	await _touch(0, point, true)
	await _touch(0, point, false)
	await get_tree().create_timer(0.1).timeout

func _capture(label: String) -> void:
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../m2-" + label + ".png")

func _run() -> void:
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	add_child(world)
	world.weather.set_debug_hour(12)
	await get_tree().create_timer(0.5).timeout
	var player: FarmPlayer = world.player
	var controls: MobileControls = player.mobile_controls
	var bag: InventoryUI = player.get_node("InventoryUI") as InventoryUI
	var hotbar: HotbarUI = player.get_node("Hotbar") as HotbarUI
	# Input.parse_input_event exercises Godot's actual touch-to-mouse bridge.
	await _tap(hotbar.buttons[1])
	_check(player.selection.selected_index == 1, "Touch selects a hotbar slot through engine emulation")
	_check(not player.state.navigation.has_focus, "Touch hotbar must not navigate")
	await _tap(hotbar.inventory_button)
	_check(player.selection.inventory_open, "Touch Bag opens inventory without keyboard")
	await _capture("inventory-en")
	# A swipe beginning on a slot must scroll and must not select/move items.
	var scroll: ScrollContainer = bag.grid.get_parent().get_parent() as ScrollContainer
	var start: Vector2 = _physical(bag.buttons[1])
	var inspected: int = bag.inspected_index
	var original_scroll: int = scroll.scroll_vertical
	await _touch(0, start, true)
	for step: int in range(1, 9):
		await _drag(0, start - Vector2(0, step * 10))
	await _touch(0, start - Vector2(0, 80), false)
	_check(scroll.scroll_vertical > original_scroll, "Native touch swipe scrolls inventory")
	_check(bag.inspected_index == inspected, "Native swipe does not activate an inventory slot")
	await _tap(bag.close_button as Control)
	_check(not player.selection.inventory_open, "Touch closes inventory")
	_check(not player.state.navigation.has_focus, "Closing modal must not click through")
	# Context opens a real NPC shop, with quantity/buy/close using native touches.
	var merchant: ShopMerchant = world.get_node("LaiBuon") as ShopMerchant
	player.global_position = merchant.interaction_position() + Vector2(0, 20)
	player.animation.face(Vector2.UP)
	await get_tree().create_timer(0.15).timeout
	await _capture("controls-en")
	await _tap(controls.interact_button)
	_check(merchant.menu.is_open, "Touch context button opens shop")
	var shop: ShopUI = merchant.shop_ui
	var amount: TouchQuantityComponent = shop.quantity.get_child(shop.quantity.get_child_count() - 1) as TouchQuantityComponent
	var offer: ShopOffer = shop.selected
	var before: int = player.selection.inventory.count_item(offer.item.item_id)
	await _tap(amount.increase)
	_check(int(shop.quantity.value) == 2, "Touch quantity increases once")
	await _tap(shop.buy_button)
	_check(player.selection.inventory.count_item(offer.item.item_id) == before + 2, "Touch buys exactly two items")
	await _tap(shop.close_button as Control)
	var buyer: ShopMerchant = world.get_node("ProduceBuyer") as ShopMerchant
	player.global_position = buyer.interaction_position() + Vector2(0, 20)
	player.animation.face(Vector2.UP)
	var sales: ProduceSalesUI = buyer.menu as ProduceSalesUI
	var produce: ProducePrice = sales.catalog.entries[0]
	player.selection.inventory.add(produce.item, 5)
	await get_tree().create_timer(0.15).timeout
	await _tap(controls.interact_button)
	_check(sales.is_open, "Touch context button opens produce sales")
	await _tap(sales.sell_quantity_button)
	_check(player.selection.inventory.count_item(produce.item.item_id) == 4, "Touch sells one item exactly once")
	await _tap(sales.close_button as Control)
	# Land confirmation uses the same resolver and trade lock as desktop.
	player.wallet.set_balance(50000)
	player.global_position = world.land.interaction_position() + Vector2(0, 20)
	player.animation.face(Vector2.UP)
	await get_tree().create_timer(0.15).timeout
	await _tap(controls.interact_button)
	_check(world.land.menu.is_open, "Touch context button opens land confirmation")
	await _tap(world.land.menu.confirm)
	_check(world.land.state.unlocked_columns == 2, "Touch confirms one land column")
	_check(player.wallet.balance == 35000, "Touch land purchase charges exactly once")
	(root.get_node("Language") as GameLanguage).set_language("vi")
	await _capture("controls-vi")
	await _tap(hotbar.inventory_button)
	await _capture("inventory-vi")
	await _tap(bag.close_button as Control)
	var joy: Vector2 = _physical(controls.joystick)
	await _touch(2, joy, true)
	await _drag(2, joy + Vector2(32, 0))
	await get_tree().create_timer(0.1).timeout
	_check(player.state.touch_direction.x > 0.9, "Native joystick owns its finger")
	await _touch(3, _physical(controls.tool_button), true)
	await get_tree().create_timer(0.05).timeout
	_check(player.state.current_state in [StateComponent.State.TOOL, StateComponent.State.WATER], "Second native finger uses tool while joystick is held")
	await _touch(3, _physical(controls.tool_button), false)
	await _touch(2, joy + Vector2(32, 0), false)
	await get_tree().create_timer(0.9).timeout
	_check(player.state.touch_direction == Vector2.ZERO, "Native joystick releases")
	await _touch(2, joy, true)
	await _drag(2, joy + Vector2(32, 0))
	await _touch(3, _physical(hotbar.inventory_button), true)
	await _touch(3, _physical(hotbar.inventory_button), false)
	_check(player.selection.inventory_open, "Second native finger opens Bag while joystick is held")
	_check(player.state.touch_direction == Vector2.ZERO, "Opening Bag with second finger stops joystick")
	await _touch(2, joy + Vector2(32, 0), false)
	await _tap(bag.close_button as Control)
	var zoom_before: float = controls.zoom._target_zoom
	await _touch(0, Vector2(250, 80), true)
	await _touch(1, Vector2(350, 80), true)
	await _drag(1, Vector2(450, 80))
	await _touch(1, Vector2(450, 80), false)
	await _touch(0, Vector2(250, 80), false)
	_check(controls.zoom._target_zoom > zoom_before, "Native pinch changes zoom")
	_check(not player.state.navigation.has_focus, "Native pinch never clicks through to world")
	var result: Dictionary = {"ok": failures.is_empty(), "checks": checks, "failures": failures, "native_touch_emulation": Input.emulate_mouse_from_touch}
	var output: FileAccess = FileAccess.open("res://../m2-native-input.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print(JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
