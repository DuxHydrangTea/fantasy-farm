class_name ObjectiveUI
extends CanvasLayer
signal help_requested
## Signal-driven HUD adapted from the skill HUD template; one shared modal lock.
var model: ObjectiveProgress
var selection: ToolSelectionComponent
var root: Control
var hud: HBoxContainer
var hud_button: Button
var collapse_button: Button
var help_button: Button
var overlay: ColorRect
var panel: PanelContainer
var heading: Label
var close_button: Button
var list_scroll: ScrollContainer
var list_box: VBoxContainer
var rows: Array[Button] = []
var detail: Label
var claim_button: Button
var track_button: Button
var notice: Label
var inspected: int = 0
var _ready_id: String = ""
var _message: String = ""
var _reward: int = 0
var _completion: Timer
var _slide: Node
var _closing: bool = false
var hud_card: PanelContainer
var hud_reward: Label
var hud_claim: Button
var hud_caption: Label
var hud_progress: ProgressBar

func _ready() -> void:
	layer = 24
	root = Control.new()
	root.name = "ObjectiveRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = preload("res://resources/ui/cozy_hud/inventory_theme.tres")
	add_child(root)
	hud_card = PanelContainer.new()
	hud_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_card)
	var hud_column: VBoxContainer = VBoxContainer.new()
	hud_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_card.add_child(hud_column)
	hud_caption = Label.new()
	hud_caption.text = tr("Objectives")
	hud_caption.add_theme_font_size_override("font_size", 13)
	hud_caption.add_theme_color_override("font_color", FarmUI.MUTED)
	hud_column.add_child(hud_caption)
	hud = HBoxContainer.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_column.add_child(hud)
	hud_button = _button(hud, open)
	hud_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_button.clip_text = true
	hud_button.add_theme_font_size_override("font_size", 16)
	hud_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud_button.add_theme_stylebox_override("normal", FarmUI.box(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT))
	collapse_button = _button(hud, _collapse)
	collapse_button.custom_minimum_size.x = 48
	help_button = _button(hud, func() -> void: help_requested.emit())
	help_button.custom_minimum_size.x = 48
	help_button.text = "?"
	help_button.tooltip_text = tr("Help") + " [H]"
	hud_progress = ProgressBar.new()
	hud_progress.custom_minimum_size.y = 6
	hud_progress.show_percentage = false
	hud_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var progress_bg: StyleBoxFlat = StyleBoxFlat.new()
	progress_bg.bg_color = Color("d6bf95")
	hud_progress.add_theme_stylebox_override("background", progress_bg)
	var progress_fill: StyleBoxFlat = StyleBoxFlat.new()
	progress_fill.bg_color = Color("6d914b")
	hud_progress.add_theme_stylebox_override("fill", progress_fill)
	hud_column.add_child(hud_progress)
	hud_reward = Label.new()
	hud_reward.add_theme_font_size_override("font_size", 14)
	hud_column.add_child(hud_reward)
	hud_claim = _button(hud_column, _claim_tracked)
	hud_claim.theme_type_variation = &"PrimaryAction"
	overlay = ColorRect.new()
	overlay.color = Color(0.03, 0.04, 0.06, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	_build_page()
	overlay.hide()
	_slide = preload("res://components/modal_slide.gd").new()
	add_child(_slide)
	_slide.configure(overlay, ^"position:y", overlay)
	_completion = Timer.new()
	_completion.one_shot = true
	_completion.wait_time = 4
	_completion.timeout.connect(refresh)
	add_child(_completion)
	model.changed.connect(refresh)
	model.restored.connect(_restored)
	selection.objectives_visibility_changed.connect(_visibility)
	selection.inventory_visibility_changed.connect(_other_menu)
	selection.shop_visibility_changed.connect(_other_menu)
	root.resized.connect(_fit)
	UIScaleComponent.attach(self, root)
	_restored()
	refresh()
	_fit()

func _button(parent: Node, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 16)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

func _build_page() -> void:
	panel = PanelContainer.new()
	overlay.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	body.add_child(header)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 20)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	close_button = _button(header, close)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	body.add_child(columns)
	list_scroll = ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.follow_focus = true
	columns.add_child(list_scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_box)
	for index: int in range(model.catalog.steps.size()):
		var button: Button = _button(list_box, inspect.bind(index))
		button.custom_minimum_size.y = 64
		button.clip_text = true
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		rows.append(button)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var detail_scroll: ScrollContainer = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(detail_scroll)
	detail = Label.new()
	detail.add_theme_font_size_override("font_size", 16)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_scroll.add_child(detail)
	track_button = _button(right, _track)
	claim_button = _button(right, _claim)
	claim_button.theme_type_variation = &"PrimaryAction"
	notice = Label.new()
	notice.add_theme_font_size_override("font_size", 14)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.y = 24
	body.add_child(notice)

func _fit() -> void:
	if panel == null:
		return
	panel.position = Vector2(8, 8)
	panel.size = root.size - Vector2(16, 16)
	list_scroll.custom_minimum_size.x = floorf((root.size.x - 64) * 0.42)
	var compact_hud: bool = root.size.y < 500
	hud_caption.visible = not compact_hud
	hud_reward.visible = not compact_hud and not model.hud_collapsed and model.tracked_index() >= 0
	hud_card.position = Vector2(16, 88 if compact_hud else 110)
	hud_card.custom_minimum_size.x = minf(340, maxf(260, root.size.x - 32))
	hud_card.size = Vector2(hud_card.custom_minimum_size.x, 0)
	hud_card.visible = hud.visible

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_instance_valid(detail):
		refresh()

func _input(event: InputEvent) -> void:
	if selection.is_menu_open() and not selection.objectives_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_J:
			if selection.objectives_open:
				close()
			else:
				open()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE and selection.objectives_open:
			close()
			get_viewport().set_input_as_handled()

func open() -> void:
	if selection.is_menu_open():
		return
	inspected = maxi(0, model.tracked_index())
	selection.set_objectives_open(true)
	refresh()
	rows[inspected].grab_focus()
	list_scroll.call_deferred("ensure_control_visible", rows[inspected])

func close() -> void:
	if selection.objectives_open and not _closing:
		_closing = true
		_slide.leave(func() -> void: selection.set_objectives_open(false))

func _visibility(value: bool) -> void:
	if value or _closing:
		Sound.play(&"ui_open" if value else &"ui_close")
	_closing = false
	overlay.visible = value
	if value:
		_slide.enter()
	else:
		_slide.stop()
	hud.visible = not selection.is_menu_open()
	hud_card.visible = hud.visible
	if not value:
		get_viewport().gui_release_focus()

func _other_menu(_value: bool) -> void:
	hud.visible = not selection.is_menu_open()
	hud_card.visible = hud.visible

func inspect(index: int) -> void:
	inspected = clampi(index, 0, rows.size() - 1)
	refresh()

func _track() -> void:
	model.track(String(model.catalog.steps[inspected].objective_id))

func _collapse() -> void:
	model.set_collapsed(not model.hud_collapsed)

func _claim_tracked() -> void:
	inspected = model.active_index()
	if inspected >= 0:
		_claim()

func _claim() -> void:
	var result: Dictionary = model.claim(model.catalog.steps[inspected].objective_id)
	Sound.result(result, &"reward_claim")
	_message = "Reward received: +%d coins" if result.ok else String(result.error)
	_reward = int(result.get("coins", 0))
	refresh()

func _restored() -> void:
	# Loading a ready save is not a new completion event.
	_ready_id = String(model.active().objective_id) if model.ready_to_claim() else ""
	_message = ""
	_completion.stop()
	selection.set_objectives_open(false)

func _status(index: int, data: Dictionary) -> String:
	if data.steps[index].claimed:
		return tr("Completed")
	if index != model.active_index():
		return tr("Locked")
	return tr("Ready to claim") if model.ready_to_claim() else tr("In progress")

func refresh() -> void:
	var data: Dictionary = model.capture()
	var ready_id: String = String(model.active().objective_id) if model.ready_to_claim() else ""
	if ready_id != _ready_id and not ready_id.is_empty():
		Sound.play(&"objective_complete")
		_message = "Objective complete! Open Objectives to claim your reward."
		_completion.start()
	_ready_id = ready_id
	heading.text = tr("Objectives") + "   %d / %d" % [model.active_index() if model.active_index() >= 0 else rows.size(), rows.size()]
	close_button.text = tr("Close")
	collapse_button.text = tr("Show") if model.hud_collapsed else tr("Hide")
	collapse_button.tooltip_text = tr("Expand objectives") if model.hud_collapsed else tr("Collapse objectives")
	hud_caption.text = tr("Objectives").to_upper()
	var tracked: int = model.tracked_index()
	hud_reward.visible = tracked >= 0 and not model.hud_collapsed
	hud_reward.text = tr("Reward: %d coins") % model.catalog.steps[tracked].reward_coins if tracked >= 0 else ""
	hud_claim.text = tr("Claim reward")
	hud_claim.visible = model.ready_to_claim() and not model.hud_collapsed
	hud_claim.disabled = not model.ready_to_claim()
	hud_button.text = tr("Objectives") if model.hud_collapsed or tracked < 0 else tr(model.catalog.steps[tracked].title) + "\n" + _status(tracked, data) + "  %d/%d" % [data.steps[tracked].progress, model.catalog.steps[tracked].required]
	hud_button.tooltip_text = tr("Objectives") + " [J]"
	if not ready_id.is_empty():
		hud_button.text = tr("Claim reward") + " [J]" if model.hud_collapsed else hud_button.text + "\n" + tr("Reward: %d coins") % model.active().reward_coins
	if tracked >= 0:
		hud_button.tooltip_text = tr(model.catalog.steps[tracked].title) + "\n" + tr(model.catalog.steps[tracked].description) + "\n[J] " + tr("Objectives")
		hud_progress.max_value = model.catalog.steps[tracked].required
		hud_progress.value = data.steps[tracked].progress
	hud_progress.visible = tracked >= 0 and not model.hud_collapsed
	for index: int in range(rows.size()):
		rows[index].text = "%d. %s\n%s" % [index + 1, tr(model.catalog.steps[index].title), _status(index, data)]
		rows[index].set_pressed_no_signal(index == inspected)
	var definition: ObjectiveDefinition = model.catalog.steps[inspected]
	detail.text = tr(definition.title) + "\n\n" + tr(definition.description) + "\n\n" + _status(inspected, data) + "  %d / %d\n" % [data.steps[inspected].progress, definition.required] + tr("Reward: %d coins") % definition.reward_coins
	track_button.text = tr("Tracking") if tracked == inspected else tr("Track objective")
	track_button.disabled = tracked == inspected
	claim_button.text = tr("Claim reward")
	claim_button.disabled = inspected != model.active_index() or not model.ready_to_claim()
	notice.text = tr(_message) % _reward if _message == "Reward received: +%d coins" else tr(_message)
	_fit()
