class_name HelpUI
extends TradeMenu
## Container-based help adapted from the skill HUD/menu templates.
var world: FarmWorld
var support: StarterSupport
var panel: PanelContainer
var heading: Label
var topics: Array[Button] = []
var content: Label
var content_scroll: ScrollContainer
var topic_scroll: ScrollContainer
var toggle_button: Button
var skip_button: Button
var support_button: Button
var status: Label
var selected_topic: int = 0
var _message: String = ""

func _ready() -> void:
	layer = 26
	support = StarterSupport.new(world)
	_build()
	super._ready()
	visit_started.connect(_visit)
	models_changed.connect(_refresh)
	world.tutorial.changed.connect(_refresh)
	world.objectives.progress.changed.connect(_refresh)
	root.resized.connect(_fit)
	_fit()

func _button(parent: Node, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build() -> void:
	root = Control.new()
	root.theme = preload("res://resources/ui/game_theme.tres")
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.06, 0.8)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	var style: StyleBox = root.theme.get_stylebox(&"panel", &"PanelContainer").duplicate() as StyleBox
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(edge, 12)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	body.add_child(header)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 20)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	close_button = _button(header, func() -> void: pass)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	body.add_child(columns)
	topic_scroll = ScrollContainer.new()
	topic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	topic_scroll.follow_focus = true
	topic_scroll.custom_minimum_size.x = 164
	columns.add_child(topic_scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topic_scroll.add_child(list)
	for index: int in range(GuideContent.TOPICS.size()):
		var button: Button = _button(list, _select.bind(index))
		button.clip_text = true
		button.toggle_mode = true
		topics.append(button)
	content_scroll = ScrollContainer.new()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(content_scroll)
	content = Label.new()
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_font_size_override("font_size", 16)
	content_scroll.add_child(content)
	support_button = _button(body, _support)
	var footer: HBoxContainer = HBoxContainer.new()
	body.add_child(footer)
	toggle_button = _button(footer, _toggle)
	toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip_button = _button(footer, _skip)
	skip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var status_scroll: ScrollContainer = ScrollContainer.new()
	status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	status_scroll.custom_minimum_size.y = 40
	body.add_child(status_scroll)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 14)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_scroll.add_child(status)

func _fit() -> void:
	panel.size = Vector2(minf(960, root.size.x - 16), minf(640, root.size.y - 16))
	panel.position = (root.size - panel.size) * 0.5
	if is_open:
		content.text = GuideContent.topic(selected_topic, world.objectives.progress, MobileLayout.is_touch(get_viewport()))

func open_help() -> void:
	open(null, world.player)

func _visit() -> void:
	topic_scroll.scroll_vertical = 0
	_select(0)
	close_button.grab_focus()

func _select(index: int) -> void:
	selected_topic = index
	_message = ""
	content_scroll.scroll_vertical = 0
	if index == 0 and world.objectives.progress.active() != null:
		world.tutorial.mark_seen(String(world.objectives.progress.active().objective_id))
	_refresh()

func _toggle() -> void:
	world.tutorial.set_enabled(not bool(world.tutorial.capture().enabled))

func _skip() -> void:
	world.tutorial.skip()
	_message = "Hints skipped. Objectives and rewards stay unchanged."
	_refresh()

func _support() -> void:
	var result: Dictionary = support.claim()
	_message = "Received one carrot seed. Deposit it at supply storage, choose Stored seeds, then plant, water and sell the harvest." if result.ok else String(result.error)
	_refresh()

func _refresh() -> void:
	if not is_open:
		return
	heading.text = tr("Help")
	close_button.text = tr("Close")
	for index: int in range(topics.size()):
		topics[index].text = tr(GuideContent.TOPICS[index])
		topics[index].set_pressed_no_signal(index == selected_topic)
	var data: Dictionary = world.tutorial.capture()
	toggle_button.text = tr("Hints: On") if data.enabled else tr("Hints: Off")
	skip_button.text = tr("Skip hints")
	skip_button.disabled = data.skipped
	support_button.visible = selected_topic == 5
	support_button.text = tr("Request one carrot seed")
	var quoted: Dictionary = support.quote()
	support_button.disabled = not quoted.ok
	status.text = tr(_message) if not _message.is_empty() else tr(String(quoted.error)) if selected_topic == 5 and not quoted.ok else ""
	_fit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		if is_open:
			close()
		else:
			open_help()
		get_viewport().set_input_as_handled()
		return
	super._input(event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()
