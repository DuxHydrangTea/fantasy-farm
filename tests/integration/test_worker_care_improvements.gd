extends GutTest
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld
var now: float = 1793500000.0
var old_source: Callable
var old_floor: float
var old_processing: bool

func before_each() -> void:
	old_source = TimeManager.clock_source
	old_floor = TimeManager._last_timestamp
	old_processing = TimeManager.is_processing()
	TimeManager.set_process(false)
	TimeManager._last_timestamp = now
	TimeManager.clock_source = func() -> float: return now
	world = WORLD.instantiate() as FarmWorld
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(world)
	world.tool_upgrades.profile_ready = true
	world.land.state.restore_columns(16, 8)
	world.player.wallet.set_balance(10000000)
	world.trees.reset()
	for pen: AnimalPen in world.workers.bridge.pens():
		for node: Node in pen.get_children():
			if node is AnimalTrough:
				node.stock = node.capacity
	assert_eq(world.workers.hire("crop"), "")

func after_each() -> void:
	TimeManager.clock_source = old_source
	TimeManager._last_timestamp = old_floor
	TimeManager.set_process(old_processing)

func _animal() -> AnimalActor:
	var animal: AnimalActor = preload("res://scenes/animals/chicken.tscn").instantiate() as AnimalActor
	animal.position = Vector2(100, 80)
	world.get_node("CoopPen").add_child(animal)
	animal.health.sick = true
	animal.needs.weather = null
	animal.needs.pen = null
	animal.needs.configure(1000000, 1000000)
	world.workers.bridge.invalidate_ranch()
	return animal

func _crop() -> Crop:
	var cell: Vector2i = Vector2i(56, 22)
	world.farming.restore_soil([{"cell": [56, 22], "state": 1}])
	world.farming.restore_crop(cell, preload("res://crops/field/wheat/wheat.tres"), now, now + 10000.0, 0.0, now)
	var crop: Crop = world.farming.get_crop(cell)
	crop.conditions.weeds = true
	crop.conditions.pests = true
	crop.refresh(now)
	return crop

func test_missing_medicines_report_exact_type_and_deposit_clears_reason() -> void:
	_crop()
	_animal()
	var service: WorkerService = world.workers
	var row: Dictionary = service.record("crop")
	var bag: InventoryComponent = service.feed_inventory(String(row.id))
	service.bridge.candidates(row, bag)
	var reason: String = service.waiting_reasons[String(row.id)]
	assert_string_contains(reason, "No herbicide")
	assert_string_contains(reason, "No pesticide")
	assert_string_contains(reason, "No animal medicine")
	bag.add(WorkerWorldBridge.HERBICIDE, 5)
	bag.add(WorkerWorldBridge.PESTICIDE, 5)
	bag.add(WorkerWorldBridge.ANIMAL_MEDICINE, 5)
	service.bridge.candidates(row, bag)
	assert_false(service.waiting_reasons.has(String(row.id)))

func test_priority_modes_and_legacy_save_defaults() -> void:
	var choices: Array[Dictionary] = [{"kind": "harvest", "id": "crop", "priority": 0, "point": [0, 0]}, {"kind": "cure_animal", "id": "animal", "priority": 0, "point": [100, 0]}]
	WorkerRole.apply_priorities(choices, "care_first")
	assert_eq(WorkerRole.choose(choices, Vector2.ZERO).kind, "cure_animal")
	WorkerRole.apply_priorities(choices, "harvest_first")
	assert_eq(WorkerRole.choose(choices, Vector2.ZERO).kind, "harvest")
	assert_true(world.workers.configure_priority("care_first"))
	var captured: Dictionary = world.workers.crop_automation.capture()
	var copy: CropAutomationState = CropAutomationState.new()
	copy.restore(captured)
	assert_eq(copy.priority_mode, "care_first")
	copy.restore(CropAutomationState.fresh())
	assert_eq(copy.priority_mode, "balanced")
	assert_false(world.workers.configure_priority("invalid"))
	assert_true(CropAutomationState.valid(captured, SaveCatalog.new(), now))
	captured.priority_mode = "invalid"
	assert_false(CropAutomationState.valid(captured, SaveCatalog.new(), now))

func test_animal_commit_rejects_wall_and_keeps_medicine() -> void:
	var animal: AnimalActor = _animal()
	var row: Dictionary = world.workers.record("crop")
	var worker: WorkerActor = world.workers.actor_for(String(row.id))
	worker.global_position = animal.global_position + Vector2(0, 28)
	row.position = WorkerRole.pair(worker.global_position)
	var wall: StaticBody2D = StaticBody2D.new()
	wall.process_mode = Node.PROCESS_MODE_ALWAYS
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(60, 3)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	wall.global_position = animal.global_position + Vector2(0, 14)
	await wait_physics_frames(2)
	var bag: InventoryComponent = world.workers.feed_inventory(String(row.id))
	bag.add(WorkerWorldBridge.ANIMAL_MEDICINE, 1)
	var job: Dictionary = {"kind": "cure_animal", "id": String(animal.persistent_id), "item": "animal_medicine"}
	assert_false(world.workers.bridge.commit(row, bag, job))
	assert_true(animal.health.sick)
	assert_eq(bag.count_item(&"animal_medicine"), 1)

func test_moving_target_replans_and_removed_target_cancels() -> void:
	var animal: AnimalActor = _animal()
	var row: Dictionary = world.workers.record("crop")
	var worker: WorkerActor = world.workers.actor_for(String(row.id))
	worker.global_position = animal.global_position + Vector2(0, 70)
	row.task = {"kind": "cure_animal", "id": String(animal.persistent_id), "point": WorkerRole.pair(animal.global_position + Vector2(100, 0)), "work_at": now, "finish_at": now + 2}
	assert_true(world.workers.bridge.refresh_animal_task(row, false))
	assert_lte(WorkerRole.point(row.task.point).distance_to(animal.global_position), 32.0)
	assert_gt(float(row.task.finish_at), now)
	animal.free()
	assert_false(world.workers.bridge.refresh_animal_task(row, false))

func test_unreachable_patient_times_out_without_spending_medicine() -> void:
	var animal: AnimalActor = _animal()
	var row: Dictionary = world.workers.record("crop")
	var bag: InventoryComponent = world.workers.feed_inventory(String(row.id))
	bag.add(WorkerWorldBridge.ANIMAL_MEDICINE, 1)
	row.task = {"kind": "cure_animal", "id": String(animal.persistent_id), "point": WorkerRole.pair(animal.global_position), "tracking_started_at": now - 46.0}
	assert_false(world.workers.bridge.refresh_animal_task(row, false))
	assert_gt(float(world.workers.blocked_targets[String(row.id) + ":" + String(animal.persistent_id)]), now)
	assert_eq(bag.count_item(&"animal_medicine"), 1)

func test_online_worker_moves_sprays_and_consumes_once() -> void:
	var crop: Crop = _crop()
	crop.conditions.pests = false
	var service: WorkerService = world.workers
	var row: Dictionary = service.record("crop")
	var worker: WorkerActor = service.actor_for(String(row.id))
	var goal: Vector2 = world.farming.farmland.to_global(world.farming.farmland.map_to_local(Vector2i(56, 22)))
	worker.global_position = goal + Vector2(0, 55)
	row.position = WorkerRole.pair(worker.global_position)
	row.task = {}
	row.wake_at = now
	service.feed_inventory(String(row.id)).add(WorkerWorldBridge.HERBICIDE, 2)
	var moved: bool = false
	var sprayed: bool = false
	var origin: Vector2 = worker.global_position
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	service.navigation.process_mode = Node.PROCESS_MODE_ALWAYS
	for frame: int in range(720):
		now += 1.0 / 60.0
		service.advance(now, false)
		await wait_physics_frames(1)
		moved = moved or worker.global_position.distance_to(origin) > 10
		sprayed = sprayed or (worker.care_action.visible and worker.care_action.kind == "treat_weeds")
		if not crop.conditions.weeds:
			break
	assert_true(moved)
	assert_true(sprayed)
	assert_false(crop.conditions.weeds)
	assert_eq(service.feed_inventory(String(row.id)).count_item(&"herbicide"), 1)

func test_bubble_fits_both_languages_and_preserves_center_under_zoom() -> void:
	var original: String = TranslationServer.get_locale()
	for language: String in ["vi", "en"]:
		Language.set_language(language)
		var holder: Node2D = Node2D.new()
		holder.scale = Vector2(2.5, 2.5)
		add_child_autofree(holder)
		var bubble: Node2D = preload("res://components/animals/animal_care_bubble.gd").new()
		holder.add_child(bubble)
		await wait_process_frames(2)
		var panel: PanelContainer = bubble.get_node("BubbleVisual/BubblePanel") as PanelContainer
		var label: Label = panel.get_node("Text") as Label
		var measured: Vector2 = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
		assert_lte(measured.x, label.size.x)
		assert_lte(label.get_minimum_size().y, label.size.y)
		assert_almost_eq(panel.position.x + label.position.x + label.size.x * 0.5, 0.0, 0.01)
	Language.set_language(original)
