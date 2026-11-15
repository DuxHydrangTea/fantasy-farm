class_name TutorialSaveSchema
extends RefCounted
## Tạo và kiểm tra dữ liệu trạng thái hướng dẫn người chơi.

## Tạo trạng thái mặc định: bật hướng dẫn, chưa bỏ qua và chưa xem mục nào.
static func fresh() -> Dictionary:
	return {"enabled": true, "skipped": false, "seen": [], "support_used": false}

## Kiểm tra mã có trong catalog mục tiêu mặc định.
static func known(id: String) -> bool:
	for definition: ObjectiveDefinition in ObjectiveProgress.DEFAULT_CATALOG.steps:
		if String(definition.objective_id) == id:
			return true
	return false

## Kiểm tra các cờ và danh sách mã đã xem không trùng, đều có trong catalog.
## Trạng thái bật và đã bỏ qua không được cùng đúng.
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
