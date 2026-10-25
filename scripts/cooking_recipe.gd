class_name CookingRecipe
extends Resource
## Shipped recipe data; ingredients and output are allowlisted ItemDefinitions.
@export var recipe_id: StringName
@export var display_name: String
@export var ingredients: Array[ItemDefinition] = []
@export var amounts: Array[int] = []
@export var output: ItemDefinition
@export_range(1.0, 86400.0) var cook_seconds: float = 14400.0

func valid() -> bool:
	if recipe_id.is_empty() or ingredients.is_empty() or ingredients.size() != amounts.size() or output == null or output.item_type != ItemDefinition.ItemType.PRODUCE or not is_finite(cook_seconds) or cook_seconds < 1.0:
		return false
	var seen: Dictionary = {}
	for i: int in range(ingredients.size()):
		if ingredients[i] == null or amounts[i] < 1 or amounts[i] > 32000 or seen.has(ingredients[i].item_id):
			return false
		seen[ingredients[i].item_id] = true
	return true
