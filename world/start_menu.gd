extends Control
## Adapted from the Godot main_menu template; profile selection precedes world loading.
signal profile_requested(id: String, is_new: bool)
@export var navigate_on_launch: bool = true
@onready var card: PanelContainer = %Card
@onready var continue_button: Button = %Continue
@onready var new_button: Button = %NewGame
@onready var games_button: Button = %SavedGames
@onready var quit_button: Button = %Quit
@onready var farm_name: LineEdit = %FarmName
@onready var saves_list: VBoxContainer = %SavesList
@onready var status: Label = %Status
var _latest: String = ""
var _launching: bool = false
var _slide: Node

func _ready() -> void:
	continue_button.pressed.connect(_continue)
	new_button.pressed.connect(_new_game)
	games_button.pressed.connect(_saved_games)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	(%Create as Button).pressed.connect(_create)
	(%BackNew as Button).pressed.connect(_main)
	(%BackList as Button).pressed.connect(_main)
	farm_name.text_submitted.connect(func(_text: String) -> void: _create())
	resized.connect(_fit)
	_main()
	if not SaveManager.startup_error.is_empty():
		status.text = SaveManager.startup_error
		SaveManager.startup_error = ""
	_fit()
	_slide = preload("res://components/modal_slide.gd").new()
	add_child(_slide)
	_slide.configure(get_node("Center"), ^"position:y", get_node("Center") as Control)
	_slide.enter()

func _fit() -> void:
	var compact: bool = size.x < 900 or size.y < 560
	card.custom_minimum_size = Vector2(minf(920, maxf(0, size.x - 32)), minf(620, maxf(0, size.y - 24)))
	(%Artwork as VBoxContainer).visible = not compact
	(%Title as Label).add_theme_font_size_override("font_size", 30 if compact else 48)
	(%Subtitle as Label).visible = not compact
	(%Layout as VBoxContainer).add_theme_constant_override("separation", 8 if compact else 16)
	for button: Button in [continue_button, new_button, games_button, quit_button]:
		button.custom_minimum_size.y = 48 if compact else 58
		button.add_theme_font_size_override("font_size", 18 if compact else 24)

func _show(page: String) -> void:
	if _slide != null:
		_slide.enter()
	for child: Control in (%Pages as VBoxContainer).get_children():
		child.visible = child.name == page
	status.text = ""

func _main() -> void:
	_show("Home")
	_latest = SaveManager.profile_store().latest_profile()
	continue_button.disabled = _latest.is_empty()
	games_button.disabled = SaveManager.profile_store().list_profiles().is_empty()
	if continue_button.disabled:
		new_button.grab_focus()
	else:
		continue_button.grab_focus()

func _continue() -> void:
	if not _latest.is_empty():
		_launch(_latest, false)

func _new_game() -> void:
	_show("NewFarm")
	farm_name.text = ""
	farm_name.grab_focus()

func _create() -> void:
	if _launching:
		return
	var result: Dictionary = SaveManager.profile_store().create_profile(farm_name.text)
	if not result.ok:
		status.text = tr(String(result.error))
		return
	_launch(result.id, true)

func _saved_games() -> void:
	_show("FarmList")
	for child: Node in saves_list.get_children():
		child.free()
	var rows: Array[Dictionary] = SaveManager.profile_store().list_profiles()
	for row: Dictionary in rows:
		var button: Button = Button.new()
		var caption: String = tr("Existing farm") if row.legacy else String(row.name)
		if caption.is_empty():
			caption = String(row.id)
		var details: String = tr("Unable to read this save.")
		if row.valid:
			var date: String = Time.get_datetime_string_from_unix_time(int(row.last_played)).replace("T", " ")
			details = tr("{coins} coins · {columns} field columns").format({"coins": GameText.grouped_integer(row.coins), "columns": row.land_columns}) + "\n" + date + " UTC"
		button.text = caption + "\n" + details
		button.tooltip_text = button.text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = true
		button.custom_minimum_size.y = 96
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = not row.valid
		button.set_meta(&"profile_id", row.id)
		button.pressed.connect(_launch.bind(row.id, false))
		saves_list.add_child(button)
	(%Empty as Label).visible = rows.is_empty()
	(%BackList as Button).grab_focus()

func _launch(id: String, is_new: bool) -> void:
	if _launching:
		return
	if not SaveManager.select_profile(id, is_new):
		status.text = tr("Another farm is still open.")
		return
	_launching = true
	profile_requested.emit(id, is_new)
	if navigate_on_launch:
		var error: Error = get_tree().change_scene_to_file("res://world/loading_screen.tscn")
		if error != OK:
			_launching = false
			status.text = tr("Unable to open the farm.")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_main()
