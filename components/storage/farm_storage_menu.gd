class_name FarmStorageMenu
extends TradeMenu
## Selected commands use item IDs, never stale visual slot indices.
var storage_id: String
var service: FarmStorageService
var panel: PanelContainer
var title: Label
var usage: Label
var status: Label
var grids: Array[VBoxContainer] = []
var quantity: SpinBox
var move_button: Button
var selected_id: StringName = &""
var depositing: bool = true
var pending: bool = false
var elapsed: float = 0.0

func _ready() -> void:
	layer = 25
	_build()
	super._ready()
	visit_started.connect(_visit)
	models_changed.connect(_queue_refresh)
	root.resized.connect(_fit)
	panel.minimum_size_changed.connect(_queue_fit)
	_fit()

func _queue_fit() -> void:
	_fit.call_deferred()

func _label(parent: Node, caption: String = "") -> Label:
	var label: Label = Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = caption
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 16)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _build() -> void:
	root = Control.new()
	root.theme = preload("res://resources/ui/game_theme.tres")
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
	body.add_theme_constant_override("separation", 6)
	panel.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	body.add_child(header)
	title = _label(header)
	close_button = _button(header, "×", func() -> void: pass)
	usage = _label(body)
	var panes: HBoxContainer = HBoxContainer.new()
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panes.add_theme_constant_override("separation", 12)
	body.add_child(panes)
	for side: int in range(2):
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panes.add_child(column)
		_label(column, tr("Your bag") if side == 0 else tr("Storage"))
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		column.add_child(scroll)
		var list: VBoxContainer = VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		grids.append(list)
	var command: HBoxContainer = HBoxContainer.new()
	body.add_child(command)
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 1
	quantity.rounded = true
	quantity.custom_minimum_size = Vector2(90, 44)
	command.add_child(quantity)
	TouchQuantityComponent.attach(quantity, root)
	move_button = _button(command, tr("Deposit"), _move)
	move_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bulk: HBoxContainer = HBoxContainer.new()
	body.add_child(bulk)
	for deposit: bool in [true, false]:
		var button: Button = _button(bulk, tr("Deposit matching items") if deposit else tr("Withdraw all"), _bulk.bind(deposit))
		button.name = "DepositAll" if deposit else "WithdrawAll"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status = _label(body, tr("Select an item, then choose a quantity."))
	status.custom_minimum_size.y = 40

func _fit() -> void:
	panel.position = Vector2(12, 12)
	panel.size = root.size - Vector2(24, 24)

func _visit() -> void:
	service = (merchant as FarmStorageAccess).world.storages
	service.changed.connect(_storage_changed)
	selected_id = &""
	status.text = tr("Select an item, then choose a quantity.")
	_refresh()

func _storage_changed(_id: String) -> void:
	_queue_refresh()

func _queue_refresh() -> void:
	if not pending:
		pending = true
		_refresh.call_deferred()

func _totals(bag: InventoryComponent) -> Dictionary:
	var result: Dictionary = {}
	for i: int in range(bag.slot_count):
		var slot: Dictionary = bag.slot(i)
		if slot.item != null:
			var id: StringName = slot.item.item_id
			if not result.has(id):
				result[id] = {"item": slot.item, "count": 0, "tiers": [0, 0, 0]}
			result[id].count += int(slot.count)
			for tier: int in range(3):
				result[id].tiers[tier] += int(slot.tiers[tier])
	return result

func _refresh() -> void:
	pending = false
	if not is_open:
		return
	var definition: FarmStorageDefinition = service.definition(storage_id)
	var store: InventoryComponent = service.inventory(storage_id)
	var focused: Control = get_viewport().gui_get_focus_owner()
	var focus_id: StringName = focused.get_meta("storage_item", &"") if focused != null else &""
	var focus_deposit: bool = bool(focused.get_meta("storage_deposit", true)) if focused != null else true
	title.text = tr(definition.display_name)
	var used: int = 0
	for i: int in range(store.slot_count):
		if store.slot(i).item != null:
			used += 1
	usage.text = tr("Occupied slots: {used}/{total}").format({"used": used, "total": store.slot_count}) + " · " + tr("Produce only" if definition.kind == FarmStorageDefinition.Kind.PRODUCE else "Crop seeds, feed and fertilizer only")
	for side: int in range(2):
		var list: VBoxContainer = grids[side]
		for child: Node in list.get_children():
			list.remove_child(child)
			child.queue_free()
		var totals: Dictionary = _totals(customer.selection.inventory if side == 0 else store)
		if totals.is_empty():
			_label(list, tr("Empty"))
		for id: StringName in totals:
			var item: ItemDefinition = totals[id].item
			var button: Button = _button(list, "%s × %d" % [tr(item.display_name), int(totals[id].count)], _select.bind(id, side == 0))
			button.icon = item.icon
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 28)
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.disabled = not definition.accepts(item)
			button.text += "\n" + ItemQuality.summary(totals[id].tiers) if item.item_type == ItemDefinition.ItemType.PRODUCE and not item.star_fruit else ""
			button.tooltip_text = tr(item.display_name) if not button.disabled else tr("This item does not belong in this storage.")
			button.toggle_mode = true
			button.button_pressed = id == selected_id and depositing == (side == 0)
			button.set_meta("storage_item", id)
			button.set_meta("storage_deposit", side == 0)
			if id == focus_id and focus_deposit == (side == 0) and not button.disabled:
				button.grab_focus.call_deferred()
	_update_command()
	_queue_fit()

func _select(id: StringName, deposit: bool) -> void:
	selected_id = id
	depositing = deposit
	quantity.value = 1
	status.text = tr("Select an item, then choose a quantity.")
	for side: int in range(2):
		for child: Node in grids[side].get_children():
			if child is Button:
				(child as Button).button_pressed = child.get_meta("storage_item", &"") == id and deposit == (side == 0)
	_update_command()

func _update_command() -> void:
	var totals: Dictionary = _totals(customer.selection.inventory if depositing else service.inventory(storage_id))
	var count: int = int(totals.get(selected_id, {}).get("count", 0))
	quantity.max_value = maxi(1, count)
	quantity.editable = count > 0
	move_button.disabled = count == 0
	move_button.text = tr("Deposit") if depositing else tr("Withdraw")
	if count > 0:
		move_button.text += " · " + tr((totals[selected_id].item as ItemDefinition).display_name)
	TouchQuantityComponent.refresh_for(quantity)

func _move() -> void:
	quantity.apply()
	_finish(service.transfer(storage_id, customer.selection.inventory, selected_id, int(quantity.value), depositing))

func _bulk(deposit: bool) -> void:
	_finish(service.transfer_all(storage_id, customer.selection.inventory, deposit))

func _finish(result: Dictionary) -> void:
	status.text = tr("Moved {count} items.").format({"count": result.moved}) if result.ok else tr(result.error)
	_queue_refresh()
	if result.ok:
		_save.call_deferred()

func _save() -> void:
	if service != null and SaveManager.adapter != null and SaveManager.adapter.world == service.world and SaveManager.writes_enabled and not SaveManager.busy:
		SaveManager.save_game()

func close(show_thanks: bool = true) -> void:
	if is_open and is_instance_valid(service) and service.changed.is_connected(_storage_changed):
		service.changed.disconnect(_storage_changed)
	super.close(show_thanks)

func _process(delta: float) -> void:
	if not is_open:
		return
	elapsed += delta
	if elapsed >= 0.25:
		elapsed = 0
		if not (merchant as FarmStorageAccess).can_reach(customer):
			close(false)
