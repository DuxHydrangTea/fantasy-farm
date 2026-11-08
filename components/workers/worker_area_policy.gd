class_name WorkerAreaPolicy
extends RefCounted
## Bounded batch planning; a single cell commit is a scheduler event boundary.
const TOOLS: Dictionary = {"till": "hoe", "plant": "sowing", "water_crop": "watering", "harvest": "harvest"}

static func task_cells(job: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if job.has("cells"):
		for index: int in range(int(job.get("cursor", 0)), job.cells.size()):
			result.append(Vector2i(int(job.cells[index][0]), int(job.cells[index][1])))
	elif job.has("cell"):
		result.append(Vector2i(int(job.cell[0]), int(job.cell[1])))
	return result

static func item_count(job: Dictionary) -> int:
	return maxi(1, task_cells(job).size()) if job.get("kind", "") in ["till", "plant"] else 1

static func footprint(anchor: Vector2i, width: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var start: Vector2i = anchor - (Vector2i.ONE if width == 3 else Vector2i.ZERO)
	for y: int in range(width):
		for x: int in range(width):
			result.append(start + Vector2i(x, y))
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = (a - anchor).length_squared()
		var db: int = (b - anchor).length_squared()
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	return result

static func eligible(team: WorkerService, row: Dictionary, job: Dictionary, cell: Vector2i, at_commit: bool = false) -> bool:
	var farm: FarmingController = team.world.farming
	var actor: WorkerActor = team.actor_for(String(row.id))
	if not LandExpansionState.REGION.has_point(cell) or not team.world.land.state.is_unlocked(cell):
		return false
	var center: Vector2 = farm.farmland.to_global(farm.farmland.map_to_local(cell))
	var origin: Vector2 = actor.global_position if at_commit else WorkerRole.point(job.point)
	if at_commit and origin.distance_to(WorkerRole.point(job.point)) > 3.0:
		return false
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, center, farm.obstacle_mask, [actor.get_rid()])
	if not actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		return false
	match String(job.kind):
		"till": return farm.can_till(cell, actor)
		"plant": return farm.can_plant(cell, actor)
		"water_crop":
			var crop: Crop = farm.get_crop(cell)
			return crop != null and not crop.is_mature() and farm.can_water(cell, actor)
		"harvest":
			var crop: Crop = farm.get_crop(cell)
			return crop != null and farm.can_harvest(cell) and farm._allowed(cell, &"can_plant", actor) and not (crop.conditions.affected() and team.crop_automation.wait_for_care)
	return false

static func expand(team: WorkerService, row: Dictionary, job: Dictionary) -> void:
	if not TOOLS.has(job.kind):
		return
	var width: int = team.upgrades.level(String(TOOLS[job.kind]))
	if width == 1:
		return
	var held: Dictionary = team.reservations(String(row.id))
	var limit: int = width * width
	if job.kind in ["till", "plant"]:
		var item: StringName = StringName(job.item)
		limit = mini(limit, team.feed_inventory(row.id).count_item(item) - int(held.items.get(String(item), 0)))
	var cells: Array = []
	var anchor: Vector2i = Vector2i(int(job.cell[0]), int(job.cell[1]))
	for cell: Vector2i in footprint(anchor, width):
		if cells.size() >= limit:
			break
		if not held.cells.has(cell) and eligible(team, row, job, cell):
			cells.append([cell.x, cell.y])
	# Retain the selected single target if terrain changed during planning.
	if not cells.is_empty():
		job["cells"] = cells
		job["cursor"] = 0

static func commit_next(team: WorkerService, row: Dictionary, job: Dictionary) -> void:
	var index: int = int(job.cursor)
	var cell: Vector2i = Vector2i(int(job.cells[index][0]), int(job.cells[index][1]))
	var single: Dictionary = job.duplicate(true)
	single.erase("cells")
	single.erase("cursor")
	single.cell = [cell.x, cell.y]
	single.id = "%d_%d" % [cell.x, cell.y]
	if team.running(row) and not team.reservations(String(row.id)).cells.has(cell) and eligible(team, row, single, cell, true):
		team.bridge.commit(row, team.feed_inventory(row.id), single)
	# Increment only after the complete inventory/world transaction. No await.
	job.cursor = index + 1
