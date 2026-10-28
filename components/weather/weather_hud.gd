class_name WeatherHUD
extends CanvasLayer
var manager: WeatherManager
var label: Label
var debug_bar: PanelContainer
var debug_toggle: Button
var time_buttons: Array[Button] = []
var weather_buttons: Array[Button] = []
var _debug_title: Label
var _time_title: Label
var _weather_title: Label
var _last_timestamp: float = 0.0

func _ready() -> void:
	layer = 11
	var root: Control = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)
	UIScaleComponent.attach(self, root)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.position = Vector2(16, 16)
	root.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme = preload("res://resources/ui/cozy_hud/theme.tres")
	panel.theme_type_variation = &"WeatherPanel"
	column.add_child(panel)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 20)
	panel.add_child(label)
	if OS.is_debug_build() and not MobileLayout.is_touch(get_viewport()):
		_build_debug_bar(column, panel.theme)

func _build_debug_bar(column: VBoxContainer, theme: Theme) -> void:
	debug_toggle = Button.new()
	debug_toggle.name = "DebugToggle"
	debug_toggle.theme = theme
	debug_toggle.toggle_mode = true
	debug_toggle.focus_mode = Control.FOCUS_NONE
	debug_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	debug_toggle.custom_minimum_size.y = 30
	debug_toggle.toggled.connect(_toggle_debug_panel)
	column.add_child(debug_toggle)
	debug_bar = PanelContainer.new()
	debug_bar.name = "DebugPanel"
	debug_bar.theme = theme
	debug_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	debug_bar.hide()
	var style: StyleBoxTexture = theme.get_stylebox("panel", "PanelContainer").duplicate() as StyleBoxTexture
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	debug_bar.add_theme_stylebox_override("panel", style)
	column.add_child(debug_bar)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	debug_bar.add_child(rows)
	_debug_title = Label.new()
	_debug_title.add_theme_font_size_override("font_size", 18)
	rows.add_child(_debug_title)
	_time_title = _group_title(rows)
	var time_row: HBoxContainer = HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 4)
	rows.add_child(time_row)
	for hour: int in [12, 23, -1]:
		var button: Button = _debug_button(time_row)
		button.pressed.connect(manager.set_debug_hour.bind(hour))
		time_buttons.append(button)
	_weather_title = _group_title(rows)
	var weather_row: HBoxContainer = HBoxContainer.new()
	weather_row.add_theme_constant_override("separation", 4)
	rows.add_child(weather_row)
	for kind: int in range(4):
		var button: Button = _debug_button(weather_row)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_weather.bind(kind))
		weather_buttons.append(button)
	_refresh_debug_bar()

func _group_title(rows: VBoxContainer) -> Label:
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 14)
	rows.add_child(title)
	return title

func _toggle_debug_panel(open: bool) -> void:
	debug_bar.visible = open and not MobileLayout.is_touch(get_viewport())

func _select_weather(kind: WeatherSchedule.Weather) -> void:
	manager.set_weather(kind)
	_refresh_debug_bar()

func _debug_button(row: HBoxContainer) -> Button:
	var button: Button = Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 30
	button.add_theme_font_size_override("font_size", 16)
	row.add_child(button)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBox = button.get_theme_stylebox(state).duplicate() as StyleBox
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 4
		style.content_margin_bottom = 6
		button.add_theme_stylebox_override(state, style)
	return button

func _refresh_debug_bar() -> void:
	if debug_bar == null:
		return
	debug_toggle.visible = not MobileLayout.is_touch(get_viewport())
	debug_bar.visible = debug_toggle.visible and debug_toggle.button_pressed
	debug_toggle.text = tr("Debug tools")
	_debug_title.text = tr("Debug tools")
	_time_title.text = tr("Day and night")
	_weather_title.text = tr("Weather")
	var times: Array[String] = [tr("Day"), tr("Night"), tr("Live time")]
	var hours: Array[int] = [12, 23, -1]
	for index: int in range(time_buttons.size()):
		time_buttons[index].text = times[index]
		time_buttons[index].set_pressed_no_signal(manager.debug_hour == hours[index])
	var titles: Array[String] = [tr("Sunny"), tr("Rainy"), tr("Cloudy"), tr("Windy")]
	for kind: int in range(weather_buttons.size()):
		weather_buttons[kind].text = titles[kind]
		weather_buttons[kind].set_pressed_no_signal(manager.current_weather == kind)

func refresh(timestamp: float) -> void:
	_last_timestamp = timestamp
	var minutes: int = floori(fposmod(timestamp + WeatherSchedule.UTC_OFFSET, 86400.0) / 60.0)
	var titles: Array[String] = [tr("Sunny"), tr("Rainy"), tr("Cloudy"), tr("Windy")]
	label.text = "%02d:%02d · %s" % [minutes / 60, minutes % 60, titles[manager.current_weather]]
	_refresh_debug_bar()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh(_last_timestamp)
