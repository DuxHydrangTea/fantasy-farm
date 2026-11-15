class_name WorkerRole
extends RefCounted
## Quy tắc thuần cho vai trò, tiền công và lựa chọn công việc công nhân.
## Ứng viên được chọn theo độ ưu tiên, khoảng cách rồi mã mục tiêu ổn định.

## Các vai trò đang hỗ trợ.
const ROLES: Array[String] = ["crop"]
## Giới hạn số công nhân theo vai trò.
const LIMITS: Dictionary = {"crop": 3}
## Tiền công theo vai trò.
const WAGES: Dictionary = {"crop": 2800}
## Các chế độ ưu tiên có thể chọn.
const PRIORITY_MODES: Array[String] = ["balanced", "care_first", "harvest_first"]
## Chuỗi nguồn mô tả các loại công việc.
const TASK_CAPTIONS: Dictionary = {"till": "Tilling soil", "plant": "Planting crops", "fertilize": "Fertilizing crops", "water": "Watering", "water_crop": "Watering", "feed": "Refilling feed", "water_trough": "Refilling water", "fetch_water": "Fetching water", "harvest": "Harvesting", "fruit": "Harvesting", "pickup": "Collecting produce", "pen_collect": "Collecting pen produce", "patrol": "Patrolling the work area", "treat_pests": "Treating pests", "treat_weeds": "Treating weeds", "cure_animal": "Treating an animal"}

## Tạo chuỗi nguồn mô tả công việc hoặc trạng thái chờ, nghỉ.
static func task_caption(task: Dictionary, position: Vector2) -> String:
	if task.is_empty():
		return "Waiting for work"
	if task.get("kind", "") == "patrol" and position.distance_to(point(task.point)) <= 3.0:
		return "Resting"
	return String(TASK_CAPTIONS.get(String(task.get("kind", "")), "Working"))

## Điều chỉnh độ ưu tiên tại chỗ theo chế độ chăm sóc hoặc thu hoạch trước.
static func apply_priorities(tasks: Array[Dictionary], mode: String) -> void:
	if mode == "balanced":
		return
	for task: Dictionary in tasks:
		var group: int = 4
		match String(task.kind):
			"cure_animal": group = 0 if mode == "care_first" else 1
			"feed", "water_trough", "fetch_water": group = 1 if mode == "care_first" else 2
			"treat_pests", "treat_weeds": group = 2 if mode == "care_first" else 3
			"fruit", "harvest", "pickup", "pen_collect": group = 3 if mode == "care_first" else 0
		task.priority = group * 10 + mini(int(task.priority), 9)
## Chuyển mảng hai tọa độ thành Vector2.
static func point(coordinates: Array) -> Vector2:
	return Vector2(float(coordinates[0]), float(coordinates[1]))

## Chuyển Vector2 thành mảng hai số dùng trong dữ liệu lưu và công việc.
static func pair(value: Vector2) -> Array:
	return [value.x, value.y]

## Chọn công việc tốt nhất và trả bản sao sâu, hoặc dictionary rỗng.
static func choose(candidates: Array[Dictionary], origin: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var distance: float = INF
	for task: Dictionary in candidates:
		var next_distance: float = origin.distance_squared_to(point(task.point))
		if best.is_empty() or int(task.priority) < int(best.priority) or (int(task.priority) == int(best.priority) and (next_distance < distance or (is_equal_approx(next_distance, distance) and String(task.id) < String(best.id)))):
			best = task
			distance = next_distance
	return best.duplicate(true)

## Tạo khóa giữ chỗ theo loại mục tiêu; tuần tra và việc rỗng không có khóa.
static func target_key(job: Dictionary) -> String:
	if job.is_empty() or job.get("kind", "") == "patrol":
		return ""
	if job.kind == "pickup":
		return "pickup:" + String(job.get("id", ""))
	if job.kind == "cure_animal":
		return "animal:" + String(job.get("id", ""))
	if job.has("cell"):
		return "cell:%d_%d" % [int(job.cell[0]), int(job.cell[1])]
	return "station:" + String(job.get("id", ""))
