class_name ChefCooking
extends RefCounted
## One serial queue owned by the farm, independent of the Chef scene and UI.
signal changed
const CAPACITY: int = 20
const RECIPES: Array[CookingRecipe] = [preload("res://resources/kitchen/recipes/fried_egg.tres"), preload("res://resources/kitchen/recipes/steamed_egg.tres"), preload("res://resources/kitchen/recipes/bread.tres"), preload("res://resources/kitchen/recipes/fruit_salad.tres"), preload("res://resources/kitchen/recipes/honey_bread.tres"), preload("res://resources/kitchen/recipes/root_tonic.tres")]
var queue: Array[Dictionary] = []
var ready: Array[String] = []
var updated_at: float = 0.0
var busy: bool = false

static func find(id: String) -> CookingRecipe:
	for recipe: CookingRecipe in RECIPES:
		if String(recipe.recipe_id) == id:
			return recipe
	return null

static func fresh() -> Dictionary:
	return {"queue": [], "ready": [], "updated_at": 0.0}

static func valid(data: Variant, saved_at: float) -> bool:
	if not data is Dictionary or data.size() != 3 or not data.get("queue") is Array or not data.get("ready") is Array or not SaveSchema.number(data.get("updated_at"), 0.0, saved_at) or data.queue.size() + data.ready.size() > CAPACITY:
		return false
	var previous: float = float(data.updated_at)
	for row: Variant in data.queue:
		if not row is Dictionary or row.size() != 2 or not row.get("recipe") is String or find(row.recipe) == null or not SaveSchema.number(row.get("finish_at"), previous + 0.001):
			return false
		if previous != float(data.updated_at) and absf(float(row.finish_at) - previous - find(row.recipe).cook_seconds) > 0.01:
			return false
		previous = float(row.finish_at)
	for id: Variant in data.ready:
		if not id is String or find(id) == null:
			return false
	return true

func advance(now: float, notify: bool = true) -> void:
	if busy or not is_finite(now) or now < 0.0:
		return
	updated_at = maxf(updated_at, now)
	var completed: bool = false
	while not queue.is_empty() and float(queue[0].finish_at) <= updated_at:
		ready.append(String(queue.pop_front().recipe))
		completed = true
	if completed and notify:
		changed.emit()

func capture(now: float) -> Dictionary:
	advance(now, false)
	return {"queue": queue.duplicate(true), "ready": ready.duplicate(), "updated_at": updated_at}

func restore(data: Dictionary, now: float) -> void:
	queue.clear()
	for row: Dictionary in data.queue:
		queue.append(row.duplicate(true))
	ready.assign(data.ready)
	updated_at = float(data.updated_at)
	advance(now, false)

func quote(id: String, amount: int, inventory: InventoryComponent) -> String:
	var recipe: CookingRecipe = find(id)
	if busy or recipe == null or not recipe.valid() or inventory == null or amount < 1 or amount > CAPACITY:
		return "Cooking is unavailable."
	if queue.size() + ready.size() + amount > CAPACITY:
		return "Chef is full. Collect dishes first (20 maximum)."
	for i: int in range(recipe.ingredients.size()):
		if inventory.count_item(recipe.ingredients[i].item_id, recipe.tier_at(i)) < recipe.amounts[i] * amount:
			return "Not enough ingredients."
	return ""

func start(id: String, amount: int, inventory: InventoryComponent, now: float) -> String:
	if busy:
		return "Cooking is unavailable."
	advance(now, false)
	var error: String = quote(id, amount, inventory)
	if not error.is_empty():
		return error
	busy = true
	var recipe: CookingRecipe = find(id)
	for i: int in range(recipe.ingredients.size()):
		inventory.consume(recipe.ingredients[i].item_id, recipe.amounts[i] * amount, ItemQuality.exact(recipe.tier_at(i)), false)
	var finish: float = maxf(updated_at, float(queue.back().finish_at) if not queue.is_empty() else updated_at)
	for i: int in range(amount):
		finish += recipe.cook_seconds
		queue.append({"recipe": id, "finish_at": finish})
	inventory.changed.emit()
	changed.emit()
	busy = false
	return ""

func collect(inventory: InventoryComponent, now: float) -> int:
	if busy or inventory == null:
		return 0
	advance(now, false)
	busy = true
	var collected: int = 0
	# Commit source removal before inventory notification; reentrant collection is locked.
	for index: int in range(ready.size() - 1, -1, -1):
		var item: ItemDefinition = find(ready[index]).output
		if inventory.capacity_for(item) < 1:
			continue
		ready.remove_at(index)
		collected += inventory.add(item, 1)
	if collected > 0:
		changed.emit()
	busy = false
	return collected
