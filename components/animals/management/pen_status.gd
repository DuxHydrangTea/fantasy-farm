class_name PenStatus
extends RefCounted
## Các truy vấn chỉ đọc phục vụ giao diện quản lý chuồng.

## Liệt kê vật nuôi còn hợp lệ thuộc chuồng, sắp xếp theo mã ổn định.
static func members(pen: AnimalPen) -> Array[AnimalActor]:
	var result: Array[AnimalActor] = []
	var status: AnimalStatusText = AnimalStatusText.new()
	if not is_instance_valid(pen) or not pen.is_inside_tree():
		return result
	for node: Node in pen.get_tree().get_nodes_in_group(&"animal_status_targets"):
		var actor: AnimalActor = node as AnimalActor
		if status.is_available(actor) and actor.pen == pen:
			result.append(actor)
	result.sort_custom(func(a: AnimalActor, b: AnimalActor) -> bool: return String(a.persistent_id) < String(b.persistent_id))
	return result

## Cộng tồn kho và sức chứa các máng cùng loại thuộc chuồng.
## Trả [code]stock[/code], [code]capacity[/code] và phần trăm lượng khả dụng
## trên tổng sức chứa. Khi không có sức chứa, phần trăm bằng 0.
static func troughs(pen: AnimalPen, kind: AnimalTrough.Kind) -> Dictionary:
	var stock: int = 0
	var capacity: int = 0
	var available: float = 0.0
	for node: Node in pen.get_tree().get_nodes_in_group(&"animal_troughs"):
		var trough: AnimalTrough = node as AnimalTrough
		if trough.pen == pen and trough.kind == kind and not trough.is_queued_for_deletion():
			stock += trough.stock
			available += trough.available_units()
			capacity += trough.capacity
	return {"stock": stock, "capacity": capacity, "percent": 100.0 * available / capacity if capacity > 0 else 0.0}

## Trả tiêu đề đã dịch theo loại ao, chuồng gà hoặc chuồng gia súc.
static func title(pen: AnimalPen) -> String:
	if pen is PondPen:
		return TranslationServer.translate("Pond management")
	if pen.accepted_species == [AnimalTypes.Species.CHICKEN]:
		return TranslationServer.translate("Coop management")
	return TranslationServer.translate("Livestock management")

## Tạo chuỗi sáu chữ số từ hash của mã ổn định để hiển thị ngắn.
static func short_id(actor: AnimalActor) -> String:
	return "%06d" % (String(actor.persistent_id).hash() % 1000000)
