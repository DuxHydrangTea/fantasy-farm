extends Node2D
## Native visual/input QA. World is a child, never the personal-save scene.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const SEED: ItemDefinition = preload("res://items/seeds/carrot_seed.tres")
var world: FarmWorld
var _checks: int = 0
var _failures: Array[String] = []
var _output: String

class MemoryRepository extends SaveRepository:
	var snapshot: Dictionary = {}
	func read_profile(_profile: String) -> Dictionary:
		return {"ok": true, "found": not snapshot.is_empty(), "snapshot": snapshot.duplicate(true), "revision": snapshot.get("revision", 0)}
	func write_profile(_profile: String, data: Dictionary, _expected: int) -> Dictionary:
		snapshot = data.duplicate(true)
		return {"ok": true, "revision": data.revision}

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
	await _frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_output + "/" + name + ".png")

func _click(button: Button) -> void:
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

func _use() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"use_item"
	event.pressed = true
	get_viewport().push_input(event, true)
	await _frames(1)
	event.pressed = false
	get_viewport().push_input(event, true)
	await _frames(80)

func _touch(id: int, point: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = id
	event.position = point
	event.pressed = pressed
	get_viewport().push_input(event, true)

func _run() -> void:
	Language.set_language("vi")
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	var save: GameSaveManager = GameSaveManager.new()
	add_child(save)
	var repository: MemoryRepository = MemoryRepository.new()
	_check((await save.bind_world(world, repository, "tool_full_qa")).ok, "Isolated fresh profile loads")
	world.objectives.progress.suspended = true
	world.player.wallet.set_balance(1000000)
	world.land.state.restore_columns(7, 4)
	world.weather.set_weather(WeatherManager.Weather.SUNNY)
	world.weather.set_debug_hour(12)
	var merchant: ShopMerchant
	for node: Node in get_tree().get_nodes_in_group(&"shop_merchants"):
		if world.is_ancestor_of(node):
			merchant = node as ShopMerchant
			break
	world.player.global_position = merchant.interaction_position() + Vector2(0, 24)
	world.player.camera.position_smoothing_enabled = false
	world.player.camera.force_update_scroll()
	_check(merchant.open_shop(world.player), "Existing NPC opens its real shop")
	var shop: ShopUI = merchant.shop_ui
	await _frames()
	await _click(shop.categories.get_child(ShopUI.UPGRADES) as Button)
	_check(shop.category == ShopUI.UPGRADES and shop.grid.get_child_count() == 3, "Actual GUI click opens three upgrade cards")
	await _capture("desktop-upgrades")
	for tool: StringName in ToolUpgradeState.TOOLS:
		await _click(shop._buttons[tool] as Button)
		await _click(shop.buy_button)
		_check(world.tool_upgrade_state.level(tool) == 2, "GUI purchase level 2 " + String(tool))
		await _click(shop.buy_button)
		_check(world.tool_upgrade_state.level(tool) == 3, "GUI purchase level 3 " + String(tool))
	_check(world.player.wallet.balance == 600000, "All six upgrades debit exactly 400000 coins")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_R
	key.pressed = true
	get_viewport().push_input(key, true)
	key.pressed = false
	get_viewport().push_input(key, true)
	_check(world.tool_upgrade_state.selected_size(&"hoe") == 3, "Range hotkey is blocked by the NPC modal")
	await _click(shop.close_button)
	_check(not world.player.selection.shop_open, "Close restores gameplay input")
	var origin: Vector2i = Vector2i.ZERO
	for x: int in range(51, 55):
		for y: int in range(22, 45):
			var candidate: Vector2i = Vector2i(x, y)
			var ready: bool = true
			for row: Dictionary in FarmingAreaPolicy.evaluate(world.farming, &"tool", FarmingAreaPolicy.cells(candidate, Vector2i.DOWN, 3), null, -1, world.player):
				ready = ready and row.ready
			if ready:
				origin = candidate
				break
		if origin != Vector2i.ZERO:
			break
	_check(origin != Vector2i.ZERO, "Real farm has a valid 3x3 patch")
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(origin))
	world.player.animation.face(Vector2.DOWN)
	world.player.camera.zoom = Vector2.ONE * 2
	world.player.camera.force_update_scroll()
	world.player.selection.select_slot(0)
	await _frames()
	await _capture("desktop-area-3x3")
	await _use()
	_check(world.player.farming_actions.last_result.get("changed", 0) == 9, "Real animation tills nine cells")
	world.player.selection.select_slot(1)
	await _use()
	_check(world.player.farming_actions.last_result.get("changed", 0) == 9, "Real animation waters nine cells")
	var bag: InventoryComponent = world.player.selection.inventory
	bag.remove(SEED.item_id, bag.count_item(SEED.item_id))
	bag.add(SEED, 5)
	var seed_slot: int = -1
	for i: int in range(bag.slot_count):
		if bag.slot(i).item == SEED:
			seed_slot = i
	world.player.selection.select_slot(seed_slot)
	await _frames()
	_check(world.player.farming_actions.last_preview.filter(func(row: Dictionary) -> bool: return row.ready).size() == 5, "Preview limits the sowing plan to five seeds")
	await _capture("desktop-five-seeds")
	await _use()
	_check(world.player.farming_actions.last_result.get("seed_spent", 0) == 5 and world.farming.crop_cells().size() == 5, "One animation plants exactly five crops")
	world.player.selection.select_slot(0)
	await _frames()
	key.pressed = true
	get_viewport().push_input(key, true)
	key.pressed = false
	get_viewport().push_input(key, true)
	_check(world.tool_upgrade_state.selected_size(&"hoe") == 1, "Physical R key cycles the selected area")
	await _click(world.player.tool_range_ui.button)
	_check(world.tool_upgrade_state.selected_size(&"hoe") == 2, "HUD cycles 3x3 to 1x1 to 2x2")
	_check((await save.save_game()).ok, "Upgrades and crops save together")
	var saved_progress: Dictionary = repository.snapshot.tool_upgrades.duplicate(true)
	var saved_coins: int = world.player.wallet.balance
	world.tool_upgrade_state.restore(ToolUpgradeState.fresh())
	world.player.wallet.set_balance(0)
	_check((await save.load_game()).ok, "Saved profile reloads")
	_check(world.tool_upgrade_state.capture() == saved_progress and world.player.wallet.balance == saved_coins and world.farming.crop_cells().size() == 5, "Reload preserves levels, chosen areas, coins and crops")
	get_tree().root.size = Vector2i(844, 390)
	get_viewport().set_meta(&"touch_layout", true)
	get_viewport().set_meta(&"ui_point_scale", 1.0)
	await _frames(8)
	var controls: MobileControls = world.player.mobile_controls
	world.player.tool_range_ui._process(0.0)
	var selector: Button = world.player.tool_range_ui.button
	var before: int = world.tool_upgrade_state.selected_size(&"hoe")
	var joystick: Vector2 = controls.joystick.get_global_transform_with_canvas() * (controls.joystick.size * 0.5)
	var area_button: Vector2 = selector.get_global_transform_with_canvas() * (selector.size * 0.5)
	_touch(0, joystick, true)
	_touch(1, area_button, true)
	_touch(1, area_button, false)
	_touch(0, joystick, false)
	await _frames()
	_check(world.tool_upgrade_state.selected_size(&"hoe") == before % 3 + 1, "Second finger changes range exactly once while joystick is held")
	_check(Rect2(Vector2.ZERO, Vector2(844, 390)).encloses(selector.get_global_rect()), "Touch area selector fits landscape viewport")
	await _capture("touch-area")
	var touch_uses: Array[int] = [0]
	world.player.state.state_changed.connect(func(_previous: StringName, current: StringName) -> void:
		if current == &"tool":
			touch_uses[0] += 1)
	var use_button: Vector2 = controls.tool_button.get_global_transform_with_canvas() * (controls.tool_button.size * 0.5)
	_touch(0, use_button, true)
	_touch(0, use_button, false)
	await _frames(80)
	_check(touch_uses[0] == 1, "Touch Use starts exactly one real tool animation")
	world.player.global_position = merchant.interaction_position() + Vector2(0, 24)
	_check(merchant.open_shop(world.player), "NPC shop opens in touch layout")
	shop.show_category(ShopUI.UPGRADES)
	await _frames(8)
	_check(Rect2(Vector2.ZERO, Vector2(844, 390)).encloses(shop.panel.get_global_rect()), "Upgrade panel fits phone landscape")
	await _capture("touch-upgrades")
	shop.browse.scroll_vertical = 99999
	await _frames()
	_check(shop.browse.get_global_rect().grow(1).encloses((shop._buttons[&"sowing"] as Button).get_global_rect()), "The third upgrade card is reachable by scrolling on phone layout")
	await _capture("touch-upgrades-scroll")
	shop.close(false)
	world.objectives.progress.suspended = true
	var timings: Dictionary = {"till": [], "water": [], "plant": []}
	var targets: Array[Vector2i] = FarmingAreaPolicy.cells(origin, Vector2i.DOWN, 3)
	for iteration: int in range(32):
		world.farming.restore_soil([])
		var began: int = Time.get_ticks_usec()
		world.farming.apply_area(&"tool", targets, null, -1, null, world.player)
		if iteration >= 2:
			timings.till.append(float(Time.get_ticks_usec() - began) / 1000.0)
		began = Time.get_ticks_usec()
		world.farming.apply_area(&"water", targets, null, -1, null, world.player)
		if iteration >= 2:
			timings.water.append(float(Time.get_ticks_usec() - began) / 1000.0)
		bag.add(SEED, 9)
		seed_slot = -1
		for i: int in range(bag.slot_count):
			if bag.slot(i).item == SEED:
				seed_slot = i
		began = Time.get_ticks_usec()
		world.farming.apply_area(&"plant", targets, bag, seed_slot, SEED, world.player)
		if iteration >= 2:
			timings.plant.append(float(Time.get_ticks_usec() - began) / 1000.0)
		await _frames(1)
	var durations: Dictionary = {}
	var frames: SpriteFrames = world.player.animation.animated_sprite.sprite_frames
	for clip: StringName in [&"tool_down", &"water_down"]:
		var duration: float = 0.0
		for i: int in range(frames.get_frame_count(clip)):
			duration += frames.get_frame_duration(clip, i) / frames.get_animation_speed(clip)
		durations[String(clip)] = duration
	var report: Dictionary = {"checks": _checks, "failures": _failures, "renderer": RenderingServer.get_current_rendering_method(), "engine": Engine.get_version_info().string, "animation_seconds": durations,
		"commit_cpu_ms": timings, "max_area": 9, "all_upgrade_cost": 400000, "land_gates": [1, 3], "personal_save_used": false, "phone_hardware_tested": false}
	var file: FileAccess = FileAccess.open(_output + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("TOOL_UPGRADES_QA=" + JSON.stringify({"checks": _checks, "failures": _failures}))
	world.free()
	get_tree().quit(0 if _failures.is_empty() else 1)
