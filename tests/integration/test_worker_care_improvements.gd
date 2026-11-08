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
	world.land.state.restore_blocks(16, 8)
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

func _focus_patient(animal: AnimalActor) -> Dictionary:
	var service: WorkerService = world.workers
	var row: Dictionary = service.record("crop")
	var worker: WorkerActor = service.actor_for(row.id)
	var point: Vector2 = animal.global_position + Vector2(0, 24)
	worker.global_position = point
	row.position = WorkerRole.pair(point)
	row.task = {"kind": "cure_animal", "id": String(animal.persistent_id), "item": "animal_medicine", "point": WorkerRole.pair(point), "base_point": WorkerRole.pair(point), "attempt": 0, "work_at": now, "finish_at": now + 2.0, "duration": 2.0}
	worker.behaviour._physics_process(1.0 / 60.0)
	assert_true(animal.behaviour._has_care_hold())
	return row

func test_walking_patient_stays_still_through_real_online_treatment() -> void:
	var animal: AnimalActor = _animal()
	animal.process_mode = Node.PROCESS_MODE_ALWAYS
	animal.wander.set_destination(animal.global_position + Vector2(40, 0))
	animal.behaviour._enter(AnimalBehaviourComponent.State.WALK)
	var original: Vector2 = animal.global_position
	await wait_physics_frames(3)
	assert_gt(animal.global_position.distance_to(original), 0.0, "Reproduce a moving sick animal")
	var service: WorkerService = world.workers
	var row: Dictionary = service.record("crop")
	var worker: WorkerActor = service.actor_for(row.id)
	worker.global_position = animal.global_position + Vector2(0, 55)
	row.position = WorkerRole.pair(worker.global_position)
	row.task = {}
	row.wake_at = now
	service.feed_inventory(row.id).add(WorkerWorldBridge.ANIMAL_MEDICINE, 1)
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	service.navigation.process_mode = Node.PROCESS_MODE_ALWAYS
	var held: bool = false
	var stayed_still: bool = true
	var held_position: Vector2
	var held_frames: int = 0
	for frame: int in range(300):
		now += 1.0 / 60.0
		service.advance(now, false)
		await wait_physics_frames(1)
		if not animal.health.sick:
			break
		if animal.behaviour._has_care_hold():
			if not held:
				held_position = animal.global_position
			held = true
			held_frames += 1
			stayed_still = stayed_still and animal.global_position.is_equal_approx(held_position)
	assert_true(held)
	assert_gt(held_frames, 60, "Hold lasts while approaching and working")
	assert_true(stayed_still, "No chase/restart while the patient was walking")
	assert_false(animal.health.sick)
	assert_eq(service.feed_inventory(row.id).count_item(&"animal_medicine"), 0)
	assert_false(animal.behaviour._has_care_hold())
	assert_true(animal.behaviour.request_behaviour(&"walk"), "Normal behaviour resumes after cure")

func test_care_hold_and_player_focus_release_independently() -> void:
	var animal: AnimalActor = _animal()
	var row: Dictionary = _focus_patient(animal)
	animal.set_status_focused(true)
	animal.set_status_focused(false)
	assert_false(animal.behaviour.request_behaviour(&"walk"), "Player unfocus cannot release the worker's hold")
	animal.set_status_focused(true)
	row.task = {}
	animal.behaviour._physics_process(0.1)
	assert_false(animal.behaviour._has_care_hold())
	assert_false(animal.behaviour.request_behaviour(&"walk"), "Task cancellation cannot release the player's focus")
	animal.set_status_focused(false)
	assert_true(animal.behaviour.request_behaviour(&"walk"))

func test_pause_retarget_and_dismiss_release_only_the_current_patient() -> void:
	var first: AnimalActor = _animal()
	var row: Dictionary = _focus_patient(first)
	row.active = false
	first.behaviour._physics_process(0.1)
	assert_true(first.behaviour.request_behaviour(&"walk"))
	row.active = true
	world.workers.actor_for(row.id).behaviour._physics_process(0.01)
	assert_false(first.behaviour.request_behaviour(&"walk"), "Resume reacquires a hold pruned during pause")
	var second: AnimalActor = _animal()
	_focus_patient(second)
	assert_false(first.behaviour._has_care_hold())
	assert_true(second.behaviour._has_care_hold())
	assert_eq(world.workers.dismiss(row.id), "")
	assert_true(second.behaviour.request_behaviour(&"walk"), "Dismissal releases even before the worker's next physics frame")

func test_removed_worker_and_external_cure_cannot_leave_stale_holds() -> void:
	var animal: AnimalActor = _animal()
	var row: Dictionary = _focus_patient(animal)
	assert_true(animal.cure_disease())
	assert_true(animal.behaviour.request_behaviour(&"walk"))
	animal.health.sick = true
	world.workers.actor_for(row.id).behaviour._physics_process(0.01)
	assert_true(animal.behaviour._has_care_hold())
	world.workers.actor_for(row.id).free()
	assert_false(animal.behaviour._has_care_hold())
	assert_true(animal.behaviour.request_behaviour(&"walk"))

func test_unreachable_patient_is_released_without_spending_medicine() -> void:
	var animal: AnimalActor = _animal()
	var row: Dictionary = _focus_patient(animal)
	var source: InventoryComponent = world.workers.feed_inventory(row.id)
	source.add(WorkerWorldBridge.ANIMAL_MEDICINE, 1)
	row.task["tracking_started_at"] = now - 46.0
	world.workers.advance(now, false)
	assert_false(animal.behaviour._has_care_hold())
	assert_true(animal.behaviour.request_behaviour(&"walk"))
	assert_eq(source.count_item(&"animal_medicine"), 1)

func test_worker_restore_releases_old_hold_and_reacquires_from_task() -> void:
	var animal: AnimalActor = _animal()
	var row: Dictionary = _focus_patient(animal)
	var service: WorkerService = world.workers
	var saved: Dictionary = service.capture(now)
	assert_true(WorkerSaveSchema.valid(saved, SaveCatalog.new(), now))
	service.restore(saved, SaveCatalog.new())
	assert_false(animal.behaviour._has_care_hold(), "Focus owners are transient and cannot survive their worker")
	service.actor_for(row.id).behaviour._physics_process(0.01)
	assert_true(animal.behaviour._has_care_hold(), "Restored cure task reacquires its patient")

func test_swimming_patient_defers_shore_delivery_only_until_care_releases() -> void:
	var pond: PondPen = world.get_node("PondPen") as PondPen
	pond.process_mode = Node.PROCESS_MODE_ALWAYS
	await wait_physics_frames(3)
	assert_true(pond.navigation_ready)
	pond.process_mode = Node.PROCESS_MODE_DISABLED
	var water: Vector2
	var found: bool = false
	for cell: Vector2i in pond.water_layer.get_used_cells():
		var point: Vector2 = pond.water_layer.to_global(pond.water_layer.map_to_local(cell))
		if pond.is_water(point) and pond.contains_world(point, 24) and not pond.land_route(point).is_empty():
			water = point
			found = true
			break
	assert_true(found, "Fixture needs one reachable water cell")
	if not found:
		return
	var duck: AnimalActor = preload("res://scenes/animals/duck.tscn").instantiate() as AnimalActor
	duck.initial_age_seconds = duck.definition.maturity_seconds
	duck.position = pond.to_local(water)
	pond.add_child(duck)
	duck.health.sick = true
	duck.production.restore_state(0.0, 1, false)
	var row: Dictionary = _focus_patient(duck)
	for frame: int in range(10):
		duck.behaviour._physics_process(0.1)
	assert_eq(duck.global_position, water)
	assert_false(duck.movement.has_target)
	assert_eq(duck.production.stored_amount, 1, "Focus preserves eggs while shore travel is paused")
	row.task = {}
	duck.behaviour._physics_process(0.1)
	assert_false(duck.behaviour._has_care_hold())
	assert_true(duck.movement.has_target or duck.product_pickup() != null, "Shore delivery resumes after cancellation")
