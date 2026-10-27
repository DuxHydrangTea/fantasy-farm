class_name FarmSeedPicker
extends TradeMenu
## A source selector, independent of the player's six physical hotbar slots.
var world: FarmWorld
var hud: Control
var launcher: Button
var panel: PanelContainer
var summary: Label
var list: VBoxContainer
var queued: bool = false

func _ready() -> void:
	layer = 25
	_build()
	super._ready()
	root.resized.connect(_fit)
	panel.minimum_size_changed.connect(_queue_fit)
	visit_started.connect(_refresh)
	world.storages.changed.connect(_stock_changed)
	if not InputMap.has_action(&"choose_stored_seed"):
		InputMap.add_action(&"choose_stored_seed")
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_G
		InputMap.action_add_event(&"choose_stored_seed", key)
	_fit()

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = tr(caption)
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 16)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _label(parent: Node, text: String) -> Label:
	var label: Label = Label.new()
	label.text = tr(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	return label

func _build() -> void:
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.layer = 19
	add_child(hud_layer)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = preload("res://resources/ui/game_theme.tres")
	hud_layer.add_child(hud)
	UIScaleComponent.attach(hud_layer, hud)
	launcher = _button(hud, "Stored seeds · G", open_picker)
	launcher.focus_mode = Control.FOCUS_NONE
	root = Control.new()
	root.theme = hud.theme
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.06, 0.75)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	root.add_child(panel)
	var style: StyleBox = root.theme.get_stylebox(&"panel", &"PanelContainer").duplicate() as StyleBox
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(edge, 12)
	panel.add_theme_stylebox_override("panel", style)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	body.add_child(header)
	_label(header, "Sow from farm supply storage")
	close_button = _button(header, "×", func() -> void: pass)
	_label(body, "Deposit crop seeds at supply storage, then choose a variety here. Select a hotbar slot to leave this mode.")
	summary = _label(body, "")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

func _queue_fit() -> void:
	_fit.call_deferred()

func _fit() -> void:
	panel.size = Vector2(minf(680, root.size.x - 24), minf(560, root.size.y - 24))
	panel.position = (root.size - panel.size) * 0.5

func open_picker() -> void:
	if not get_tree().paused and world.storages.available() and not world.storages.busy:
		super.open(null, world.player)

func _stock_changed(id: String) -> void:
	if is_open and (id == "farm_supply_storage" or id.is_empty()) and not queued:
		queued = true
		_refresh.call_deferred()

func _refresh() -> void:
	queued = false
	if not is_open:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var focused_id: String = String(focused.name) if focused != null and list.is_ancestor_of(focused) else ""
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var store: InventoryComponent = world.storages.inventory("farm_supply_storage")
	# Resolve once through the validated catalog, including varieties currently at zero.
	world.storages.seed_item(&"")
	var ids: Array[String] = []
	var counts: Dictionary = {}
	for id: String in world.storages.catalog.items:
		var candidate: ItemDefinition = world.storages.seed_item(StringName(id))
		if candidate != null:
			ids.append(id)
			counts[id] = store.count_item(candidate.item_id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		if (int(counts[a]) > 0) != (int(counts[b]) > 0):
			return int(counts[a]) > 0
		return a < b)
	for id: String in ids:
		var item: ItemDefinition = world.storages.seed_item(StringName(id))
		if item == null:
			continue
		var count: int = int(counts[id])
		var button: Button = _button(list, "%s · %s: %d" % [tr(item.display_name), tr("Storage"), count], _choose.bind(item.item_id))
		button.name = id
		button.icon = item.icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 28)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = count == 0
		if id == focused_id and not button.disabled:
			button.grab_focus.call_deferred()
		button.tooltip_text = tr("Deposit this seed at farm supply storage.") if count == 0 else tr(item.display_name)
	summary.text = tr("Field crops consume stored seeds. Flower seeds and saplings still use your bag.")
	_queue_fit()

func _choose(id: StringName) -> void:
	if world.storages.inventory("farm_supply_storage").count_item(id) > 0 and world.player.selection.select_storage_seed(id):
		close(false)
		_save.call_deferred()

func _save() -> void:
	if SaveManager.adapter != null and SaveManager.adapter.world == world and SaveManager.writes_enabled and not SaveManager.busy:
		SaveManager.save_game()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"choose_stored_seed") and not event.is_echo() and not world.player.selection.is_menu_open():
		open_picker()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if launcher == null:
		return
	var touch: bool = MobileLayout.is_touch(get_viewport())
	hud.visible = not world.player.selection.is_menu_open() and not (touch and hud.size.y > hud.size.x)
	launcher.size = Vector2(144, 48) if touch else Vector2(220, 48)
	launcher.position = Vector2(hud.size.x - 152, hud.size.y - 228) if touch else Vector2(hud.size.x - 232, 128)
	launcher.disabled = not world.storages.available() or world.storages.busy
	var selection: ToolSelectionComponent = world.player.selection
	var chosen_seed: ItemDefinition = selection.get_selected_item() if selection.uses_storage_seeds() else null
	launcher.text = tr("Stored seeds") if touch else tr("Stored seeds · G")
	if chosen_seed != null:
		launcher.text += "\n%s × %d" % [tr(chosen_seed.display_name), selection.planting_inventory().count_item(chosen_seed.item_id)]
	launcher.clip_text = true
