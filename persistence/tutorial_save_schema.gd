class_name TutorialSaveSchema
extends RefCounted

static func fresh() -> Dictionary:
	return {"enabled": true, "skipped": false, "seen": [], "support_used": false}

static func known(id: String) -> bool:
	for definition: ObjectiveDefinition in ObjectiveProgress.DEFAULT_CATALOG.steps:
		if String(definition.objective_id) == id:
			return true
	return false

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 4 or not data.get("enabled") is bool or not data.get("skipped") is bool or not data.get("support_used") is bool or not data.get("seen") is Array or data.seen.size() > ObjectiveProgress.DEFAULT_CATALOG.steps.size():
		return false
	if data.enabled and data.skipped:
		return false
	var ids: Dictionary = {}
	for id: Variant in data.seen:
		if not id is String or not known(id) or ids.has(id):
			return false
		ids[id] = true
	return true
