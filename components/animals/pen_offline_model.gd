class_name PenOfflineModel
extends RefCounted
## Continuous shared supply, split only at stock/body/death/weather/arrival boundaries.
## Units may be fractional here; the scene bridge preserves them beside integer stock.
const EPSILON: float = 0.000001

static func advance(animals: Array[Dictionary], troughs: Array[Dictionary], start: float, until: float, weather: WeatherSchedule = null) -> Dictionary:
	var herd: Array[Dictionary] = animals.duplicate(true)
	var supplies: Array[Dictionary] = troughs.duplicate(true)
	herd.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.id) < String(b.id))
	supplies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.id) < String(b.id))
	var steps: Array[Dictionary] = []
	var cursor: float = start
	while cursor < until - EPSILON:
		var active: Array[Dictionary] = []
		var end: float = minf(until, weather.next_boundary(cursor)) if weather != null else until
		var pending: bool = false
		for row: Dictionary in herd:
			if float(row.age) >= float(row.lifespan) - EPSILON:
				continue
			pending = true
			if float(row.starts_at) > cursor + EPSILON:
				end = minf(end, float(row.starts_at))
				continue
			active.append(row)
			end = minf(end, cursor + float(row.lifespan) - float(row.age))
		if not pending:
			break
		var water_rate: float = weather.water_rate(cursor) if weather != null else 1.0
		# Fill deficits proportionally; no actor can take the last portion by array order.
		_top_up(active, supplies, 0, "satiety")
		_top_up(active, supplies, 1, "hydration")
		var food: Dictionary = _rates(active, supplies, 0, water_rate)
		var water: Dictionary = _rates(active, supplies, 1, water_rate)
		for supply: Dictionary in supplies:
			var rate: float = float(food.troughs.get(supply.id, 0.0)) + float(water.troughs.get(supply.id, 0.0))
			if rate > 0.0:
				end = minf(end, cursor + float(supply.stock) / rate)
		for row: Dictionary in active:
			var food_loss: float = float(food.loss[row.id])
			var water_loss: float = float(water.loss[row.id])
			if food_loss > 0.0 and float(row.satiety) > EPSILON:
				end = minf(end, cursor + float(row.satiety) / food_loss)
			if water_loss > 0.0 and float(row.hydration) > EPSILON:
				end = minf(end, cursor + float(row.hydration) / water_loss)
		var elapsed: float = end - cursor
		if elapsed <= 0.0:
			break
		for supply: Dictionary in supplies:
			var rate: float = float(food.troughs.get(supply.id, 0.0)) + float(water.troughs.get(supply.id, 0.0))
			supply.stock = maxf(0.0, float(supply.stock) - elapsed * rate)
			if float(supply.stock) < EPSILON:
				supply.stock = 0.0
		for row: Dictionary in active:
			var fed: bool = float(row.satiety) > EPSILON or float(food.loss[row.id]) <= EPSILON
			var hydrated: bool = float(row.hydration) > EPSILON or float(water.loss[row.id]) <= EPSILON
			row.satiety = maxf(0.0, float(row.satiety) - elapsed * float(food.loss[row.id]))
			row.hydration = maxf(0.0, float(row.hydration) - elapsed * float(water.loss[row.id]))
			if float(row.satiety) < EPSILON:
				row.satiety = 0.0
			if float(row.hydration) < EPSILON:
				row.hydration = 0.0
			row.age = minf(float(row.lifespan), float(row.age) + elapsed)
			steps.append({"id": row.id, "timestamp": end, "elapsed": elapsed, "supplied": elapsed if fed and hydrated else 0.0, "satiety": row.satiety, "hydration": row.hydration})
		cursor = end
	return {"animals": herd, "troughs": supplies, "steps": steps, "updated_at": maxf(start, until)}

static func _accepts(supply: Dictionary, row: Dictionary) -> bool:
	return supply.species.is_empty() or int(row.species) in supply.species

static func _top_up(herd: Array[Dictionary], supplies: Array[Dictionary], kind: int, field: String) -> void:
	for supply: Dictionary in supplies:
		if int(supply.kind) != kind or float(supply.stock) <= EPSILON:
			continue
		var needed: float = 0.0
		for row: Dictionary in herd:
			if _accepts(supply, row):
				needed += maxf(0.0, 100.0 - float(row[field]))
		if needed <= EPSILON:
			continue
		var energy: float = minf(needed, float(supply.stock) * float(supply.restoration))
		for row: Dictionary in herd:
			if _accepts(supply, row):
				row[field] = minf(100.0, float(row[field]) + maxf(0.0, 100.0 - float(row[field])) * energy / needed)
		supply.stock = maxf(0.0, float(supply.stock) - energy / float(supply.restoration))

static func _rates(herd: Array[Dictionary], supplies: Array[Dictionary], kind: int, water_rate: float) -> Dictionary:
	var loss: Dictionary = {}
	var usage: Dictionary = {}
	for row: Dictionary in herd:
		loss[row.id] = 100.0 / float(row.food_seconds) if kind == 0 else water_rate * 100.0 / float(row.water_seconds)
	for supply: Dictionary in supplies:
		if int(supply.kind) != kind or float(supply.stock) <= EPSILON:
			continue
		var demand: float = 0.0
		for row: Dictionary in herd:
			if _accepts(supply, row):
				demand += float(loss[row.id])
				loss[row.id] = 0.0
		usage[supply.id] = demand / float(supply.restoration)
	return {"loss": loss, "troughs": usage}
