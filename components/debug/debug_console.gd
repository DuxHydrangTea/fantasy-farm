class_name FarmDebugConsole
extends CanvasLayer
## F1 modal; tree pause stops gameplay hotkeys, while this layer remains active.
var world: FarmWorld
var commands: FarmDebugCommands
var panel: PanelContainer
var output: RichTextLabel
var entry: LineEdit
var hints: Label
var perf: Label
var history: Array[String] = []
var history_index: int = 0
var draft: String = ""
var is_open: bool = false
var previous_pause: bool = false
var perf_enabled: bool = false
var elapsed: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	commands = FarmDebugCommands.new(world)
	commands.clear_requested.connect(func() -> void: output.clear())
	commands.perf_changed.connect(func(enabled: bool) -> void:
		perf_enabled = enabled
		perf.visible = enabled)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)
	var rows: VBoxContainer = VBoxContainer.new()
	panel.add_child(rows)
	var title: Label = Label.new()
	title.text = "DEBUG CONSOLE · F1 / Esc close · ↑ ↓ history · Tab complete"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(title)
	output = RichTextLabel.new()
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.selection_enabled = true
	output.scroll_following = true
	output.add_theme_color_override("default_color", Color("493121"))
	output.add_theme_font_size_override("normal_font_size", 16)
	rows.add_child(output)
	hints = Label.new()
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(hints)
	entry = LineEdit.new()
	entry.custom_minimum_size.y = 48
	entry.placeholder_text = "/help"
	entry.max_length = 1024
	rows.add_child(entry)
	entry.text_submitted.connect(submit)
	entry.text_changed.connect(_suggest)
	perf = Label.new()
	perf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(perf)
	perf.hide()
	panel.hide()
	_write("Debug changes affect the current farm and may be autosaved. Use /help.\n")

func _write(text: String) -> void:
	var content: String = output.text + text
	output.text = content.right(48000) if content.length() > 64000 else content

func set_open(value: bool) -> void:
	if value == is_open or (commands.busy and not value): return
	if value and world.player.selection.is_menu_open(): return
	is_open = value
	panel.visible = value
	if value:
		previous_pause = get_tree().paused
		get_tree().paused = true
		world.player.velocity = Vector2.ZERO
		entry.grab_focus()
	else:
		entry.release_focus()
		get_tree().paused = previous_pause

func _exit_tree() -> void:
	if is_open: get_tree().paused = previous_pause

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F1 or event.physical_keycode == KEY_F1:
		set_open(not is_open)
		get_viewport().set_input_as_handled()
		return
	if not is_open: return
	if event.keycode == KEY_ESCAPE:
		set_open(false)
	elif event.keycode in [KEY_UP, KEY_DOWN]:
		if history_index == history.size(): draft = entry.text
		history_index = clampi(history_index + (-1 if event.keycode == KEY_UP else 1), 0, history.size())
		entry.text = history[history_index] if history_index < history.size() else draft
		entry.caret_column = entry.text.length()
	elif event.keycode == KEY_TAB:
		var matches: Array[String] = commands.suggestions(entry.text)
		if not matches.is_empty():
			entry.text = matches[0] + (" " if matches.size() == 1 else "")
			entry.caret_column = entry.text.length()
	else: return
	get_viewport().set_input_as_handled()

func _suggest(text: String) -> void:
	hints.text = "  ·  ".join(commands.suggestions(text).slice(0, 5)) if not text.is_empty() else ""

func submit(line: String) -> void:
	if commands.busy or line.strip_edges().is_empty(): return
	if history.is_empty() or history.back() != line: history.append(line)
	if history.size() > 100: history.pop_front()
	history_index = history.size()
	draft = ""
	entry.clear()
	hints.text = "Working…"
	entry.editable = false
	_write("> " + line + "\n")
	var result: Dictionary = await commands.execute(line)
	if not is_inside_tree(): return
	_write((str(result.get("text", "")) if result.ok else "ERROR: " + str(result.error)) + "\n")
	entry.editable = true
	hints.text = ""
	if is_open: entry.grab_focus()

func _process(delta: float) -> void:
	if not perf_enabled: return
	elapsed += delta
	if elapsed < 0.5: return
	elapsed = 0.0
	perf.text = "FPS %d · process %.2f ms · physics %.2f ms · workers %d · scheduler %.2f ms total · navigation %.2f ms total" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000, world.workers.actors.size(), world.workers.scheduler_usec / 1000.0, world.workers.navigation.profile_usec / 1000.0]
