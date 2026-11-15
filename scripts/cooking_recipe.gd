class_name CookingRecipe
extends Resource
## Công thức chế biến gồm nguyên liệu, chi phí, sản phẩm và thời gian nấu.
##
## Các mảng nguyên liệu, số lượng và chất lượng tương ứng theo chỉ số.
## Mảng chất lượng rỗng biểu thị cấp mặc định cho mọi nguyên liệu.

## Mã công thức mật ong liên quan, nếu có.
@export var honey_recipe: String = ""
## Mã ổn định nhận diện công thức.
@export var recipe_id: StringName
## Tên hiển thị.
@export var display_name: String
## Các loại vật phẩm cần dùng.
@export var ingredients: Array[ItemDefinition] = []
## Số lượng tương ứng với từng nguyên liệu.
@export var amounts: Array[int] = []
## Cấp chất lượng tương ứng, hoặc để trống để dùng cấp 0.
@export var ingredient_tiers: Array[int] = []
## Chi phí bằng xu.
@export_range(0, 1000000000) var coin_cost: int = 0
## Định nghĩa vật phẩm tạo ra.
@export var output: ItemDefinition
## Thời gian nấu tính bằng giây.
@export_range(1.0, 86400.0) var cook_seconds: float = 14400.0

## Kiểm tra mã, chi phí, thời gian, loại sản phẩm và các dòng nguyên liệu.
## Mỗi nguyên liệu phải khác null, có số lượng 1–32.000, mã không trùng và
## hỗ trợ cấp chất lượng tương ứng. Thời gian phải hữu hạn và ít nhất một giây.
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

## Trả về cấp chất lượng tại [param index], hoặc 0 nếu chỉ số ngoài mảng.
func tier_at(index: int) -> int:
	return ingredient_tiers[index] if index >= 0 and index < ingredient_tiers.size() else 0
