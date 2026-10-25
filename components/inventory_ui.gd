class_name InventoryUI
extends CanvasLayer
@export var close_button: BaseButton
# Signal-driven grid adapted from the Godot skill's inventory_ui.gd template.
@export var selection: ToolSelectionComponent
@export var root: Control
@export var panel: PanelContainer
@export var grid: GridContainer
@export var details: Label
@export var capacity: Label
var buttons: Array[InventorySlot] = []
var inspected_index: int = 0
var wallet_label: Label
var _wallet: WalletComponent
var _details_scroll: ScrollContainer
var _subtitle: Label
var _hint: Label
var move_button: Button
var touch_mode_button: Button
var _moving_from: int = -1
var quality_popup: PopupPanel
var _quality_rows: Array[Label] = []

func _ready() -> void:
	root.hide()
	quality_popup = PopupPanel.new()
	quality_popup.name = "QualityBreakdown"
	var popup_theme: Theme = preload("res://resources/ui/game_theme.tres").duplicate() as Theme
	var popup_style: StyleBoxFlat = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.91, 0.81, 0.64)
	popup_style.border_color = Color(0.44, 0.28, 0.16)
	popup_style.border_width_left = 2
	popup_style.border_width_right = 2
	popup_style.border_width_top = 2
	popup_style.border_width_bottom = 2
	popup_style.content_margin_left = 16
	popup_style.content_margin_right = 16
	popup_style.content_margin_top = 12
	popup_style.content_margin_bottom = 12
	popup_theme.set_stylebox(&"panel", &"PopupPanel", popup_style)
	quality_popup.theme = popup_theme
	add_child(quality_popup)
	var quality_body: VBoxContainer = VBoxContainer.new()
	quality_body.add_theme_constant_override("separation", 8)
	quality_popup.add_child(quality_body)
	for tier: int in range(3):
		var row: Label = Label.new()
		row.add_theme_font_size_override("font_size", 20)
		row.add_theme_color_override("font_color", Color(0.28, 0.18, 0.12))
		quality_body.add_child(row)
		_quality_rows.append(row)
	UIScaleComponent.attach(self, root)
	_build_wallet_row()
	_build_details_scroll()
	grid.columns = 8
	for index: int in range(selection.inventory.slot_count):
		var button: InventorySlot = InventorySlot.new()
		button.name = "Slot" + str(index)
		button.inventory = selection.inventory
		button.slot_index = index
		button.compact = true
		button.show_shortcut = index < selection.HOTBAR_SIZE
		button.pressed.connect(_inspect_slot.bind(index))
		grid.add_child(button)
		buttons.append(button)
	close_button.pressed.connect(close)
	selection.inventory_visibility_changed.connect(_on_visibility_changed)
	selection.inventory.changed.connect(_refresh)
	root.resized.connect(_fit_panel)
	_fit_panel()
	_refresh()

func _fit_panel() -> void:
	var size: Vector2 = root.size
	var touch: bool = MobileLayout.is_touch(get_viewport())
	panel.custom_minimum_size = Vector2(minf(760.0 if touch else 560.0, size.x - 16.0 if touch else size.x - 32.0), minf(580.0, size.y - 16.0 if touch else size.y - 24.0))
	grid.columns = mini(8, maxi(1, floori((panel.custom_minimum_size.x - 48.0) / 60.0))) if touch else 8
	if touch:
		MobileLayout.prepare_buttons(root)
	for button: InventorySlot in buttons:
		button.refresh()
	_details_scroll.custom_minimum_size.y = 88 if touch else 76
	_subtitle.visible = not touch
	_hint.visible = not touch
	move_button.visible = touch
	_hint.text = tr("Drag to swap or stack")

func _build_details_scroll() -> void:
	var body: Node = details.get_parent()
	var index: int = details.get_index()
	_details_scroll = ScrollContainer.new()
	_details_scroll.name = "ItemDetailsScroll"
	_details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_details_scroll)
	body.move_child(_details_scroll, index)
	details.reparent(_details_scroll)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_button = Button.new()
	move_button.custom_minimum_size.y = 48
	move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_button.focus_mode = Control.FOCUS_NONE
	move_button.pressed.connect(_toggle_move)
	_hint.get_parent().add_child(move_button)
	touch_mode_button = Button.new()
	touch_mode_button.custom_minimum_size.y = 48
	touch_mode_button.add_theme_font_size_override("font_size", 16)
	touch_mode_button.focus_mode = Control.FOCUS_NONE
	touch_mode_button.pressed.connect(_cycle_touch_mode)
	_hint.get_parent().add_child(touch_mode_button)

func _cycle_touch_mode() -> void:
	var player: FarmPlayer = get_parent() as FarmPlayer
	if player != null and player.mobile_controls != null:
		player.mobile_controls.cycle_mode()
		_refresh()

func _toggle_move() -> void:
	_moving_from = inspected_index if _moving_from < 0 else -1
	_refresh()

func _build_wallet_row() -> void:
	var player: FarmPlayer = get_parent() as FarmPlayer
	_wallet = player.wallet if player != null else null
	var body: VBoxContainer = details.get_parent() as VBoxContainer
	# Cache the two existing captions by type before rearranging their containers.
	for child: Node in body.get_children():
		if child is Label and child != details:
			_subtitle = child as Label
	for child: Node in capacity.get_parent().get_children():
		if child is Label and child != capacity:
			_hint = child as Label
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "WalletRow"
	row.add_theme_constant_override("separation", 16)
	body.add_child(row)
	body.move_child(row, 1)
	wallet_label = Label.new()
	wallet_label.name = "Balance"
	wallet_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallet_label.add_theme_font_size_override("font_size", 24)
	row.add_child(wallet_label)
	capacity.reparent(row)
	capacity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _wallet != null:
		_wallet.changed.connect(_refresh_wallet)
		_refresh_wallet(_wallet.balance)

func _refresh_wallet(balance: int) -> void:
	wallet_label.text = tr("{coins} coins").format({"coins": GameText.grouped_integer(balance)})

func open() -> void:
	selection.set_inventory_open(true)

func close() -> void:
	quality_popup.hide()
	selection.set_inventory_open(false)

func _on_visibility_changed(value: bool) -> void:
	_moving_from = -1
	if value:
		show() # Cho phép ẩn CanvasLayer trong editor mà vẫn mở túi khi chơi.
	root.visible = value
	if not value:
		quality_popup.hide()
	if value:
		_fit_panel()
		_refresh()

func _inspect_slot(index: int) -> void:
	if _moving_from >= 0:
		var source: int = _moving_from
		_moving_from = -1
		selection.inventory.move_slot(source, index)
	inspected_index = index
	if index < selection.HOTBAR_SIZE:
		selection.select_slot(index)
	_refresh()
	var item: ItemDefinition = selection.inventory.get_slot_item(index)
	if item != null and item.item_type == ItemDefinition.ItemType.PRODUCE and _moving_from < 0:
		var tiers: Array = selection.inventory.slot(index).tiers
		for tier: int in range(3):
			_quality_rows[tier].text = "%s: %d" % [ItemQuality.label(tier), tiers[tier]]
		quality_popup.popup_centered(Vector2i(280, 160))

func _refresh() -> void:
	var used: int = 0
	for index: int in range(buttons.size()):
		var selected: bool = index == inspected_index
		buttons[index].set_selected(selected)
		if not selection.inventory.is_empty_slot(index):
			used += 1
	var ordered: Array[InventorySlot] = buttons.duplicate()
	ordered.sort_custom(func(a: InventorySlot, b: InventorySlot) -> bool:
		if a.slot_index < selection.HOTBAR_SIZE or b.slot_index < selection.HOTBAR_SIZE:
			return a.slot_index < b.slot_index
		var left: ItemDefinition = selection.inventory.get_slot_item(a.slot_index)
		var right: ItemDefinition = selection.inventory.get_slot_item(b.slot_index)
		var left_id: String = String(left.item_id) if left != null else "~"
		var right_id: String = String(right.item_id) if right != null else "~"
		return left_id < right_id or (left_id == right_id and a.slot_index < b.slot_index)
	)
	for index: int in range(ordered.size()):
		grid.move_child(ordered[index], index)
	var item: ItemDefinition = selection.inventory.get_slot_item(inspected_index)
	var touch: bool = MobileLayout.is_touch(get_viewport())
	if item != null:
		details.text = tr("{item} ×{count}").format({"item": tr(item.display_name), "count": selection.inventory.get_slot_count(inspected_index)})
	else:
		details.text = tr("Empty slot") if touch else tr("Empty slot - drag an item here")
	if item != null and item.item_type == ItemDefinition.ItemType.PRODUCE:
		var tiers: Array = selection.inventory.slot(inspected_index).tiers
		for tier: int in range(3):
			details.text += "\n%s: %d" % [ItemQuality.label(tier), tiers[tier]]
	if item != null and MobileLayout.is_touch(get_viewport()) and not item.description.is_empty():
		details.text += "\n" + tr(item.description)
	if _moving_from >= 0:
		details.text = tr("Tap a destination slot.")
	move_button.text = tr("Cancel move") if _moving_from >= 0 else tr("Move item")
	move_button.disabled = item == null and _moving_from < 0
	var player: FarmPlayer = get_parent() as FarmPlayer
	if touch_mode_button != null:
		touch_mode_button.text = player.mobile_controls.mode_text() if player != null and player.mobile_controls != null else tr("Touch controls: {mode}").format({"mode": tr("Auto")})
	capacity.text = tr("{used} / {total} slots").format({"used": used, "total": buttons.size()})

func _input(event: InputEvent) -> void:
	if selection.shop_open or selection.objectives_open:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"toggle_inventory"):
		selection.set_inventory_open(not selection.inventory_open)
		get_viewport().set_input_as_handled()
	elif selection.inventory_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
		if _wallet != null:
			_refresh_wallet(_wallet.balance)
