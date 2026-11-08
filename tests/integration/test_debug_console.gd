extends GutTest
var world: FarmWorld
var commands: FarmDebugCommands
var old_clock: Callable
var old_floor: float

func before_each() -> void:
	old_clock = TimeManager.clock_source
	old_floor = TimeManager._last_timestamp
	TimeManager._last_timestamp = 1793500000.0
	TimeManager.clock_source = func() -> float: return 1793500000.0
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.player.wallet.set_balance(2000000)
	world.land.state.restore_blocks(12, 4)
	commands = (world.get_node("DebugConsole") as FarmDebugConsole).commands

func after_each() -> void:
	(world.get_node("DebugConsole") as FarmDebugConsole).set_open(false)
	TimeManager.clock_source = old_clock
	TimeManager._last_timestamp = old_floor

func run_command(line: String) -> Dictionary:
	var result: Dictionary = await commands.execute(line)
	assert_true(result.ok, line + ": " + str(result))
	return result

func test_parser_quotes_errors_registry_and_suggestions() -> void:
	assert_eq(DebugCommandRegistry.parse('/find item "carrot seed"').tokens, ["find", "item", "carrot seed"])
	for line: String in ["help", "/", '/find "open', "/give seed\\"]:
		assert_false(DebugCommandRegistry.parse(line).ok)
	assert_false((await commands.execute("/unknown")).ok)
	assert_string_contains((await run_command("/help")).text, "/animal")
	assert_true(commands.suggestions("/wor").has("/worker"))
	assert_true(commands.suggestions("/give carrot_s").has("/give carrot_seed"))
	assert_true(commands.suggestions("/worker upgrade sp").has("/worker upgrade speed"))
	assert_true(commands.suggestions("/animal spawn chi").has("/animal spawn chicken"))
	await run_command("/find crop carrot")
	await run_command("/find animal chicken")
	await run_command("/pos")
	await run_command("/inspect here")

func test_money_inventory_invalid_input_and_storage_are_atomic() -> void:
	await run_command("/money set 1000")
	await run_command("/money add 123")
	assert_eq(world.player.wallet.balance, 1123)
	for line: String in ["/money set -1", "/money add nan", "/money set 999999999999999999999", "/give missing 1", "/give carrot_seed -2", "/give carrot_seed 2 purple", "/storage add produce carrot_seed 2"]:
		assert_false((await commands.execute(line)).ok, line)
	assert_eq(world.player.wallet.balance, 1123)
	await run_command("/give carrot_seed 5")
	await run_command("/storage add supply animal_medicine 3")
	assert_eq(world.workers.feed_inventory("crop").count_item(&"animal_medicine"), 3)
	await run_command("/storage info supply")
	await run_command("/money get")
	commands.busy = true
	assert_false((await commands.execute("/money set 0")).ok)
	commands.busy = false
	assert_eq(world.player.wallet.balance, 1123)

func test_worker_cap_pause_resume_snapshots_and_upgrade_boundaries() -> void:
	for index: int in range(3): await run_command("/worker hire")
	assert_false((await commands.execute("/worker hire")).ok)
	await run_command("/worker list")
	await run_command("/worker info 1")
	await run_command("/worker target 1")
	await run_command("/worker pause 1")
	assert_false(world.workers.records[0].active)
	await run_command("/worker resume 1")
	assert_true(world.workers.records[0].active)
	await run_command("/worker pause all")
	await run_command("/worker resume all")
	var task: Dictionary = world.workers.records[0].task.duplicate(true)
	await run_command("/worker upgrade speed 10")
	assert_eq(world.workers.upgrades.level("speed"), 10)
	assert_eq(world.workers.records[0].task, task)
	assert_false((await commands.execute("/worker upgrade hoe 4")).ok)
	await run_command("/upgrade tool hoe 6")
	assert_eq(world.tool_upgrade_state.level(&"hoe"), 6)
	var id: String = String(world.workers.bridge.pens()[0].persistent_id)
	await run_command("/upgrade pen " + id + " 2")
	assert_eq(world.workers.bridge.pens()[0].capacity, 10)

func test_animal_commands_use_real_actors_and_roundtrip() -> void:
	await wait_physics_frames(3)
	await run_command("/animal spawn chicken 1")
	assert_eq(commands._animals().size(), 1)
	var animal: AnimalActor = commands._animals()[0]
	var id: String = String(animal.persistent_id)
	await run_command("/animal list chicken")
	await run_command("/animal info " + id)
	await run_command("/animal disease " + id + " on")
	assert_true(animal.health.sick)
	await run_command("/animal disease " + id + " off")
	assert_false(animal.health.sick)
	await run_command("/animal needs " + id + " food 22")
	assert_eq(animal.needs.satiety, 22.0)
	await run_command("/animal age " + id + " adult")
	assert_true(animal.growth.is_adult())
	await run_command("/animal age " + id + " young")
	assert_false(animal.growth.is_adult())
	assert_false((await commands.execute("/animal spawn chicken 31")).ok)
	var snapshot: Dictionary = WorldStateAdapter.new(world, commands.resources()).capture("debug_test", 1, TimeManager.now())
	assert_true(SaveSchema.validate(snapshot, commands.resources()).ok)

func test_crops_weather_objective_save_perf_and_time() -> void:
	world.farming.restore_soil([{"cell": [54, 24], "state": 1}])
	world.farming.restore_crop(Vector2i(54, 24), commands.resources().crops.carrot, TimeManager.now(), TimeManager.now() + 60, 0.0, TimeManager.now())
	await run_command("/crop info 54 24")
	await run_command("/crop water 54 24")
	await run_command("/crop disease pests 54 24")
	assert_true(world.farming.get_crop(Vector2i(54, 24)).conditions.pests)
	await run_command("/crop disease weeds 54 24")
	assert_true(world.farming.get_crop(Vector2i(54, 24)).conditions.pests)
	assert_true(world.farming.get_crop(Vector2i(54, 24)).conditions.weeds)
	await run_command("/crop disease clear all confirm")
	assert_false((await commands.execute("/crop grow all")).ok)
	await run_command("/crop grow all confirm")
	assert_true(world.farming.get_crop(Vector2i(54, 24)).is_mature())
	await run_command("/land unlock 24")
	await run_command("/weather set rain")
	await run_command("/weather auto")
	var timestamp: float = TimeManager.now()
	await run_command("/time hour 12")
	assert_eq(TimeManager.now(), timestamp)
	await run_command("/time hour auto")
	await run_command("/objective list")
	await run_command("/objective complete " + String(world.objectives.progress.active().objective_id))
	assert_true(world.objectives.progress.ready_to_claim())
	await run_command("/order list")
	await run_command("/perf on")
	await run_command("/perf snapshot")
	await run_command("/perf off")
	await run_command("/save status")
	var checked: Dictionary = await run_command("/save validate")
	assert_true(JSON.parse_string(checked.text).live_ok, checked.text)
	await run_command("/time advance 1 minute")
	assert_almost_eq(TimeManager.now(), timestamp + 60, 0.01)
	await run_command("/tp 800 300")
	assert_eq(world.player.global_position, Vector2(800, 300))
	await run_command("/tp workers")
	assert_false((await commands.execute("/tp nan 2")).ok)

func test_f1_escape_history_and_modal_keyboard() -> void:
	var console: FarmDebugConsole = world.get_node("DebugConsole") as FarmDebugConsole
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_F1
	key.pressed = true
	Input.parse_input_event(key)
	await wait_process_frames(2)
	assert_true(console.is_open)
	assert_true(get_tree().paused)
	assert_true(console.entry.has_focus())
	await console.submit("/money get")
	assert_string_contains(console.output.text, "/money get")
	await console.submit("/help")
	assert_string_contains(console.output.text, "/animal")
	key = InputEventKey.new()
	key.keycode = KEY_UP
	key.pressed = true
	Input.parse_input_event(key)
	await wait_process_frames(1)
	assert_eq(console.entry.text, "/help")
	key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await wait_process_frames(2)
	assert_false(console.is_open)
	assert_false(get_tree().paused)
