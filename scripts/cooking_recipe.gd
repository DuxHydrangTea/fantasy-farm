class_name CookingRecipe
extends Resource
## Shipped recipe data; ingredients and output are allowlisted ItemDefinitions.
@export var honey_recipe: String = ""
@export var recipe_id: StringName
@export var display_name: String
@export var ingredients: Array[ItemDefinition] = []
@export var amounts: Array[int] = []
@export var ingredient_tiers: Array[int] = []
@export_range(0, 1000000000) var coin_cost: int = 0
@export var output: ItemDefinition
@export_range(1.0, 86400.0) var cook_seconds: float = 14400.0

func valid() -> bool:
	if coin_cost < 0 or coin_cost > WalletComponent.MAX_COINS or recipe_id.is_empty() or ingredients.is_empty() or ingredients.size() != amounts.size() or output == null or (output.item_type != ItemDefinition.ItemType.PRODUCE and output.item_type != ItemDefinition.ItemType.MATERIAL and not (output.item_type == ItemDefinition.ItemType.BOOSTER and output.booster_kind == ItemDefinition.BoosterKind.ROOT_TONIC)) or not is_finite(cook_seconds) or cook_seconds < 1.0:
		return false
	if not ingredient_tiers.is_empty() and ingredient_tiers.size() != ingredients.size():
		return false
	var seen: Dictionary = {}
	for i: int in range(ingredients.size()):
		if ingredients[i] == null or amounts[i] < 1 or amounts[i] > 32000 or seen.has(ingredients[i].item_id):
			return false
		if not ItemQuality.supported(ingredients[i], tier_at(i)):
			return false
		seen[ingredients[i].item_id] = true
	return true

func tier_at(index: int) -> int:
	return ingredient_tiers[index] if index >= 0 and index < ingredient_tiers.size() else 0
