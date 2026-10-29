class_name WorkerSaveSchema
extends RefCounted
static func fresh() -> Dictionary:
	return {"rows": [], "trial_used": [], "next_order": 1, "simulated_at": 0.0, "crop_automation": CropAutomationState.fresh()}

static func valid(data: Variant, catalog: SaveCatalog, saved_at: float) -> bool:
	if not data is Dictionary or data.size() != 5 or not data.get("rows") is Array or data.rows.size() > 7 or not data.get("trial_used") is Array or data.trial_used.size() > 3 or not SaveSchema.number(data.get("next_order"), 1, 1000000000, true) or not SaveSchema.number(data.get("simulated_at"), 0, saved_at):
		return false
	if not CropAutomationState.valid(data.get("crop_automation"), catalog, saved_at):
		return false
	if not data.rows.is_empty() and absf(float(data.simulated_at) - saved_at) > 0.001:
		return false
	var trials: Dictionary = {}
	for role: Variant in data.trial_used:
		if not role is String or not role in WorkerRole.ROLES or trials.has(role):
			return false
		trials[role] = true
	var roles: Dictionary = {}
	var ids: Dictionary = {}
	var slots: Dictionary = {}
	var orders: Dictionary = {}
	var targets: Dictionary = {}
	for row: Variant in data.rows:
		if not row is Dictionary or not SaveSchema.identifier(row.get("id")) or not row.get("role") is String or not row.role in WorkerRole.ROLES or ids.has(row.id) or not row.get("zone") is String or not row.get("employed") is bool or not row.get("active") is bool or not SaveSchema.vector(row.get("position")) or not SaveSchema.number(row.get("hire_order"), 1, int(data.next_order) - 1, true) or orders.has(row.hire_order) or not SaveSchema.number(row.get("paid_through_day"), -100000000, 100000000, true) or not SaveSchema.number(row.get("last_wage_day"), -100000000, 100000000, true) or row.paid_through_day > row.last_wage_day or not SaveSchema.number(row.get("wake_at")) or not SaveSchema.number(row.get("paused_at"), 0, saved_at) or not SaveSchema.number(row.get("patrol_index"), 0, 3, true) or not SaveSchema.number(row.get("water_units"), 0, 30, true) or not row.get("basket") is Array or row.basket.size() != 16 or not row.get("task") is Dictionary or not trials.has(row.role):
			return false
		if row.active and not row.employed:
			return false
		if not SaveSchema.number(row.get("slot"), 1, int(WorkerRole.LIMITS[row.role]), true):
			return false
		var slot_key: String = "%s:%d" % [row.role, int(row.slot)]
		if slots.has(slot_key):
			return false
		slots[slot_key] = true
		roles[row.role] = int(roles.get(row.role, 0)) + 1
		if int(roles[row.role]) > int(WorkerRole.LIMITS[row.role]):
			return false
		ids[row.id] = true
		orders[row.hire_order] = true
		for slot: Variant in row.basket:
			if not QualitySaveSchema.slot_valid(slot, catalog, 100):
				return false
			if slot.item == "":
				if slot.count != 0:
					return false
			elif not catalog.items.has(slot.item) or slot.count < 1 or slot.count > (catalog.items[slot.item] as ItemDefinition).get_stack_limit():
				return false
		var task: Dictionary = row.task
		if not task.is_empty():
			if not task.get("kind") is String or not task.kind in ["fruit", "harvest", "water_crop", "pickup", "feed", "fetch_water", "water_trough", "patrol", "till", "plant", "fertilize"] or not task.get("id") is String or not SaveSchema.vector(task.get("point")) or not SaveSchema.vector(task.get("base_point")) or not SaveSchema.number(task.get("attempt"), 0, 4, true) or not SaveSchema.number(task.get("work_at")) or not SaveSchema.number(task.get("finish_at"), float(task.work_at)):
				return false
			var allowed: Array = ["fruit", "pickup", "patrol"] if row.role == "orchard" else ["harvest", "water_crop", "pickup", "patrol", "till", "plant", "fertilize"] if row.role == "crop" else ["feed", "fetch_water", "water_trough", "pickup", "patrol"]
			if not task.kind in allowed:
				return false
			if task.kind in ["fruit", "harvest", "water_crop", "till", "plant", "fertilize"] and not SaveSchema.vector(task.get("cell"), true):
				return false
			if row.role == "crop" and row.employed and row.active and not data.crop_automation.paused and task.kind != "patrol":
				var key: String = WorkerRole.target_key(task)
				if targets.has(key):
					return false
				targets[key] = row.id
			if task.kind in ["till", "plant", "fertilize"]:
				if not SaveSchema.number(task.get("revision"), 0, float(data.crop_automation.revision), true) or task.revision != data.crop_automation.revision or not task.get("item") is String:
					return false
				var item: ItemDefinition = catalog.items.get(task.item) as ItemDefinition
				if item == null:
					return false
				if task.kind in ["till", "plant"] and (not data.crop_automation.auto_plant or item.item_type != ItemDefinition.ItemType.SEED or not item.crop is CropDefinition or not item.crop.is_valid()):
					return false
				if task.kind == "fertilize" and (not data.crop_automation.auto_fertilize or item.item_type != ItemDefinition.ItemType.BOOSTER or item.booster_kind != ItemDefinition.BoosterKind.FERTILIZER or not task.get("crop") is String or not catalog.crops.has(task.crop) or not SaveSchema.number(task.get("planted_at"), 0, saved_at)):
					return false
	for prepared: Dictionary in data.crop_automation.prepared:
		var owner_found: bool = false
		for row: Dictionary in data.rows:
			if row.id == prepared.worker and row.role == "crop" and row.employed:
				owner_found = true
				var key: String = "cell:%d_%d" % [int(prepared.cell[0]), int(prepared.cell[1])]
				if row.active and not data.crop_automation.paused and targets.has(key) and targets[key] != row.id:
					return false
		if not owner_found:
			return false
	return true
