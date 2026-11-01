extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
const PREFERENCES: String = "user://gut_ui_completion_preferences.cfg"
var viewport: SubViewport
var world: FarmWorld
var original_scale: float
var original_volume: float
var original_language: String

func before_each() -> void:
	original_scale = FarmUI.ui_scale
	original_volume = FarmUI.master_volume
	original_language = TranslationServer.get_locale()
	FarmUI.ui_scale = 1.0
	viewport = SubViewport.new()
	viewport.world_2d = World2D.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.size_2d_override = Vector2i(1920, 1080)
	viewport.size_2d_override_stretch = true
	add_child_autofree(viewport)
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	viewport.add_child(world)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(907959824)
	await wait_process_frames(4)

func after_each() -> void:
	FarmUI.ui_scale = original_scale
	FarmUI.master_volume = original_volume
	Language.set_language(original_language)
	AudioServer.set_bus_mute(0, original_volume <= 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, original_volume)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PREFERENCES))

func _pixels(control: Control) -> Rect2:
	return viewport.get_stretch_transform() * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func test_hud_groups_fit_and_tutorial_does_not_cover_objective_in_both_languages() -> void:
	var hotbar: HotbarUI = world.player.get_node("Hotbar") as HotbarUI
	var picker: FarmSeedPicker
	for child: Node in world.get_children():
		if child is FarmSeedPicker:
			picker = child as FarmSeedPicker
	assert_not_null(picker)
	for language: String in ["vi", "en"]:
		Language.set_language(language)
		for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
			viewport.size = size
			get_tree().call_group(&"ui_scales", "refresh")
			picker._process(0)
			world.tutorial_hints.refresh()
			await wait_process_frames(4)
			var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
			assert_true(bounds.grow(1).encloses(_pixels(hotbar.slots)), "Hotbar fits " + str(size))
			assert_true(bounds.grow(1).encloses(_pixels(world.objective_ui.hud_card)))
			if world.tutorial_hints.button.visible:
				assert_false(_pixels(world.tutorial_hints.button).intersects(_pixels(world.objective_ui.hud_card)))
			assert_true(hotbar.selected_name.visible)
			assert_eq(picker.launcher.get_parent(), hotbar.slots)
			assert_false(_pixels(picker.launcher).intersects(_pixels(hotbar.inventory_button)))
			assert_true(picker.launcher.text.contains("[" + GameText.action_key(&"choose_stored_seed") + "]"))

func test_wallet_is_compact_but_tooltip_keeps_exact_value_and_locale() -> void:
	var hud: WalletHUD = (world.player.get_node("Hotbar") as HotbarUI).wallet_hud
	for language: String in ["en", "vi"]:
		Language.set_language(language)
		assert_true(hud.label.text.contains("907"))
		assert_true(hud.label.text.contains("M"))
		assert_true(hud.panel.tooltip_text.contains(GameText.grouped_integer(907959824)))
		world.player.wallet.set_balance(500)
		assert_false(hud.label.text.contains("M"))
		world.player.wallet.set_balance(907959824)

func test_inventory_filters_do_not_move_or_spend_items_and_empty_result_recovers() -> void:
	var ui: InventoryUI = world.player.get_node("InventoryUI") as InventoryUI
	var medicine: ItemDefinition = preload("res://items/boosters/animal_medicine.tres")
	world.player.selection.inventory.add(medicine, 2)
	ui.open()
	ui.search.text = tr(medicine.display_name)
	ui.search.text_changed.emit(ui.search.text)
	var visible_items: int = 0
	for button: InventorySlot in ui.buttons:
		if button.visible:
			visible_items += 1
			assert_eq(button.inventory.get_slot_item(button.slot_index).item_id, medicine.item_id)
	assert_eq(visible_items, 1)
	ui.search.text = "zzz-no-such-item"
	ui.search.text_changed.emit(ui.search.text)
	assert_true(ui.empty_results.visible)
	ui.search.text = ""
	ui.search.text_changed.emit("")
	assert_false(ui.empty_results.visible)
	for button: InventorySlot in ui.buttons:
		assert_true(button.visible)
	assert_eq(world.player.selection.inventory.count_item(medicine.item_id), 2)
	ui.item_filter.select(1)
	ui.item_filter.item_selected.emit(1)
	assert_true(ui.buttons[0].visible, "The tool filter includes the legacy hoe item type")
	assert_false(ui.empty_results.visible)

func test_dialogue_stays_inside_view_at_left_and_right_edges() -> void:
	var merchant: ShopMerchant = world.get_node("PetMerchant") as ShopMerchant
	for x: float in [16.0, 1904.0]:
		merchant.global_position = viewport.get_canvas_transform().affine_inverse() * Vector2(x, 180)
		merchant.thank_customer()
		for popup_scale: float in [0.85, 1.0, 1.06]:
			merchant.bubble.scale = Vector2.ONE * popup_scale
			merchant._place_bubble()
			assert_true(Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(1).encloses(_pixels(merchant.bubble)))

func test_settings_persist_real_options_and_share_modal_lock() -> void:
	var settings: TradeMenu = world.player.get_node("FarmSettings") as TradeMenu
	settings.set("preferences_path", PREFERENCES)
	settings.call("show_settings")
	assert_true(world.player.selection.is_menu_open())
	world.player.selection.set_inventory_open(true)
	assert_false(world.player.selection.inventory_open)
	var size_choice: OptionButton = settings.get("size_choice") as OptionButton
	size_choice.item_selected.emit(1)
	var language_choice: OptionButton = settings.get("language_choice") as OptionButton
	language_choice.item_selected.emit(1)
	var volume: HSlider = settings.get("volume") as HSlider
	volume.value = 35
	settings.call("_persist")
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load(PREFERENCES), OK)
	assert_almost_eq(float(config.get_value("ui", "scale")), 1.25, 0.001)
	assert_eq(config.get_value("ui", "language"), "en")
	assert_almost_eq(float(config.get_value("audio", "master")), 0.35, 0.001)
	assert_almost_eq(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.35, 0.001)
	settings.close(false)
	assert_false(world.player.selection.is_menu_open())
	assert_null(SaveManager.adapter, "UI options never bind or rewrite a farm profile")

func test_save_status_uses_a_single_bounded_panel_and_sleeps_when_idle() -> void:
	var persistence: WorldPersistence
	for child: Node in world.get_children():
		if child is WorldPersistence:
			persistence = child as WorldPersistence
	persistence._build_notice()
	persistence._notice(tr("Progress saved"), true)
	await wait_process_frames(3)
	assert_true(persistence._notice_panel.visible)
	assert_false(persistence.is_processing())
	assert_true(Rect2(Vector2.ZERO, Vector2(viewport.size)).encloses(_pixels(persistence._notice_panel)))
	persistence._notice("An error that needs attention", false)
	assert_eq(persistence._label.text, "An error that needs attention")
	assert_eq(persistence._notice_timer.wait_time, 15.0)

func test_cozy_hud_claims_ready_reward_once_without_opening_a_modal() -> void:
	var ui: ObjectiveUI = world.objective_ui
	world.objectives.progress.state_query = func(_condition: StringName) -> int: return 1
	world.objectives.progress.refresh_state()
	await wait_process_frames(3)
	assert_true(ui.hud_claim.visible)
	var before: int = world.player.wallet.balance
	var reward: int = world.objectives.progress.active().reward_coins
	ui.hud_claim.pressed.emit()
	assert_eq(world.player.wallet.balance, before + reward)
	assert_false(world.player.selection.is_menu_open())
	ui.hud_claim.pressed.emit()
	assert_eq(world.player.wallet.balance, before + reward)

func test_animal_speech_uses_shared_font_and_contains_vietnamese_text() -> void:
	Language.set_language("vi")
	var anchor: Node2D = Node2D.new()
	world.add_child(anchor)
	var speech: Node2D = preload("res://components/animals/animal_care_bubble.gd").new()
	anchor.add_child(speech)
	await wait_process_frames(3)
	var panel: PanelContainer = speech.get_node("BubbleVisual/BubblePanel") as PanelContainer
	var text: Label = panel.get_node("Text") as Label
	assert_true(panel.get_theme_stylebox("panel") is StyleBoxFlat)
	assert_eq(text.get_theme_font("font"), preload("res://resources/ui/game_font.tres"))
	assert_eq(text.text, tr("Feeling healthy!"))
	assert_true(Rect2(Vector2.ZERO, panel.size).encloses(text.get_rect()))
	anchor.queue_free()
