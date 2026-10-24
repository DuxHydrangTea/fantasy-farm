class_name ObjectiveCatalog
extends Resource
@export var steps: Array[ObjectiveDefinition] = []

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
