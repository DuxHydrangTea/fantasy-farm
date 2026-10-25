class_name WorkerMenu
extends TradeMenu
## Shared merchant modal gives E/click/touch and blocks player actions consistently.
var role: String = "orchard"
var world: FarmWorld
var panel: PanelContainer
var info: Label
var status: Label
var hire_button: Button
var dismiss_button: Button
var collect_button: Button
var deposit_button: Button
var withdraw_button: Button
var zones: OptionButton
var _confirm: bool = false
var _elapsed: float = 0.0

func _ready() -> void:
	layer = 25
	root = Control.new()
	root.theme = preload("res://resources/ui/game_theme.tres")
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	root.add_child(panel)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	body.add_child(header)
	var heading: Label = Label.new()
	heading.text = tr("Hired workers")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 20)
	header.add_child(heading)
	close_button = _button(header, "×", func() -> void: pass)
	close_button.custom_minimum_size.x = 44
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	body.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 16)
	content.add_child(info)
	zones = OptionButton.new()
	zones.custom_minimum_size.y = 44
	content.add_child(zones)
	hire_button = _button(content, tr("Hire worker"), _hire)
	deposit_button = _button(content, tr("Deposit feed"), _deposit)
	collect_button = _button(content, tr("Collect products"), _collect)
	withdraw_button = _button(content, tr("Withdraw feed"), _withdraw)
	dismiss_button = _button(content, tr("Dismiss worker"), _dismiss)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 16)
	content.add_child(status)
	super._ready()
	visit_started.connect(_visit)
	root.resized.connect(_queue_fit)
	panel.minimum_size_changed.connect(_queue_fit)
	_fit()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _queue_fit() -> void:
	_fit.call_deferred()

func _fit() -> void:
	panel.size = Vector2(minf(620, root.size.x - 24), minf(540, root.size.y - 24))
	panel.position = (root.size - panel.size) * 0.5

func _visit() -> void:
	world = customer.get_parent() as FarmWorld
	status.text = ""
	_confirm = false
	zones.clear()
	for pen: AnimalPen in world.workers.bridge.pens():
		zones.add_item(PenStatus.title(pen))
		zones.set_item_metadata(zones.item_count - 1, String(pen.persistent_id))
	_refresh()
	_queue_fit()

func _refresh() -> void:
	if not is_open or world == null:
		return
	var service: WorkerService = world.workers
	var row: Dictionary = service.record(role)
	var employed: bool = not row.is_empty() and row.employed
	zones.visible = role == "ranch"
	zones.disabled = employed
	var lines: PackedStringArray = [tr("Workers") + " · " + tr(role), tr("Daily wage: %d coins · paid at dawn") % int(WorkerRole.WAGES[role])]
	lines.append(tr("First shift is free once per role. Rehiring costs today's wage."))
	if row.is_empty():
		lines.append(tr(service.unlock_error(role)))
	else:
		lines.append(tr("Working") if row.active and employed else tr("Resting"))
		if role == "ranch" and employed:
			for i: int in range(zones.item_count):
				if String(zones.get_item_metadata(i)) == row.zone:
					zones.select(i)
		var bag: InventoryComponent = service.bag_for(role)
		var counts: Dictionary = {}
		var used: int = 0
		for i: int in range(bag.slot_count):
			var stack: Dictionary = bag.slot(i)
			if stack.item != null:
				used += 1
				var title: String = tr(stack.item.display_name)
				counts[title] = int(counts.get(title, 0)) + int(stack.count)
		lines.append(tr("Basket %d/16") % used)
		for key: String in counts:
			lines.append("%s × %d" % [key, counts[key]])
	info.text = "\n".join(lines)
	hire_button.disabled = employed or not service.available() or not service.unlock_error(role).is_empty()
	dismiss_button.disabled = not employed or not service.available()
	dismiss_button.text = tr("Confirm dismissal (basket is kept)") if _confirm else tr("Dismiss worker")
	collect_button.disabled = row.is_empty() or not service.available()
	deposit_button.visible = role == "ranch"
	withdraw_button.visible = role == "ranch"
	deposit_button.disabled = row.is_empty() or not service.available()
	withdraw_button.disabled = row.is_empty() or not service.available()

func _hire() -> void:
	if world == null:
		return
	var zone: String = String(zones.get_item_metadata(zones.selected)) if role == "ranch" and zones.selected >= 0 else ""
	var error: String = world.workers.hire(role, zone)
	status.text = tr(error) if not error.is_empty() else tr("Worker hired.")
	_refresh()
	_save.call_deferred()

func _dismiss() -> void:
	if not _confirm:
		_confirm = true
		_refresh()
		return
	status.text = tr(world.workers.dismiss(role))
	_confirm = false
	_refresh()
	_save.call_deferred()

func _deposit() -> void:
	_transfer(true, true)

func _withdraw() -> void:
	_transfer(false, true)

func _collect() -> void:
	_transfer(false, false)

func _transfer(deposit: bool, supplies: bool) -> void:
	var moved: int = world.workers.transfer(role, customer.selection.inventory, deposit, supplies)
	status.text = tr("Transferred: %d units. Anything that does not fit stays in the source basket.") % moved
	_refresh()
	_save.call_deferred()

func _save() -> void:
	var manager: GameSaveManager = get_node_or_null("/root/SaveManager") as GameSaveManager
	if manager != null and manager.adapter != null and manager.adapter.world == world and manager.writes_enabled and not manager.busy:
		await manager.save_game()

func _process(delta: float) -> void:
	if is_open:
		_elapsed += delta
		if _elapsed >= 0.5:
			_elapsed = 0.0
			_refresh()
