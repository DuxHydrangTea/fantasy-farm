class_name PenOfflineSimulation
extends RefCounted
## Scene bridge: apply a whole herd catch-up once, then resume physical feeding AI.
const SUSPENSION_GAP: float = 5.0
var pen: Node2D
var busy: bool = false

func _init(owner_pen: Node2D) -> void:
	pen = owner_pen

func advance(timestamp: float, force: bool = false) -> bool:
	if busy:
		return false
	var actors: Dictionary = {}
	var stations: Dictionary = {}
	var herd: Array[Dictionary] = []
	var supplies: Array[Dictionary] = []
	var start: float = timestamp
	for child: Node in pen.get_children():
		if child is AnimalActor:
			var actor: AnimalActor = child as AnimalActor
			if actor.pen != pen or actor.is_dead() or actor.is_queued_for_deletion() or actor.definition == null:
				continue
			var id: String = String(actor.persistent_id)
			actors[id] = actor
			start = minf(start, actor.needs.updated_at())
			herd.append({"id": id, "species": int(actor.definition.species), "satiety": actor.needs.satiety, "hydration": actor.needs.hydration,
				"food_seconds": actor.needs.satiety_depletion_seconds, "water_seconds": actor.needs.hydration_depletion_seconds,
				"age": actor.growth.age_seconds, "lifespan": actor.growth.lifespan_seconds, "starts_at": actor.needs.updated_at()})
		elif child is AnimalTrough:
			var trough: AnimalTrough = child as AnimalTrough
			if trough.pen != pen or trough.is_queued_for_deletion():
				continue
			var id: String = String(trough.persistent_id)
			if id.is_empty():
				id = String(trough.name)
			stations[id] = trough
			supplies.append({"id": id, "kind": int(trough.kind), "stock": trough.available_units(), "restoration": trough.restoration_per_unit, "species": trough.allowed_species.duplicate()})
	if timestamp - start <= PenOfflineModel.EPSILON:
		return true
	if not force and timestamp - start <= SUSPENSION_GAP:
		return false
	busy = true
	var weather_schedule = pen.get("weather")
	var result: Dictionary = PenOfflineModel.advance(herd, supplies, start, timestamp, weather_schedule)
	for actor: AnimalActor in actors.values():
		actor.foraging.cancel()
	for row: Dictionary in result.troughs:
		(stations[row.id] as AnimalTrough).restore_offline_stock(float(row.stock))
	for step: Dictionary in result.steps:
		var actor: AnimalActor = actors[step.id]
		actor.needs.apply_offline_step(float(step.timestamp), float(step.elapsed), float(step.supplied), float(step.satiety), float(step.hydration))
	busy = false
	return true

func sync_before_change(timestamp: float) -> void:
	if busy or advance(timestamp):
		return
	# Small online intervals keep physical AI; still settle them before adding stock.
	busy = true
	for child: Node in pen.get_children():
		if child is AnimalActor and not child.is_queued_for_deletion():
			(child as AnimalActor).needs.update_at(timestamp)
	busy = false
