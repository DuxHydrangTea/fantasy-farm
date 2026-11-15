class_name ObjectiveCatalog
extends Resource
## Danh sách mục tiêu theo thứ tự cùng quy tắc kiểm tra dữ liệu cấu hình.

## Các bước mục tiêu được cấu hình.
@export var steps: Array[ObjectiveDefinition] = []

## Kiểm tra 1–100 mục tiêu có mã hợp lệ và không trùng, nội dung không rỗng,
## tiến độ và phần thưởng trong giới hạn, cùng mã điều kiện được hỗ trợ.
func is_valid() -> bool:
	if steps.is_empty() or steps.size() > 100:
		return false
	var ids: Dictionary = {}
	for step: ObjectiveDefinition in steps:
		if step == null or not String(step.objective_id).is_valid_identifier() or ids.has(step.objective_id):
			return false
		if step.title.is_empty() or step.description.is_empty() or step.required < 1 or step.required > 1000000 or step.reward_coins < 1 or step.reward_coins > 1000000000:
			return false
		if step.state_condition:
			if step.condition not in [&"prepared_soil", &"own_animal", &"land_columns"]:
				return false
		elif step.condition not in [&"till", &"plant", &"water_crop", &"harvest", &"sell_produce", &"refill_food", &"refill_water"]:
			return false
		ids[step.objective_id] = true
	return true
