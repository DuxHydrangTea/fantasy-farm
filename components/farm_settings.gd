extends TradeMenu
## Widget sync and ConfigFile persistence follow the Godot settings-menu template.
var player: FarmPlayer
var panel: PanelContainer
var language_choice: OptionButton
var size_choice: OptionButton
var volume: HSlider
var volume_label: Label
var audio_sliders: Dictionary[StringName, HSlider] = {}
var audio_labels: Dictionary[StringName, Label] = {}
const AUDIO_CAPTIONS: Dictionary = {&"effects": "Effects volume: {value}%", &"interface": "Interface sounds: {value}%", &"ambience": "Ambience volume: {value}%", &"music": "Music volume: {value}%"}
var heading: Label
var language_label: Label
var size_label: Label
var status: Label
var _syncing: bool = false
var _save_timer: Timer
var _dirty: bool = false
var preferences_path: String = FarmUI.PREFERENCES

func _ready() -> void:
	layer = 30
	root = Control.new()
	root.theme = preload("res://resources/ui/cozy_hud/inventory_theme.tres")
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.04, 0.03, 0.02, 0.45)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	center.add_child(panel)
	var shell: VBoxContainer = VBoxContainer.new()
	panel.add_child(shell)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(scroll)
	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var header: HBoxContainer = HBoxContainer.new()
	shell.add_child(header)
	shell.move_child(header, 0)
	heading = Label.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 24)
	header.add_child(heading)
	close_button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(48, 48)
	header.add_child(close_button)
	language_label = Label.new()
	body.add_child(language_label)
	language_choice = OptionButton.new()
	language_choice.custom_minimum_size.y = 40
	language_choice.add_item("Tiếng Việt")
	language_choice.add_item("English")
	language_choice.item_selected.connect(_language_changed)
	body.add_child(language_choice)
	size_label = Label.new()
	body.add_child(size_label)
	size_choice = OptionButton.new()
	size_choice.custom_minimum_size.y = 40
	for caption: String in ["100%", "125%", "150%"]:
		size_choice.add_item(caption)
	size_choice.item_selected.connect(_size_changed)
	body.add_child(size_choice)
	volume_label = Label.new()
	body.add_child(volume_label)
	volume = HSlider.new()
	volume.max_value = 100
	volume.step = 1
	volume.custom_minimum_size.y = 32
	volume.value_changed.connect(_volume_changed)
	body.add_child(volume)
	for key: StringName in AUDIO_CAPTIONS:
		var caption: Label = Label.new()
		body.add_child(caption)
		audio_labels[key] = caption
		var slider: HSlider = HSlider.new()
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size.y = 48
		slider.value_changed.connect(_audio_changed.bind(key))
		body.add_child(slider)
		audio_sliders[key] = slider
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 14)
	body.add_child(status)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.timeout.connect(_persist)
	add_child(_save_timer)
	super._ready()
	root.resized.connect(_fit)
	_sync()
	_fit()
	_apply_volume()

func show_settings() -> void:
	if player.selection.is_menu_open():
		return
	_sync()
	status.text = ""
	super.open(null, player)
	language_choice.grab_focus()

func _fit() -> void:
	panel.custom_minimum_size.x = minf(460, maxf(280, root.size.x - 32))
	panel.custom_minimum_size.y = minf(440, root.size.y - 32)

func _sync() -> void:
	_syncing = true
	language_choice.select(1 if TranslationServer.get_locale().begins_with("en") else 0)
	size_choice.select(clampi(roundi((FarmUI.ui_scale - 1.0) / 0.25), 0, 2))
	volume.set_value_no_signal(FarmUI.master_volume * 100)
	heading.text = tr("Settings")
	language_label.text = tr("Language")
	size_label.text = tr("Interface size")
	volume_label.text = tr("Master volume: {value}%").format({"value": roundi(FarmUI.master_volume * 100)})
	var levels: Dictionary = {&"effects": FarmUI.effects_volume, &"interface": FarmUI.interface_volume, &"ambience": FarmUI.ambience_volume, &"music": FarmUI.music_volume}
	for key: StringName in audio_sliders:
		audio_sliders[key].set_value_no_signal(float(levels[key]) * 100.0)
		audio_labels[key].text = tr(String(AUDIO_CAPTIONS[key])).format({"value": roundi(float(levels[key]) * 100.0)})
	_syncing = false

func _language_changed(index: int) -> void:
	if _syncing:
		return
	Language.set_language("vi" if index == 0 else "en")
	_store()

func _size_changed(index: int) -> void:
	if _syncing:
		return
	FarmUI.ui_scale = 1.0 + clampi(index, 0, 2) * 0.25
	get_tree().call_group(&"ui_scales", "refresh")
	_store()

func _volume_changed(value: float) -> void:
	if _syncing:
		return
	FarmUI.master_volume = value / 100.0
	_apply_volume()
	_sync()
	_store()

func _apply_volume() -> void:
	Sound.apply_volumes()

func _audio_changed(value: float, key: StringName) -> void:
	if _syncing:
		return
	match key:
		&"effects": FarmUI.effects_volume = value / 100.0
		&"interface": FarmUI.interface_volume = value / 100.0
		&"ambience": FarmUI.ambience_volume = value / 100.0
		&"music": FarmUI.music_volume = value / 100.0
	_apply_volume()
	_sync()
	_store()

func _store() -> void:
	_dirty = true
	_save_timer.start(0.35)

func _persist() -> void:
	if not _dirty:
		return
	status.text = "" if FarmUI.save_preferences(preferences_path) == OK else tr("Could not save settings.")
	_dirty = not status.text.is_empty()

func _finish_close(show_thanks: bool) -> void:
	_save_timer.stop()
	_persist()
	super._finish_close(show_thanks)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_sync()
