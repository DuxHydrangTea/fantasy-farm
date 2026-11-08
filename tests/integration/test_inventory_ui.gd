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
	Language.set_language("en")
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
	state.tool_selection.select_slot(0)
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
	await wait_seconds(0.35)

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
	await _key(KEY_TAB)
	assert_true(ui.root.visible)
	assert_true(state.tool_selection.inventory_open)
	assert_eq(ui.buttons.size(), InventoryComponent.DEFAULT_SLOT_COUNT)
	await _key(KEY_ESCAPE)
	assert_false(ui.root.visible)
	await _key(KEY_I)
	assert_true(ui.root.visible)
	await _key(KEY_I)
	assert_false(ui.root.visible)

func test_24px_icon_uses_integer_scale_and_other_icons_keep_layout() -> void:
	var slot: InventorySlot = InventorySlot.new()
	slot.inventory = bag
	slot.slot_index = 0
	slot.compact = true
	viewport.add_child(slot)
	slot.custom_minimum_size = Vector2(48, 48)
	var icon: TextureRect = slot.get_node("Icon") as TextureRect
	icon.texture = load("res://assets/Icons/meowa/extracted_24px/batch_06/01_carrot.png") as Texture2D
	slot.size = Vector2(72, 72)
	slot._place_icon()
	assert_eq(icon.size, Vector2(48, 48), "A 24px icon fills a desktop slot at 2x")
	slot.size = Vector2(48, 48)
	slot._place_icon()
	assert_eq(icon.size, Vector2(24, 24), "A 24px icon fits a compact slot at 1x")
	slot.hotbar_skin = true
	slot.size = Vector2(64, 64)
	slot._place_icon()
	assert_eq(icon.size, Vector2(48, 48), "A desktop hotbar displays a 24px icon at 2x")
	assert_eq(icon.position, Vector2(8, 8), "The hotbar icon is centered")
	slot.size = Vector2(48, 48)
	slot._place_icon()
	assert_eq(icon.size, Vector2(24, 24), "A compact hotbar keeps integer scaling")
	slot.hotbar_skin = false
	icon.texture = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	slot._place_icon()
	assert_eq(icon.size, Vector2(28, 28), "Other icon sizes retain the existing layout")
	slot.queue_free()

func test_balance_is_inside_inventory_and_updates_without_reopening() -> void:
	var actor: FarmPlayer = player as FarmPlayer
	var hud: WalletHUD = actor.get_node("Hotbar/WalletHUD") as WalletHUD
	assert_not_null(hud)
	assert_false(ui.root.visible)
	actor.wallet.set_balance(1000) # Fixed baseline for this formatting/update test.
	actor.wallet.credit(98051604)
	ui.open()
	await wait_seconds(0.35)
	assert_false(hud.panel.visible, "The inventory balance replaces the HUD balance while open")
	assert_eq(ui.wallet_label.text, "98,052,604 coins")
	actor.wallet.credit(1)
	assert_eq(ui.wallet_label.text, "98,052,605 coins")
	ui.close()
	await wait_seconds(0.35)
	assert_false(ui.wallet_label.is_visible_in_tree())

func test_inventory_toggle_uses_remapped_action_without_hardcoded_i() -> void:
	var original: Array[InputEvent] = InputMap.action_get_events(&"toggle_inventory")
	InputMap.action_erase_events(&"toggle_inventory")
	var replacement: InputEventKey = InputEventKey.new()
	replacement.physical_keycode = KEY_P
	InputMap.action_add_event(&"toggle_inventory", replacement)
	await _key(KEY_I)
	assert_false(ui.root.visible)
	await _key(KEY_P)
	assert_true(ui.root.visible)
	await _key(KEY_P)
	assert_false(ui.root.visible)
	InputMap.action_erase_events(&"toggle_inventory")
	for event: InputEvent in original:
		InputMap.action_add_event(&"toggle_inventory", event)

func test_inventory_does_not_consume_unrelated_shortcuts() -> void:
	var probe: ShortcutProbe = ShortcutProbe.new()
	viewport.add_child(probe)
	ui.open()
	await wait_seconds(0.35)
	await _key(KEY_F5)
	assert_true(probe.received, "An open inventory must not swallow save/debug shortcuts")

func test_modal_cancels_movement_and_blocks_world_input() -> void:
	state.movement.set_target(player.position + Vector2(100, 0))
	await wait_physics_frames(4)
	await _key(KEY_TAB)
	var before: Vector2 = player.position
	assert_false(state.movement.has_target)
	Input.action_press(&"move_right")
	_mouse(Vector2(100, 100), MOUSE_BUTTON_LEFT, true)
	_mouse(Vector2(100, 100), MOUSE_BUTTON_LEFT, false)
	_mouse(Vector2(100, 100), MOUSE_BUTTON_RIGHT, true)
	await _key(KEY_SPACE)
	await _key(KEY_2)
	await wait_physics_frames(10)
	assert_eq(player.position, before)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	assert_eq(state.tool_selection.selected_index, 0)
	assert_false(state.use_selected_tool())
	Input.action_release(&"move_right")
	await _key(KEY_ESCAPE)
	assert_true(state.use_selected_tool())

func test_opening_inventory_cancels_in_progress_tool_action() -> void:
	assert_true(state.use_selected_tool())
	ui.open()
	await wait_seconds(0.35)
	assert_eq(state.current_state, StateComponent.State.IDLE)
	await wait_seconds(0.8)
	assert_eq(state.current_state, StateComponent.State.IDLE)

func test_drag_drop_updates_shared_inventory_and_hotbar() -> void:
	ui.open()
	await wait_seconds(0.35)
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
	assert_eq(player.get_node("Hotbar").selected_name.text, "Watering Can")

func test_quantity_labels_refresh_in_bag_and_hotbar() -> void:
	var seed: ItemDefinition = load("res://items/seeds/carrot_seed.tres") as ItemDefinition
	bag.remove(seed.item_id, bag.count_item(seed.item_id))
	bag.add(seed, 12)
	assert_eq(ui.buttons[2].get_node("Count").text, "12")
	assert_eq(player.get_node("Hotbar").buttons[2].get_node("Count").text, "12")
	bag.remove(seed.item_id, 11)
	assert_eq(ui.buttons[2].get_node("Count").text, "")

func test_assign_from_bag_to_hotbar_swaps_without_losing_items() -> void:
	var source_item: ItemDefinition = bag.get_slot_item(0)
	var target_item: ItemDefinition = bag.get_slot_item(1)
	assert_true(bag.move_slot(0, 8))
	ui.open()
	await wait_seconds(0.35)
	ui._inspect_slot(8)
	ui.assign_button.pressed.emit()
	assert_true(ui._assigning_hotbar)
	ui._inspect_slot(9)
	assert_eq(bag.get_slot_item(8), source_item, "Only a hotbar cell can complete assignment")
	await _key(KEY_2)
	assert_eq(bag.get_slot_item(1), source_item)
	assert_eq(bag.get_slot_item(8), target_item, "Occupied target is swapped back into the bag")
	assert_eq(state.tool_selection.selected_index, 1)
	assert_false(ui._assigning_hotbar)
	assert_eq(bag.count_item(source_item.item_id), 1)
	assert_eq(bag.count_item(target_item.item_id), 1)

func test_close_cancels_hotbar_assignment_and_reenables_bag_slots() -> void:
	assert_true(bag.move_slot(0, 8))
	ui.open()
	await wait_seconds(0.35)
	ui._inspect_slot(8)
	ui.assign_button.pressed.emit()
	assert_true(ui.buttons[8].disabled)
	ui.close()
	await wait_seconds(0.35)
	ui.open()
	await wait_seconds(0.35)
	assert_false(ui._assigning_hotbar)
	assert_false(ui.buttons[8].disabled)
	assert_null(bag.get_slot_item(0))
	assert_not_null(bag.get_slot_item(8))

func test_quality_items_are_separate_and_inspection_does_not_move_or_consume_produce() -> void:
	var produce: ItemDefinition = load("res://items/harvest_produces/carrot_produces.tres") as ItemDefinition
	bag.add(produce, 80, 0)
	bag.add(produce, 40, 1)
	ui.open()
	await wait_seconds(0.35)
	for index: int in range(bag.slot_count):
		if bag.get_slot_item(index) == produce:
			ui._inspect_slot(index)
			break
	assert_false(ui.quality_panel.visible)
	assert_string_contains(ui.item_name.text, ItemQuality.label(0))
	var silver_slot: int = -1
	for index: int in range(bag.slot_count):
		if bag.get_slot_item(index) == produce and bag.slot(index).tiers[1] > 0:
			silver_slot = index
	assert_ne(silver_slot, ui.inspected_index)
	ui._inspect_slot(silver_slot)
	assert_string_contains(ui.item_name.text, ItemQuality.label(1))
	assert_eq(bag.get_slot_count(silver_slot), 40)
	ui.search.text = ItemQuality.label(1)
	ui._apply_filter()
	for button: InventorySlot in ui.buttons:
		if button.visible:
			assert_eq(bag.get_slot_item(button.slot_index), produce)
			assert_eq(ItemQuality.stack_tier(bag.slot(button.slot_index).tiers), 1)
	assert_eq(bag.count_item(produce.item_id, -1), 120)
	assert_eq(ui.item_icon.texture, produce.icon)

func test_invalid_drag_payload_cannot_move_or_duplicate_items() -> void:
	var target: Control = ui.buttons[6]
	assert_false(target._can_drop_data(Vector2.ZERO, {"inventory": bag, "slot": 99}))
	assert_false(target._can_drop_data(Vector2.ZERO, {"inventory": bag, "slot": 0, "item_id": &"wrong"}))
	assert_false(target._can_drop_data(Vector2.ZERO, {"inventory": null, "slot": 0, "item_id": &"hoe"}))
	assert_eq(bag.count_item(&"hoe"), 1)

func test_font_theme_uses_configured_font() -> void:
	var font: FontVariation = ui.root.theme.default_font as FontVariation
	assert_not_null(font)
	assert_eq(font, preload("res://resources/ui/game_font.tres"))
	for character: String in ["T", "ú", "đ", "ồ", "ư", "ớ"]:
		var code: int = character.unicode_at(0)
		assert_true(font.base_font.has_char(code) or font.fallbacks[0].has_char(code), "Vietnamese glyph in the configured font chain: " + character)

func test_panel_fits_viewport(size = use_parameters([Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(640, 360)])) -> void:
	viewport.size = size
	ui.open()
	await wait_seconds(0.35)
	await wait_physics_frames(4)
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
	assert_true(bounds.encloses(ui.panel.get_global_rect()))
	assert_true(bounds.encloses(ui.details.get_global_rect()))
	var close_button: Control = ui.get_node("Root/Center/Panel/Body/Header/Close")
	assert_true(bounds.encloses(close_button.get_global_rect()))

func test_drag_from_a_replaced_quality_stack_is_rejected() -> void:
	var produce: ItemDefinition = preload("res://items/harvest_produces/carrot_produces.tres")
	bag.add(produce, 2, 1)
	var source: int = -1
	for index: int in range(bag.slot_count):
		if bag.get_slot_item(index) == produce:
			source = index
	var payload: Dictionary = {"inventory": bag, "slot": source, "item_id": produce.item_id, "tier": 1}
	assert_true(ui.buttons[10]._can_drop_data(Vector2.ZERO, payload))
	bag.consume(produce.item_id, 2, ItemQuality.exact(1))
	bag.add(produce, 2, 2)
	assert_false(ui.buttons[10]._can_drop_data(Vector2.ZERO, payload))
	assert_eq(bag.count_item(produce.item_id, 2), 2)
