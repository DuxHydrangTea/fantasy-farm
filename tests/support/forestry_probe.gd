extends Node2D
## Native visual/input QA. World is a child, never the personal-save scene.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
const OTHER: ItemDefinition = preload("res://items/seeds/radish_seed.tres")
const FERTILIZER: ItemDefinition = preload("res://items/boosters/crop_fertilizer.tres")
var world: FarmWorld
var _checks: int = 0
var _failures: Array[String] = []
var _output: String

func _ready() -> void:
	_output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_output)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_size = Vector2i.ZERO
	get_tree().root.size = Vector2i(1280, 720)
	Engine.max_fps = 60
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error(label)

func _frames(count: int = 3) -> void:
	for i: int in range(count):
		await get_tree().process_frame

func _capture(name: String) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = get_viewport().get_visible_rect().size - Vector2(2, 2)
	motion.global_position = motion.position
	get_viewport().push_input(motion, true)
	await _frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output + "/" + name + ".png")

func _click(button: BaseButton) -> void:
	if button.get_parent().get_parent() is ScrollContainer:
		(button.get_parent().get_parent() as ScrollContainer).ensure_control_visible(button)
		await _frames(5)
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await _frames(1)
	event.pressed = false
	get_viewport().push_input(event, true)
	await _frames()

func _touch(id: int, point: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = id
	event.position = point
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _run() -> void:
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	await _frames(10)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(13, 4)
	world.player.wallet.set_balance(1000000)
	world.trees.reset()
	var merchant: ShopMerchant
	for node: Node in get_tree().get_nodes_in_group(&"shop_merchants"):
		if world.is_ancestor_of(node) and node is ShopMerchant and node.menu is ShopUI:
			merchant = node as ShopMerchant
			break
	world.player.global_position = merchant.interaction_position() + Vector2(0, 24)
	await _frames(5)
	_check(merchant.open_shop(world.player), "Existing supply merchant opens")
	var shop: ShopUI = merchant.menu as ShopUI
	shop.show_category(ShopOffer.Category.FEED)
	var offer: ShopOffer
	for candidate: ShopOffer in merchant.catalog.offers:
		if candidate.item.item_id == WoodMarket.ITEM:
			offer = candidate
	_check(offer != null and offer.price == 63, "Wood listed at 63 coins")
	shop.select_offer(offer)
	shop.quantity.value = 12
	shop._refresh()
	await _frames(5)
	await _click(shop.buy_button)
	_check(world.wood_market.used(world.farming.time_manager.now()) == 12, "GUI buys twelve wood")
	_check(shop.details.text.contains("12/30"), "Daily counter visible")
	await _capture("wood-shop-desktop")
	shop.quantity.value = 18
	shop._refresh()
	await _click(shop.buy_button)
	_check(world.player.selection.inventory.count_item(&"wood") == 30, "Second purchase reaches exact cap")
	shop.quantity.value = 1
	shop._refresh()
	_check(shop.buy_button.disabled, "Daily cap disables next purchase")
	shop.close(false)
	var access: FarmStorageAccess = world.storage_accesses.produce_warehouse
	world.player.global_position = access.global_position
	_check(world.storages.transfer("produce_warehouse", world.player.selection.inventory, &"wood", 12, true).ok, "Wood stored in Warehouse")
	world.player.global_position = merchant.interaction_position() + Vector2(0, 24)
	_check(merchant.open_shop(world.player), "Merchant reopens")
	shop.show_category(ShopUI.UPGRADES)
	await _frames(5)
	await _click(shop.buy_button)
	_check(world.tool_upgrade_state.level(&"hoe") == 2, "2x2 upgrade still coin only")
	_check(shop.details.text.contains("10"), "3x3 preview includes ten wood")
	await _click(shop.buy_button)
	_check(world.tool_upgrade_state.level(&"hoe") == 3, "GUI buys 3x3 using wood")
	_check(world.storages.inventory("produce_warehouse").count_item(&"wood") == 2, "Upgrade takes Warehouse wood first")
	_check(world.player.selection.inventory.count_item(&"wood") == 18, "Bag wood preserved when Warehouse suffices")
	await _capture("wood-upgrades-desktop")
	get_tree().root.size = Vector2i(844, 390)
	get_viewport().set_meta("touch_ui_override", true)
	await _frames(15)
	_check(Rect2(Vector2.ZERO, shop.root.size).encloses(shop.panel.get_rect()), "Upgrade menu fits touch")
	await _capture("wood-upgrades-touch")
	shop.show_category(ShopOffer.Category.FEED)
	shop.select_offer(offer)
	await _frames(10)
	_check(shop.details.text.contains("30/30"), "Daily limit survives reopening")
	await _capture("wood-shop-touch")
	shop.close(false)
	get_tree().root.size = Vector2i(1280, 720)
	get_viewport().set_meta("touch_ui_override", false)
	var now: float = world.farming.time_manager.now()
	var definition: TreeDefinition = world.trees.definitions[&"oak"]
	var first: TimberTree = world.trees.create_tree(Vector2i(68, 61), definition, now - definition.growth_seconds) as TimberTree
	var second: TimberTree = world.trees.create_tree(Vector2i(71, 61), definition, now - definition.growth_seconds) as TimberTree
	var young: TimberTree = world.trees.create_tree(Vector2i(68, 64), definition, now) as TimberTree
	var bag: InventoryComponent = world.player.selection.inventory
	for tree: TimberTree in [first, second]:
		tree.refresh(now)
		for i: int in range(definition.chop_hits):
			tree.chop(bag)
	var progress: Dictionary = world.tool_upgrade_state.capture()
	progress.hoe = {"level": 6, "selected_size": 6}
	world.tool_upgrade_state.restore(progress)
	world.player.selection.select_slot(0)
	world.player.animation.facing_direction = &"down"
	var anchor: Vector2i = world.farming.world_to_cell(first.global_position)
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(anchor + Vector2i(1, -1)))
	world.player.camera.zoom = Vector2(3, 3)
	world.player.camera.position = Vector2(0, 35)
	world.player.camera.reset_smoothing()
	await _frames(10)
	var ready: int = 0
	for row: Dictionary in world.player.farming_actions.preview():
		ready += 1 if row.ready else 0
	_check(ready == 3, "6x6 preview includes staggered stumps and sapling")
	await _capture("stumps-preview")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	get_viewport().push_input(key, true)
	await _frames(1)
	key.pressed = false
	get_viewport().push_input(key, true)
	await _frames(90)
	_check(world.trees.trees.is_empty(), "One real hoe animation clears all three targets")
	_check(bag.count_item(&"root_wood") == 4, "Only two mature stumps award roots")
	_check(bag.count_item(definition.planting_item().item_id) == 3, "Young tree refunds one sapling")
	_check(bag.count_item(&"wood") == 18 + 800, "Chopping yields unchanged, digging no extra wood")
	await _capture("stumps-cleared")
	var adapter: WorldStateAdapter = WorldStateAdapter.new(world, SaveCatalog.new())
	var timestamp: float = world.farming.time_manager.now()
	var snapshot: Dictionary = adapter.capture("forestry_qa", 1, timestamp)
	_check(SaveSchema.validate(snapshot, adapter.catalog).ok, "v29 snapshot validates")
	_check(adapter.restore(snapshot, timestamp).ok, "v29 restores")
	_check(world.wood_market.used(timestamp) == 30, "Reload preserves exhausted daily stock")
	_check(world.player.selection.inventory.count_item(&"root_wood") == 4, "Reload preserves root rewards")
	var report: Dictionary = {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "personal_save_used": false}
	var file: FileAccess = FileAccess.open(_output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _touch_click(button: BaseButton) -> void:
	if button.get_parent().get_parent() is ScrollContainer:
		(button.get_parent().get_parent() as ScrollContainer).ensure_control_visible(button)
		await _frames(5)
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	_touch(0, point, true)
	await _frames(1)
	_touch(0, point, false)
	await _frames(5)
