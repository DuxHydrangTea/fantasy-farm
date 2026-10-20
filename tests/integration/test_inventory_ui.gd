extends GutTest
const PLAYER: PackedScene = preload("res://scenes/characters/player.tscn")
var viewport: SubViewport
var player: CharacterBody2D
var ui: CanvasLayer
var state: StateComponent
var bag: InventoryComponent

class ShortcutProbe extends Node:
	var received: bool = false
	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.physical_keycode == KEY_F5 and event.is_pressed():
			received = true

func before_each() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	player = PLAYER.instantiate() as CharacterBody2D
	player.position = Vector2(960, 540)
	viewport.add_child(player)
	ui = player.get_node("InventoryUI")
	state = player.get_node("StateComponent")
	bag = state.tool_selection.inventory
	await wait_physics_frames(3)

func after_each() -> void:
	Input.action_release(&"move_right")

func _key(code: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	viewport.push_input(event, true)
	event.pressed = false
	viewport.push_input(event, true)

func _mouse(position: Vector2, button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	event.pressed = pressed
	viewport.push_input(event, true)

func test_inventory_opens_with_tab_or_i_and_closes_with_escape() -> void:
	assert_false(ui.root.visible)
	_key(KEY_TAB)
	assert_true(ui.root.visible)
	assert_true(state.tool_selection.inventory_open)
	assert_eq(ui.buttons.size(), InventoryComponent.DEFAULT_SLOT_COUNT)
	_key(KEY_ESCAPE)
	assert_false(ui.root.visible)
	_key(KEY_I)
	assert_true(ui.root.visible)
	_key(KEY_I)
	assert_false(ui.root.visible)

func test_inventory_toggle_uses_remapped_action_without_hardcoded_i() -> void:
	var original: Array[InputEvent] = InputMap.action_get_events(&"toggle_inventory")
	InputMap.action_erase_events(&"toggle_inventory")
	var replacement: InputEventKey = InputEventKey.new()
	replacement.physical_keycode = KEY_P
	InputMap.action_add_event(&"toggle_inventory", replacement)
	_key(KEY_I)
	assert_false(ui.root.visible)
	_key(KEY_P)
	assert_true(ui.root.visible)
	_key(KEY_P)
	assert_false(ui.root.visible)
	InputMap.action_erase_events(&"toggle_inventory")
	for event: InputEvent in original:
		InputMap.action_add_event(&"toggle_inventory", event)

func test_inventory_does_not_consume_unrelated_shortcuts() -> void:
	var probe: ShortcutProbe = ShortcutProbe.new()
	viewport.add_child(probe)
	ui.open()
	_key(KEY_F5)
	assert_true(probe.received, "An open inventory must not swallow save/debug shortcuts")

func test_modal_cancels_movement_and_blocks_world_input() -> void:
	state.movement.set_target(player.position + Vector2(100, 0))
	await wait_physics_frames(4)
	_key(KEY_TAB)
	var before: Vector2 = player.position
	assert_false(state.movement.has_target)
	Input.action_press(&"move_right")
	_mouse(Vector2(100, 100), MOUSE_BUTTON_LEFT, true)
	_mouse(Vector2(100, 100), MOUSE_BUTTON_LEFT, false)
	_mouse(Vector2(100, 100), MOUSE_BUTTON_RIGHT, true)
	_key(KEY_SPACE)
	_key(KEY_2)
	await wait_physics_frames(10)
	assert_eq(player.position, before)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	assert_eq(state.tool_selection.selected_index, 0)
	assert_false(state.use_selected_tool())
	Input.action_release(&"move_right")
	_key(KEY_ESCAPE)
	assert_true(state.use_selected_tool())

func test_opening_inventory_cancels_in_progress_tool_action() -> void:
	assert_true(state.use_selected_tool())
	ui.open()
	assert_eq(state.current_state, StateComponent.State.IDLE)
	await wait_seconds(0.8)
	assert_eq(state.current_state, StateComponent.State.IDLE)

func test_drag_drop_updates_shared_inventory_and_hotbar() -> void:
	ui.open()
	await wait_physics_frames(3)
	var source: Vector2 = ui.buttons[0].get_global_rect().get_center()
	var target: Vector2 = ui.buttons[6].get_global_rect().get_center()
	_mouse(source, MOUSE_BUTTON_LEFT, true)
	await wait_physics_frames(1)
	for position: Vector2 in [source + Vector2(12, 12), target]:
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = position
		motion.global_position = position
		motion.relative = position - source
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		viewport.push_input(motion, true)
		await wait_physics_frames(1)
	_mouse(target, MOUSE_BUTTON_LEFT, false)
	await wait_physics_frames(2)
	assert_null(bag.slot(0).item)
	assert_eq(bag.slot(6).item.item_id, &"hoe")
	assert_null(player.get_node("Hotbar").buttons[0].get_node("Icon").texture)
	assert_eq(state.get_selected_tool_action(), &"")
	assert_true(bag.move_slot(1, 0))
	assert_eq(state.get_selected_tool_action(), &"water")
	assert_eq(player.get_node("Hotbar").selected_name.text, "Bình tưới")

func test_quantity_labels_refresh_in_bag_and_hotbar() -> void:
	var seed: ItemDefinition = load("res://items/seeds/carrot_seed.tres") as ItemDefinition
	bag.remove(seed.item_id, bag.count_item(seed.item_id))
	bag.add(seed, 12)
	assert_eq(ui.buttons[2].get_node("Count").text, "12")
	assert_eq(player.get_node("Hotbar").buttons[2].get_node("Count").text, "12")
	bag.remove(seed.item_id, 11)
	assert_eq(ui.buttons[2].get_node("Count").text, "")

func test_invalid_drag_payload_cannot_move_or_duplicate_items() -> void:
	var target: Control = ui.buttons[6]
	assert_false(target._can_drop_data(Vector2.ZERO, {"inventory": bag, "slot": 99}))
	assert_false(target._can_drop_data(Vector2.ZERO, {"inventory": bag, "slot": 0, "item_id": &"wrong"}))
	assert_false(target._can_drop_data(Vector2.ZERO, {"inventory": null, "slot": 0, "item_id": &"hoe"}))
	assert_eq(bag.count_item(&"hoe"), 1)

func test_font_theme_uses_pixelify_sans() -> void:
	var font: FontVariation = ui.root.theme.default_font as FontVariation
	assert_not_null(font)
	assert_eq(font.base_font.resource_path, "res://assets/Fonts/Pixelify_Sans/PixelifySans.ttf")
	for character: String in ["T", "ú", "đ", "ồ", "ư", "ớ"]:
		var code: int = character.unicode_at(0)
		assert_true(font.base_font.has_char(code) or font.fallbacks[0].has_char(code), "Vietnamese glyph in the configured font chain: " + character)

func test_panel_fits_viewport(size = use_parameters([Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(640, 360)])) -> void:
	viewport.size = size
	ui.open()
	await wait_physics_frames(4)
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
	assert_true(bounds.encloses(ui.panel.get_global_rect()))
	assert_true(bounds.encloses(ui.details.get_global_rect()))
	var close_button: Control = ui.get_node("Root/Center/Panel/Body/Header/Close")
	assert_true(bounds.encloses(close_button.get_global_rect()))
