class_name FarmUI
extends RefCounted
## Shared presentation tokens; cached per source skin, never edits a theme asset.
const INK: Color = Color("402919")
const MUTED: Color = Color("80664b")
const GOOD: Color = Color("456338")
const WARNING: Color = Color("985021")
static var _themes: Dictionary = {}
static var ui_scale: float = 1.0
static var master_volume: float = 1.0
static var language: String = "vi"
static var _preferences_loaded: bool = false
const PREFERENCES: String = "user://ui_preferences.cfg"

static func load_preferences() -> void:
	if _preferences_loaded:
		return
	_preferences_loaded = true
	var config: ConfigFile = ConfigFile.new()
	if config.load(PREFERENCES) != OK:
		return
	ui_scale = clampf(float(config.get_value("ui", "scale", 1.0)), 1.0, 1.5)
	master_volume = clampf(float(config.get_value("audio", "master", 1.0)), 0.0, 1.0)
	var locale: String = String(config.get_value("ui", "language", "vi"))
	language = locale if locale in ["en", "vi"] else "vi"

static func save_preferences(path: String = PREFERENCES) -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("ui", "scale", ui_scale)
	config.set_value("ui", "language", TranslationServer.get_locale())
	config.set_value("audio", "master", master_volume)
	return config.save(path)

static func apply(root: Control) -> void:
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var source: Theme = root.theme if root.theme != null else preload("res://resources/ui/game_theme.tres")
	var key: int = source.get_instance_id()
	if not _themes.has(key):
		var skin: Theme = source.duplicate() as Theme
		_cozy_theme(skin)
		skin.default_font_size = 18
		skin.set_constant("separation", "VBoxContainer", 8)
		skin.set_constant("separation", "HBoxContainer", 8)
		skin.set_constant("h_separation", "GridContainer", 8)
		skin.set_constant("v_separation", "GridContainer", 8)
		skin.set_color("font_color", "Label", INK)
		skin.set_color("font_color", "Button", INK)
		skin.set_color("font_disabled_color", "Button", MUTED)
		var focus: StyleBoxFlat = StyleBoxFlat.new()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = GOOD
		focus.set_corner_radius_all(8)
		focus.set_border_width_all(2)
		skin.set_stylebox("focus", "Button", focus)
		skin.set_stylebox("focus", "PrimaryAction", focus)
		var field: StyleBox = box(Color("f2e9d6"), 8, 10)
		var selected_field: StyleBox = box(Color("e6edd9"), 8, 10, GOOD)
		skin.set_stylebox("normal", "LineEdit", field)
		skin.set_stylebox("read_only", "LineEdit", field)
		skin.set_stylebox("focus", "LineEdit", focus)
		skin.set_color("font_color", "LineEdit", INK)
		skin.set_color("font_placeholder_color", "LineEdit", MUTED)
		skin.set_color("caret_color", "LineEdit", INK)
		for state: String in ["normal", "disabled", "hover", "pressed"]:
			skin.set_stylebox(state, "OptionButton", selected_field if state in ["hover", "pressed"] else field)
		skin.set_stylebox("focus", "OptionButton", focus)
		for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			skin.set_color(color, "OptionButton", INK)
		skin.set_color("font_disabled_color", "OptionButton", MUTED)
		skin.set_constant("modulate_arrow", "OptionButton", 1)
		skin.set_stylebox("panel", "PopupMenu", field)
		skin.set_stylebox("hover", "PopupMenu", selected_field)
		skin.set_color("font_color", "PopupMenu", INK)
		skin.set_color("font_hover_color", "PopupMenu", INK)
		skin.set_color("font_disabled_color", "PopupMenu", MUTED)
		var track: StyleBoxFlat = StyleBoxFlat.new()
		track.bg_color = Color("b5986d")
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		skin.set_stylebox("slider", "HSlider", track)
		var fill: StyleBoxFlat = track.duplicate() as StyleBoxFlat
		fill.bg_color = GOOD
		skin.set_stylebox("grabber_area", "HSlider", fill)
		skin.set_stylebox("grabber_area_highlight", "HSlider", fill)
		var tooltip: StyleBox = box(Color("fff8e9"), 10, 12)
		for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			tooltip.set_content_margin(side, 12)
		skin.set_stylebox("panel", "TooltipPanel", tooltip)
		skin.set_color("font_color", "TooltipLabel", INK)
		skin.set_font_size("font_size", "TooltipLabel", 16)
		_themes[key] = skin
	root.theme = _themes[key] as Theme

static func compact_number(value: int) -> String:
	if value < 1000000:
		return GameText.grouped_integer(value)
	var divisor: float = 1000000000.0 if value >= 1000000000 else 1000000.0
	var suffix: String = "B" if value >= 1000000000 else "M"
	var number: String = "%.1f" % (floorf(float(value) / divisor * 10.0) / 10.0)
	if number.ends_with(".0"):
		number = number.trim_suffix(".0")
	if TranslationServer.get_locale().begins_with("vi"):
		number = number.replace(".", ",")
	return number + suffix

## Vector geometry stays sharp at every UI scale; sprites keep nearest filtering.
static func box(color: Color, radius: int = 14, padding: int = 16, border: Color = Color("dccba9")) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.corner_detail = 12
	for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(edge, padding)
	return style

static func _cozy_theme(skin: Theme) -> void:
	var font: Font = preload("res://resources/ui/game_font.tres")
	skin.default_font = font
	for type: String in ["Label", "Button", "LineEdit", "OptionButton", "PopupMenu", "RichTextLabel"]:
		skin.set_font("font", type, font)
		for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			skin.set_color(color, type, INK)
		skin.set_color("font_shadow_color", type, Color.TRANSPARENT)
		skin.set_color("font_outline_color", type, Color.TRANSPARENT)
		skin.set_constant("outline_size", type, 0)
	var paper: StyleBoxFlat = box(Color("fff8e9"), 18, 12)
	paper.shadow_color = Color(0.16, 0.12, 0.06, 0.18)
	paper.shadow_size = 4
	paper.shadow_offset = Vector2(0, 3)
	skin.set_stylebox("panel", "PanelContainer", paper)
	for variant: String in ["HotbarPanel", "WalletPanel", "WeatherPanel", "DetailCard"]:
		skin.set_type_variation(variant, "PanelContainer")
		var style: StyleBoxFlat = paper.duplicate() as StyleBoxFlat
		style.set_corner_radius_all(32 if variant == "WeatherPanel" else 18 if variant == "HotbarPanel" else 12)
		if variant == "DetailCard":
			style.bg_color = Color("f2e9d6")
			for edge: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				style.set_content_margin(edge, 8)
			style.shadow_size = 0
		skin.set_stylebox("panel", variant, style)
	for state: String in ["normal", "disabled", "hover", "pressed", "hover_pressed"]:
		var active: bool = state in ["pressed", "hover_pressed"]
		skin.set_stylebox(state, "Button", box(Color("e6edd9") if active else Color("e5ecd8") if state == "hover" else Color("f2e9d6"), 8, 4, GOOD if active else Color("dccba9")))
	skin.set_type_variation("PrimaryAction", "Button")
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		skin.set_stylebox(state, "PrimaryAction", box(Color("789057") if state == "hover" else Color("647e48"), 9, 10, GOOD))
		var color_name: String = "font_color" if state == "normal" else "font_" + state + "_color"
		skin.set_color(color_name, "PrimaryAction", Color("fff8e9"))

static func speech(panel: PanelContainer) -> void:
	apply(panel)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", box(Color("fff8e9"), 10, 8))
	var tail: Polygon2D = Polygon2D.new()
	tail.name = "SpeechTail"
	tail.color = Color("fff8e9")
	panel.add_child(tail)
	var place_tail: Callable = func() -> void:
		var center: float = panel.size.x * 0.5
		tail.polygon = PackedVector2Array([Vector2(center - 5, panel.size.y - 1), Vector2(center, panel.size.y + 5), Vector2(center + 5, panel.size.y - 1)])
	panel.resized.connect(place_tail)
	place_tail.call()
