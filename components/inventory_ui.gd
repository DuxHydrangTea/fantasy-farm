class_name InventoryUI
extends CanvasLayer
## Signal-driven inventory; containers own layout, InventoryComponent owns all moves.
@export var close_button: BaseButton
@export var selection: ToolSelectionComponent
@export var root: Control
@export var panel: PanelContainer
@export var grid: GridContainer
@export var details: Label
@export var capacity: Label

@onready var wallet_label: Label = %Balance
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name: Label = %ItemName
@onready var item_type: Label = %ItemType
@onready var quality_panel: PanelContainer = %QualityPanel
@onready var move_button: Button = %MoveButton
@onready var assign_button: Button = %AssignButton
@onready var touch_mode_button: Button = %TouchMode
@onready var _sidebar: VBoxContainer = %Sidebar
@onready var _actions: BoxContainer = %InventoryActions
@onready var _info: VBoxContainer = %ItemInfo
@onready var _hint: Label = %InventoryHint
@onready var _scroll: ScrollContainer = %ItemScroll
@onready var _quality_rows: Array[Label] = [%NormalCount, %SilverCount, %GoldCount]

var buttons: Array[InventorySlot] = []
var inspected_index: int = 0
var _wallet: WalletComponent
var _moving_from: int = -1
var _assigning_hotbar: bool = false
var _slide: Node
var _closing: bool = false
var search: LineEdit
var item_filter: OptionButton
var empty_results: Label
const FILTER_TYPES: Array[int] = [-1, ItemDefinition.ItemType.TOOL, ItemDefinition.ItemType.SEED, ItemDefinition.ItemType.PRODUCE, ItemDefinition.ItemType.FEED, ItemDefinition.ItemType.BOOSTER, ItemDefinition.ItemType.PLACEABLE, ItemDefinition.ItemType.MATERIAL]
const FILTER_TITLES: Array[String] = ["All items", "Tool", "Seed", "Produce", "Feed", "Booster", "Placeable", "Material"]

func _ready() -> void:
	root.hide()
	UIScaleComponent.attach(self, root)
	_build_filters()
	_slide = preload("res://components/modal_slide.gd").new()
	add_child(_slide)
	_slide.configure(self, ^"offset:y", root)
	var player: FarmPlayer = get_parent() as FarmPlayer
	_wallet = player.wallet if player != null else null
	if _wallet != null:
		_wallet.changed.connect(_refresh_wallet)
		_refresh_wallet(_wallet.balance)
	_sync_slots()
	close_button.pressed.connect(close)
	move_button.pressed.connect(_toggle_move)
	assign_button.pressed.connect(_assign_hotbar)
	touch_mode_button.pressed.connect(_cycle_touch_mode)
	selection.inventory_visibility_changed.connect(_on_visibility_changed)
	selection.inventory.changed.connect(_refresh)
	root.resized.connect(_fit_panel)
	_fit_panel()
	_refresh()

func _fit_panel() -> void:
	var view: Vector2 = root.size
	var touch: bool = MobileLayout.is_touch(get_viewport())
	var compact: bool = touch or view.x < 800.0 or view.y < 500.0
	var width: float = minf(1040.0, view.x - 32.0)
	panel.custom_minimum_size = Vector2(width, minf(600.0, view.y - (16.0 if compact else 24.0)))
	(panel.get_child(0) as VBoxContainer).add_theme_constant_override("separation", 4 if compact else 12)
	_sidebar.add_theme_constant_override("separation", 4 if compact else 8)
	_actions.vertical = not compact
	_actions.add_theme_constant_override("separation", 4 if compact else 8)
	_info.add_theme_constant_override("separation", 8 if compact else 12)
	var side: float = 48.0 if compact else 72.0
	var sidebar_width: float = 216.0 if compact else 280.0
	_sidebar.custom_minimum_size.x = sidebar_width
	var available: float = width - 32.0 - sidebar_width - 28.0 - 16.0
	grid.columns = clampi(floori((available + 8.0) / (side + 8.0)), 1, 8)
	for button: InventorySlot in buttons:
		button.custom_minimum_size = Vector2(side, side)
		button.refresh()
	item_icon.custom_minimum_size = Vector2(32, 32) if compact else Vector2(72, 72)
	item_name.add_theme_font_size_override("font_size", 20 if compact else 24)
	for label: Label in quality_panel.find_children("*", "Label"):
		label.add_theme_font_size_override("font_size", 16 if compact else 18)
	for button: Button in [move_button, assign_button]:
		button.add_theme_font_size_override("font_size", 16 if compact else 18)
	touch_mode_button.visible = touch
	_hint.visible = not compact
	if touch:
		MobileLayout.prepare_buttons(root)
	_refresh_actions(compact)
	if _wallet != null:
		_refresh_wallet(_wallet.balance)

func _cycle_touch_mode() -> void:
	var player: FarmPlayer = get_parent() as FarmPlayer
	if player != null and player.mobile_controls != null:
		player.mobile_controls.cycle_mode()
		_refresh()

func _toggle_move() -> void:
	_assigning_hotbar = false
	_moving_from = inspected_index if _moving_from < 0 else -1
	_refresh()

func _assign_hotbar() -> void:
	if not _assigning_hotbar:
		_moving_from = -1
	if _assigning_hotbar:
		_moving_from = -1
		_assigning_hotbar = false
	elif inspected_index < selection.HOTBAR_SIZE:
		selection.select_slot(inspected_index)
	else:
		_moving_from = inspected_index
		_assigning_hotbar = true
		_scroll.scroll_vertical = 0
	_refresh()

func _refresh_wallet(balance: int) -> void:
	wallet_label.text = tr("{coins} coins").format({"coins": FarmUI.compact_number(balance) if root.size.x < 640 else GameText.grouped_integer(balance)})
	wallet_label.tooltip_text = tr("{coins} coins").format({"coins": GameText.grouped_integer(balance)})

func open() -> void:
	if _closing:
		_slide.stop()
		_on_visibility_changed(true)
		return
	selection.set_inventory_open(true)

func close() -> void:
	if selection.inventory_open and not _closing:
		_closing = true
		_slide.leave(func() -> void: selection.set_inventory_open(false))

func _on_visibility_changed(value: bool) -> void:
	_closing = false
	_moving_from = -1
	_assigning_hotbar = false
	if value:
		show()
	root.visible = value
	if value:
		_fit_panel()
		_slide.enter()
	else:
		_slide.stop()
	_refresh()

func _inspect_slot(index: int) -> void:
	if _assigning_hotbar and index >= selection.HOTBAR_SIZE:
		return
	if _moving_from >= 0:
		var source: int = _moving_from
		_moving_from = -1
		_assigning_hotbar = false
		selection.inventory.move_slot(source, index)
	inspected_index = index
	if index < selection.HOTBAR_SIZE:
		selection.select_slot(index)
	_refresh()

func _refresh() -> void:
	_sync_slots()
	var used: int = 0
	for button: InventorySlot in buttons:
		button.set_selected(button.slot_index == inspected_index)
		button.disabled = _assigning_hotbar and button.slot_index >= selection.HOTBAR_SIZE
		if not selection.inventory.is_empty_slot(button.slot_index):
			used += 1
	var ordered: Array[InventorySlot] = buttons.duplicate()
	ordered.sort_custom(_slot_before)
	for index: int in range(ordered.size()):
		grid.move_child(ordered[index], index)
	_refresh_details()
	_refresh_actions(MobileLayout.is_touch(get_viewport()) or root.size.x < 800.0 or root.size.y < 500.0)
	var player: FarmPlayer = get_parent() as FarmPlayer
	touch_mode_button.text = player.mobile_controls.mode_text() if player != null and player.mobile_controls != null else tr("Touch controls: {mode}").format({"mode": tr("Auto")})
	capacity.text = tr("{used} / {total} slots").format({"used": used, "total": buttons.size()})
	_hint.text = tr("Choose a hotbar slot (1–6).") if _assigning_hotbar else tr("Tap a destination slot.") if _moving_from >= 0 else tr("Drag to swap or stack")
	_apply_filter()

func _build_filters() -> void:
	var parent: Node = _scroll.get_parent()
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ItemFilters"
	parent.add_child(row)
	parent.move_child(row, _scroll.get_index())
	search = LineEdit.new()
	search.name = "ItemSearch"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.y = 40
	search.clear_button_enabled = true
	search.text_changed.connect(func(_query: String) -> void: _apply_filter())
	row.add_child(search)
	item_filter = OptionButton.new()
	item_filter.name = "ItemTypeFilter"
	item_filter.fit_to_longest_item = false
	item_filter.clip_text = true
	item_filter.custom_minimum_size = Vector2(112, 40)
	for caption: String in FILTER_TITLES:
		item_filter.add_item(tr(caption))
	item_filter.item_selected.connect(func(_index: int) -> void: _apply_filter())
	row.add_child(item_filter)
	empty_results = Label.new()
	empty_results.name = "EmptyResults"
	empty_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(empty_results)

func _apply_filter() -> void:
	if search == null:
		return
	search.placeholder_text = tr("Search items…")
	for index: int in range(FILTER_TITLES.size()):
		item_filter.set_item_text(index, tr(FILTER_TITLES[index]))
	search.editable = _moving_from < 0
	item_filter.disabled = _moving_from >= 0
	var query: String = search.text.strip_edges().to_lower() if _moving_from < 0 else ""
	var type: int = FILTER_TYPES[maxi(0, item_filter.selected)] if _moving_from < 0 else -1
	item_filter.tooltip_text = tr(FILTER_TITLES[maxi(0, item_filter.selected)])
	var any: bool = false
	for button: InventorySlot in buttons:
		var item: ItemDefinition = selection.inventory.get_slot_item(button.slot_index)
		var matches_type: bool = item != null and (type == -1 or item.item_type == type or (type == ItemDefinition.ItemType.TOOL and item.item_type == ItemDefinition.ItemType.HOE))
		button.visible = (query.is_empty() and type == -1) or (matches_type and (query.is_empty() or ItemQuality.item_name(item, selection.inventory.slot(button.slot_index).tiers).to_lower().contains(query)))
		any = any or button.visible
	empty_results.text = tr("No matching items. Clear the search or choose another category.")
	empty_results.visible = not any
	_sidebar.visible = any
	if any and inspected_index >= 0 and not buttons[inspected_index].visible:
		for button: InventorySlot in buttons:
			if button.visible:
				inspected_index = button.slot_index
				break
		for button: InventorySlot in buttons:
			button.set_selected(button.slot_index == inspected_index)
		_refresh_details()
		_refresh_actions(MobileLayout.is_touch(get_viewport()) or root.size.x < 800.0 or root.size.y < 500.0)

func _refresh_actions(compact: bool) -> void:
	move_button.text = tr("Cancel" if compact else "Cancel move") if _moving_from >= 0 else tr("Move" if compact else "Move item")
	move_button.disabled = selection.inventory.is_empty_slot(inspected_index) and _moving_from < 0
	move_button.tooltip_text = tr("Move item")
	assign_button.text = tr("Cancel" if compact else "Cancel move") if _assigning_hotbar else tr("Hotbar" if compact else "Assign to hotbar")
	assign_button.disabled = selection.inventory.is_empty_slot(inspected_index) and not _assigning_hotbar
	assign_button.tooltip_text = tr("Assign to hotbar")

func _slot_before(a: InventorySlot, b: InventorySlot) -> bool:
	if a.slot_index < selection.HOTBAR_SIZE or b.slot_index < selection.HOTBAR_SIZE:
		return a.slot_index < b.slot_index
	var left: ItemDefinition = selection.inventory.get_slot_item(a.slot_index)
	var right: ItemDefinition = selection.inventory.get_slot_item(b.slot_index)
	var left_id: String = String(left.item_id) if left != null else "~"
	var right_id: String = String(right.item_id) if right != null else "~"
	if left_id == right_id:
		var left_tier: int = ItemQuality.stack_tier(selection.inventory.slot(a.slot_index).tiers)
		var right_tier: int = ItemQuality.stack_tier(selection.inventory.slot(b.slot_index).tiers)
		return left_tier < right_tier if left_tier != right_tier else a.slot_index < b.slot_index
	return left_id < right_id

func _refresh_details() -> void:
	var item: ItemDefinition = selection.inventory.get_slot_item(inspected_index)
	item_icon.texture = item.icon if item != null else null
	item_name.text = ItemQuality.item_name(item, selection.inventory.slot(inspected_index).tiers)
	item_type.text = _type_label(item) if item != null else ""
	quality_panel.visible = false # Quality is part of this separate item name, not a mixed-stack breakdown.
	if quality_panel.visible:
		var tiers: Array = selection.inventory.slot(inspected_index).tiers
		for tier: int in range(3):
			_quality_rows[tier].text = GameText.grouped_integer(int(tiers[tier]))
	if _moving_from >= 0:
		details.text = tr("Choose a hotbar slot (1–6).") if _assigning_hotbar else tr("Tap a destination slot.")
	elif item == null:
		details.text = tr("Select an item to see its details.")
	else:
		details.text = tr("{count} in bag").format({"count": selection.inventory.get_slot_count(inspected_index)})
		if not item.description.is_empty():
			details.text += "\n\n" + tr(item.description)
		if item.star_fruit:
			details.text += "\n\n" + tr("Star fruit: a separate Chef ingredient, not Gold quality.")

func _type_label(item: ItemDefinition) -> String:
	return tr(["Tool", "Seed", "Produce", "Feed", "Tool", "Booster", "Placeable", "Material"][item.item_type])

func _input(event: InputEvent) -> void:
	if selection.shop_open or selection.objectives_open:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if selection.inventory_open and search.has_focus() and event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code >= KEY_SPACE and code <= KEY_ASCIITILDE:
			return # Printable keys belong to the search field, including I and 1–6.
	if selection.inventory_open and _assigning_hotbar and event is InputEventKey:
		var index: int = event.physical_keycode - KEY_1
		if index >= 0 and index < selection.HOTBAR_SIZE:
			_inspect_slot(index)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"toggle_inventory"):
		if selection.inventory_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif selection.inventory_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
		if _wallet != null:
			_refresh_wallet(_wallet.balance)

func _sync_slots() -> void:
	inspected_index = mini(inspected_index, selection.inventory.slot_count - 1)
	while buttons.size() > selection.inventory.slot_count:
		var removed: InventorySlot = buttons.pop_back()
		grid.remove_child(removed)
		removed.queue_free()
	for index: int in range(buttons.size(), selection.inventory.slot_count):
		var button: InventorySlot = InventorySlot.new()
		button.name = "Slot" + str(index)
		button.inventory = selection.inventory
		button.slot_index = index
		button.compact = true
		button.cozy_skin = true
		button.show_shortcut = index < selection.HOTBAR_SIZE
		button.pressed.connect(_inspect_slot.bind(index))
		grid.add_child(button)
		buttons.append(button)
