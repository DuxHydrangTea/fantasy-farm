class_name FarmStorageMenu
extends TradeMenu
## Selection uses stable item IDs; the service owns all inventory mutations.
var storage_id: String
var service: FarmStorageService
@onready var panel: PanelContainer = %Panel
@onready var title: Label = %Title
@onready var usage: Label = %StoreUsage
@onready var status: Label = %Status
@onready var grids: Array[GridContainer] = [%BagGrid, %StoreGrid]
@onready var scrolls: Array[ScrollContainer] = [%BagScroll, %StoreScroll]
@onready var quantity: SpinBox = %Quantity
@onready var deposit_button: Button = %Deposit
@onready var withdraw_button: Button = %Withdraw
@onready var maximum_button: Button = %Maximum
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name: Label = %ItemName
@onready var source_label: Label = %Source
@onready var quality_row: HBoxContainer = %Quality
@onready var quality_buttons: Array[Button] = [%Normal, %Silver, %Gold]
var move_button: Button
var selected_id: StringName = &""
var selected_tier: int = -1
var depositing: bool = true
var pending: bool = false
var elapsed: float = 0.0
var _compact: bool = false
var _syncing: bool = false
var _capacity_blocked: bool = false

func _ready() -> void:
	root = %Root
	close_button = %Close
	super._ready()
	TouchQuantityComponent.attach(quantity, root, true)
	visit_started.connect(_visit)
	models_changed.connect(_queue_refresh)
	root.resized.connect(_fit)
	deposit_button.pressed.connect(_move)
	withdraw_button.pressed.connect(_move)
	maximum_button.pressed.connect(_maximum)
	quantity.value_changed.connect(_quantity_changed)
	(%DepositAll as Button).pressed.connect(_bulk.bind(true))
	(%WithdrawAll as Button).pressed.connect(_bulk.bind(false))
	for tier: int in range(3):
		quality_buttons[tier].pressed.connect(_select_tier.bind(tier))
	move_button = deposit_button
	_fit()

func _fit() -> void:
	var view: Vector2 = root.size
	_compact = view.x < 800 or view.y < 500 or MobileLayout.is_touch(get_viewport())
	panel.custom_minimum_size = Vector2(minf(1100, maxf(0, view.x - 32)), minf(660, maxf(0, view.y - (16 if _compact else 24))))
	(%Body as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 8)
	(%Panes as HBoxContainer).add_theme_constant_override("separation", 8 if _compact else 16)
	title.add_theme_font_size_override("font_size", 20 if _compact else 26)
	item_name.add_theme_font_size_override("font_size", 18 if _compact else 22)
	source_label.add_theme_font_size_override("font_size", 14 if _compact else 16)
	item_icon.custom_minimum_size = Vector2(32, 32) if _compact else Vector2(48, 48)
	(%QuantityTitle as Label).visible = not _compact
	(%BagTitle as Label).text = tr("Your bag")
	(%StoreTitle as Label).text = tr("Storage")
	(%DepositAll as Button).text = tr("Store all")
	(%WithdrawAll as Button).text = tr("Take all")
	(%DepositAll as Button).tooltip_text = tr("Deposit matching items")
	(%WithdrawAll as Button).tooltip_text = tr("Withdraw all")
	for button: Button in quality_buttons:
		button.custom_minimum_size.x = 72 if _compact else 112
		button.add_theme_font_size_override("font_size", 14 if _compact else 18)
	for button: Button in [deposit_button, withdraw_button, maximum_button, %DepositAll, %WithdrawAll]:
		button.add_theme_font_size_override("font_size", 14 if _compact else 18)
	var side: float = 48 if _compact else 80
	var available: float = (panel.custom_minimum_size.x - 32 - (18 if _compact else 34)) / 2 - 16
	for grid: GridContainer in grids:
		grid.columns = clampi(floori((available + 8) / (side + 8)), 1, 5)
		var cell_side: float = floorf((available - (grid.columns - 1) * 8) / grid.columns)
		for card: FarmStorageSlot in grid.get_children():
			card.custom_minimum_size = Vector2(cell_side, cell_side)
	if is_open:
		_update_command()

func _visit() -> void:
	service = (merchant as FarmStorageAccess).world.storages
	service.changed.connect(_storage_changed)
	selected_id = &""
	selected_tier = -1
	depositing = true
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
	title.text = tr(definition.display_name)
	var focused: Control = get_viewport().gui_get_focus_owner()
	var focus_side: int = int(focused.get_meta("storage_side", -1)) if focused != null else -1
	var focus_index: int = int(focused.get_meta("storage_index", -1)) if focused != null else -1
	for side: int in range(2):
		var bag: InventoryComponent = customer.selection.inventory if side == 0 else service.inventory(storage_id)
		var used: int = 0
		var scroll_position: int = scrolls[side].scroll_vertical
		for child: Node in grids[side].get_children():
			grids[side].remove_child(child)
			child.queue_free()
		for index: int in range(bag.slot_count):
			var slot: Dictionary = bag.slot(index)
			var card: FarmStorageSlot = FarmStorageSlot.new()
			card.name = "Slot" + str(index)
			card.item = slot.item
			card.amount = int(slot.count)
			card.tiers = slot.tiers
			card.custom_minimum_size = Vector2(48, 48) if _compact else Vector2(80, 80)
			card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card.disabled = card.item == null or not definition.accepts(card.item)
			if card.item != null and card.disabled:
				card.self_modulate = Color(1, 1, 1, 0.45)
			card.set_meta("storage_side", side)
			card.set_meta("storage_index", index)
			card.set_meta("storage_item", card.item.item_id if card.item != null else &"")
			card.set_meta("storage_name", card.item.display_name if card.item != null else "")
			grids[side].add_child(card)
			if card.item != null:
				used += 1
				card.pressed.connect(_select.bind(card.item.item_id, side == 0))
				if card.disabled:
					card.tooltip_text += "\n" + tr("This item does not belong in this storage.")
			if side == focus_side and index == focus_index and not card.disabled:
				card.grab_focus.call_deferred()
		var label: Label = %BagUsage if side == 0 else usage
		label.text = "%d / %d" % [used, bag.slot_count]
		label.tooltip_text = tr("Occupied slots: {used}/{total}").format({"used": used, "total": bag.slot_count})
		scrolls[side].set_deferred("scroll_vertical", scroll_position)
	_fit()

func _select(id: StringName, deposit: bool) -> void:
	selected_id = id
	depositing = deposit
	_set_quantity(1)
	var entry: Dictionary = _totals(customer.selection.inventory if depositing else service.inventory(storage_id)).get(id, {})
	var item: ItemDefinition = entry.get("item") as ItemDefinition
	selected_tier = -1
	if item != null and item.item_type == ItemDefinition.ItemType.PRODUCE and not item.star_fruit:
		for tier: int in range(3):
			if int(entry.tiers[tier]) > 0:
				selected_tier = tier
				break
	status.text = tr("Select an item, then choose a quantity.")
	_update_command()

func _select_tier(tier: int) -> void:
	selected_tier = tier
	_set_quantity(1)
	_update_command()

func _set_quantity(amount: float) -> void:
	quantity.value = amount
	# SpinBox.apply() must see the same value even within the same input frame.
	quantity.get_line_edit().text = str(int(quantity.value))

func _maximum() -> void:
	_set_quantity(quantity.max_value)

func _quantity_changed(_value: float) -> void:
	if is_open:
		_update_command()

func _update_command() -> void:
	if _syncing or not is_open:
		return
	_syncing = true
	var source: InventoryComponent = customer.selection.inventory if depositing else service.inventory(storage_id)
	var target: InventoryComponent = service.inventory(storage_id) if depositing else customer.selection.inventory
	var entry: Dictionary = _totals(source).get(selected_id, {})
	var item: ItemDefinition = entry.get("item") as ItemDefinition
	var count: int = int(entry.get("count", 0))
	var has_quality: bool = item != null and item.item_type == ItemDefinition.ItemType.PRODUCE and not item.star_fruit
	quality_row.visible = has_quality
	if has_quality:
		var names: Array[String] = ["Normal", "Silver", "Gold"]
		for tier: int in range(3):
			var amount: int = int(entry.tiers[tier])
			quality_buttons[tier].text = "%s %d" % [tr(names[tier]), amount]
			quality_buttons[tier].disabled = amount == 0
			quality_buttons[tier].set_pressed_no_signal(tier == selected_tier)
		if selected_tier >= 0:
			count = int(entry.tiers[selected_tier])
	var allowed: bool = item != null and service.definition(storage_id).accepts(item)
	var capacity: int = target.capacity_for(item) if allowed else 0
	quantity.max_value = maxi(1, mini(count, capacity))
	quantity.editable = count > 0 and capacity > 0 and allowed
	maximum_button.disabled = not quantity.editable
	item_icon.texture = item.icon if item != null else null
	(%IconFrame as PanelContainer).visible = item != null
	item_name.text = tr(item.display_name) if item != null else tr("Select an item")
	source_label.text = tr("Selected from bag") if depositing else tr("Selected from storage")
	source_label.visible = item != null
	deposit_button.disabled = not depositing or not quantity.editable
	withdraw_button.disabled = depositing or not quantity.editable
	deposit_button.text = tr("Deposit") + " →"
	withdraw_button.text = "← " + tr("Withdraw")
	deposit_button.theme_type_variation = &"PrimaryAction" if depositing else &"Button"
	withdraw_button.theme_type_variation = &"Button" if depositing else &"PrimaryAction"
	var reason: String = tr("Destination is full.") if allowed and capacity == 0 else tr("Select an item, then choose a quantity.")
	if allowed and capacity == 0:
		status.text = reason
		_capacity_blocked = true
	elif _capacity_blocked:
		status.text = tr("Select an item, then choose a quantity.")
		_capacity_blocked = false
	deposit_button.tooltip_text = reason if deposit_button.disabled else tr("Deposit")
	withdraw_button.tooltip_text = reason if withdraw_button.disabled else tr("Withdraw")
	move_button = deposit_button if depositing else withdraw_button
	for side: int in range(2):
		for card: FarmStorageSlot in grids[side].get_children():
			card.set_pressed_no_signal(item != null and card.get_meta("storage_item") == selected_id and depositing == (side == 0))
	TouchQuantityComponent.refresh_for(quantity)
	_syncing = false

func _move() -> void:
	if not is_open or move_button.disabled:
		return
	quantity.apply()
	_finish(service.transfer(storage_id, customer.selection.inventory, selected_id, int(quantity.value), depositing, selected_tier))


func _bulk(deposit: bool) -> void:
	if is_open:
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_language.call_deferred()

func _refresh_language() -> void:
	status.text = tr("Select an item, then choose a quantity.")
	_fit()
	if is_open:
		_refresh()
