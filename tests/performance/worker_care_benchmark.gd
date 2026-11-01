extends Node
## Live rendered workload; never binds SaveManager or reads/writes a player save.
var world: FarmWorld
var reports: Array[Dictionary] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 144
	var preview: bool = OS.get_cmdline_user_args().has("badge_preview")
	var ui_review: bool = OS.get_cmdline_user_args().has("ui_review")
	var scenarios: Array[String] = ["baseline", "missing_supplies", "care_supplied"]
	if preview or ui_review:
		scenarios.assign(["missing_supplies"])
	for scenario: String in scenarios:
		await _case(scenario)
	var output: String = "res://docs/worker_badge_preview.json" if preview else "res://docs/worker_care_benchmark_2026-11-01.json"
	if ui_review:
		output = "res://docs/ui_completion_worker_benchmark.json"
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "display": DisplayServer.get_name(), "save_bound": (get_tree().root.get_node("SaveManager") as GameSaveManager).adapter != null, "seconds_per_case": 20, "scenarios": reports}, "\t"))
	get_tree().quit()

func _case(scenario: String) -> void:
	var clock: FarmClock = get_tree().root.get_node("TimeManager") as FarmClock
	var start_clock: int = Time.get_ticks_usec()
	clock._last_timestamp = 1793500000.0
	clock.clock_source = func() -> float: return 1793500000.0 + float(Time.get_ticks_usec() - start_clock) / 1000000.0
	clock.set_process(true)
	world = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	get_tree().root.add_child(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(16, 8)
	world.player.wallet.set_balance(10000000)
	world.trees.reset()
	var now: float = clock.now()
	var soil: Array = []
	for y: int in range(22, 30):
		for x: int in range(47, 55):
			soil.append({"cell": [x, y], "state": 1})
	world.farming.restore_soil(soil)
	for y: int in range(22, 30):
		for x: int in range(47, 55):
			var cell: Vector2i = Vector2i(x, y)
			world.farming.restore_crop(cell, preload("res://crops/field/wheat/wheat.tres"), now, now + 10000, 0, now)
			var crop: Crop = world.farming.get_crop(cell)
			crop.conditions.weeds = true
			crop.conditions.pests = true
			crop.refresh(now)
	var sick: Array[AnimalActor] = []
	for pen: AnimalPen in world.workers.bridge.pens():
		for child: Node in pen.get_children():
			if child is AnimalTrough:
				child.stock = child.capacity
		if sick.size() < 3:
			var animal: AnimalActor = preload("res://scenes/animals/chicken.tscn").instantiate() as AnimalActor
			animal.position = pen.bounds.get_center()
			pen.add_child(animal)
			animal.health.sick = true
			sick.append(animal)
	var service: WorkerService = world.workers
	var bag: InventoryComponent = service.feed_inventory("crop")
	if scenario == "care_supplied":
		bag.add(WorkerWorldBridge.HERBICIDE, 80)
		bag.add(WorkerWorldBridge.PESTICIDE, 80)
		bag.add(WorkerWorldBridge.ANIMAL_MEDICINE, 10)
	var origins: Dictionary = {}
	if scenario != "baseline":
		for index: int in range(15):
			assert(service.hire("crop").is_empty())
			var row: Dictionary = service.records[index]
			var worker: WorkerActor = service.actor_for(String(row.id))
			if index < 3:
				worker.global_position = sick[index].global_position + Vector2(0, 45)
			else:
				worker.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(Vector2i(51 + index % 4, 26)))
			row.position = WorkerRole.pair(worker.global_position)
			origins[String(row.id)] = worker.global_position
		service.configure_crop(false, false, false)
	world.player.global_position = world.farming.farmland.to_global(world.farming.farmland.map_to_local(Vector2i(53, 23)))
	world.player.camera.reset_smoothing()
	var timings: Array[float] = []
	var actions_seen: Dictionary = {}
	var treated: Dictionary = {"treat_pests": 0, "clear_weeds": 0}
	world.farming.action_committed.connect(func(kind: StringName, amount: int) -> void:
		if treated.has(String(kind)):
			treated[String(kind)] += amount)
	var started: int = Time.get_ticks_usec()
	var last: int = started
	var captured: bool = false
	while Time.get_ticks_usec() - started < 20000000:
		await get_tree().process_frame
		var current: int = Time.get_ticks_usec()
		timings.append(float(current - last) / 1000.0)
		last = current
		for worker: WorkerActor in service.actors.values():
			if worker.care_action.visible:
				actions_seen[worker.care_action.kind] = true
		if not captured and current - started > 5000000 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var capture_prefix: String = "ui_completion_worker_" if OS.get_cmdline_user_args().has("ui_review") else "worker_care_"
			get_viewport().get_texture().get_image().save_png("res://docs/" + capture_prefix + scenario + ".png")
			captured = true
	var moved: int = 0
	for id: String in origins:
		if service.actor_for(id).global_position.distance_to(origins[id]) > 10:
			moved += 1
	var cured: int = 0
	for animal: AnimalActor in sick:
		if not animal.health.sick:
			cured += 1
	timings.sort()
	var total: float = 0.0
	for value: float in timings:
		total += value
	var report: Dictionary = {"scenario": scenario, "crop_count": world.farming.crop_cells().size(), "frames": timings.size(), "fps": timings.size() * 1000.0 / maxf(1, total), "p95_ms": timings[int(timings.size() * 0.95)], "worst_ms": timings[-1], "moved": moved, "actions_seen": actions_seen.keys(), "treated": treated, "cured": cured}
	reports.append(report)
	print("CARE_BENCHMARK ", JSON.stringify(report))
	world.queue_free()
	await get_tree().process_frame
