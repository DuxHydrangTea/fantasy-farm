extends GutTest
const MENU: PackedScene = preload("res://world/start_menu.tscn")
const Profiles = preload("res://persistence/game_profiles.gd")
var viewport: SubViewport
var menu: Control
var old_directory: String
var old_clock: Callable
var old_floor: float
var folder: String

func before_each() -> void:
	old_directory = SaveManager.local_directory
	old_clock = TimeManager.clock_source
	old_floor = TimeManager._last_timestamp
	folder = "user://menu_test_" + Crypto.new().generate_random_bytes(8).hex_encode()
	SaveManager.local_directory = folder
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child_autofree(viewport)

func after_each() -> void:
	SaveManager.local_directory = old_directory
	SaveManager.selected_profile_id = "local"
	SaveManager.pending_new_profile = false
	SaveManager._require_existing_profile = false
	TimeManager.use_wall_clock(old_floor)
	TimeManager.clock_source = old_clock
	Language.set_language("en")
	if DirAccess.dir_exists_absolute(folder):
		for filename: String in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)

func _open() -> void:
	menu = MENU.instantiate() as Control
	menu.set("navigate_on_launch", false)
	viewport.add_child(menu)

func test_first_launch_has_four_buttons_and_creates_named_profile_without_loading_world() -> void:
	_open()
	assert_true((menu.get_node("%Continue") as Button).disabled)
	assert_false((menu.get_node("%NewGame") as Button).disabled)
	assert_true((menu.get_node("%Quit") as Button).visible)
	menu.call("_new_game")
	menu.call("_create")
	assert_false((menu.get_node("%Status") as Label).text.is_empty())
	(menu.get_node("%FarmName") as LineEdit).text = "Farm A"
	var events: Array = []
	menu.connect("profile_requested", func(id: String, is_new: bool) -> void: events.append([id, is_new]))
	menu.call("_create")
	assert_eq(events.size(), 1)
	assert_true(events[0][1])
	assert_eq(SaveManager.selected_profile_id, events[0][0])
	assert_true(SaveManager.pending_new_profile)
	assert_null(SaveManager.adapter, "Title screen must not instantiate/bind a farm")

func test_menu_pages_and_actions_fit_small_and_large_viewports_in_both_languages() -> void:
	_open()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(667, 375), Vector2i(480, 640)]:
		viewport.size = size
		for language: String in ["en", "vi"]:
			Language.set_language(language)
			for method: String in ["_main", "_new_game", "_saved_games"]:
				menu.call(method)
				await wait_process_frames(5)
				var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(size)).grow(1)
				assert_true(bounds.encloses((menu.get_node("%Card") as Control).get_global_rect()), "%s %s %s" % [size, language, method])
				for control: Control in menu.find_children("*", "Button", true, false):
					if control.is_visible_in_tree():
						assert_true(bounds.encloses(control.get_global_rect()), control.name)
