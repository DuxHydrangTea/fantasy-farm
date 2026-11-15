class_name ObjectiveSaveSchema
extends RefCounted
## Tạo và kiểm tra tiến độ mục tiêu theo thứ tự trong catalog.

## Tạo một dòng tiến độ bằng 0 và chưa nhận thưởng cho mỗi mục tiêu.
static func fresh(catalog: ObjectiveCatalog) -> Dictionary:
	var steps: Array = []
	for definition: ObjectiveDefinition in catalog.steps:
		steps.append({"id": String(definition.objective_id), "progress": 0, "claimed": false})
	return {"steps": steps, "tracked_id": "", "hud_collapsed": false}

## Kiểm tra catalog, thứ tự và mã mục tiêu, tiến độ, thưởng và mục được theo dõi.
## Sau mục đầu tiên chưa nhận thưởng, các mục sau phải chưa có tiến độ.
static func valid(data: Variant, catalog: ObjectiveCatalog) -> bool:
	if not catalog.is_valid() or not data is Dictionary or data.size() != 3 or not data.get("steps") is Array or data.steps.size() != catalog.steps.size():
		return false
	if not data.get("tracked_id") is String or not data.get("hud_collapsed") is bool:
		return false
	var known: bool = data.tracked_id.is_empty()
	for definition: ObjectiveDefinition in catalog.steps:
		known = known or data.tracked_id == String(definition.objective_id)
	if not known:
		return false
	var active_seen: bool = false
	for index: int in range(catalog.steps.size()):
		var row: Variant = data.steps[index]
		var step: ObjectiveDefinition = catalog.steps[index]
		if not row is Dictionary or row.size() != 3 or not row.get("id") is String or row.id != String(step.objective_id) or not row.get("claimed") is bool:
			return false
		var value: Variant = row.get("progress")
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)) or float(value) < 0 or float(value) > step.required:
			return false
		if active_seen and (row.claimed or value != 0):
			return false
		if row.claimed and value != step.required:
			return false
		if not row.claimed:
			active_seen = true
	return true
