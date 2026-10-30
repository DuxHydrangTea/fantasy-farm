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

func _ready() -> void:
	root.hide()
	UIScaleComponent.attach(self, root)
	_slide = preload("res://components/modal_slide.gd").new()
	add_child(_slide)
	_slide.configure(self, ^"offset:y", root)
	var player: FarmPlayer = get_parent() as FarmPlayer
	_wallet = player.wallet if player != null else null
	if _wallet != null:
		_wallet.changed.connect(_refresh_wallet)
		_refresh_wallet(_wallet.balance)
	for index: int in range(selection.inventory.slot_count):
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
	wallet_label.text = tr("{coins} coins").format({"coins": GameText.grouped_integer(balance)})

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
	return left_id < right_id or (left_id == right_id and a.slot_index < b.slot_index)

func _refresh_details() -> void:
	var item: ItemDefinition = selection.inventory.get_slot_item(inspected_index)
	item_icon.texture = item.icon if item != null else null
	item_name.text = tr(item.display_name) if item != null else tr("Empty slot")
	item_type.text = _type_label(item) if item != null else ""
	quality_panel.visible = item != null and item.item_type == ItemDefinition.ItemType.PRODUCE and not item.star_fruit
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
