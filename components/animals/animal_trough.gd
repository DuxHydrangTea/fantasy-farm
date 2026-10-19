extends StaticBody2D
## Shared, finite food/water supply. Reservations prevent two animals using one slot.
const Definition = preload("res://scripts/animals/animal_definition.gd")
const Needs = preload("res://components/animals/animal_needs_component.gd")
const Pen = preload("res://components/animals/animal_pen.gd")
const Inventory = preload("res://components/inventory_component.gd")
const Item = preload("res://scripts/item_definition.gd")
enum Kind { FOOD, WATER }
signal stock_changed(amount: int)
@export var kind: Kind = Kind.WATER
@export var pen: Pen
@export_range(1, 32000) var capacity: int = 120
@export_range(0, 32000) var stock: int = 120:
	set(value):
		stock = clampi(value, 0, capacity)
		stock_changed.emit(stock)
		if is_node_ready():
			_update_visual()
@export_range(1.0, 100.0) var restoration_per_unit: float = 40.0
@export_range(0.05, 10.0) var serving_seconds: float = 1.5
## Empty permits every species; definitions supply species-specific portion sizes.
@export var allowed_species: Array[int] = []
@export var access_offsets: Array[Vector2] = [Vector2(-9, 12), Vector2(9, 12), Vector2(-9, -12), Vector2(9, -12), Vector2(-24, 0), Vector2(24, 0)]
@export var full_texture: Texture2D
@export var empty_texture: Texture2D
@export_group("Player Refilling")
@export var feed_item: Item
@export_range(1, 32000) var water_per_use: int = 30
var _occupants: Dictionary[int, WeakRef] = {}
var _refilling: bool = false

## Whole packages only: never discard feed when the remaining space is too small.
func feed_items_needed(inventory: Inventory) -> int:
	if kind != Kind.FOOD or inventory == null or feed_item == null or feed_item.item_type != Item.ItemType.FEED:
		return 0
	var units: int = maxi(1, feed_item.food_units_per_item)
	return mini(floori(float(maxi(0, capacity - stock)) / units), inventory.count_item(feed_item.item_id))

func refill_from_inventory(inventory: Inventory) -> int:
	if _refilling:
		return 0
	var packages: int = feed_items_needed(inventory)
	if packages <= 0:
		return 0
	_refilling = true
	var removed: int = inventory.remove(feed_item.item_id, packages)
	var added: int = refill(removed * maxi(1, feed_item.food_units_per_item))
	_refilling = false
	return added

func _ready() -> void:
	if pen == null:
		pen = get_parent() as Pen
	stock = stock
	add_to_group(&"animal_troughs")
	_update_visual()

func portion_size(data: Definition) -> int:
	return maxi(1, data.food_per_meal if kind == Kind.FOOD else data.water_per_drink)

func can_supply(data: Definition) -> bool:
	return data != null and restoration_per_unit > 0.0 and stock >= portion_size(data) and (allowed_species.is_empty() or int(data.species) in allowed_species)

func access_position(slot: int) -> Vector2:
	return to_global(access_offsets[slot])

func slot_available(slot: int, animal: Node2D = null) -> bool:
	if slot < 0 or slot >= access_offsets.size():
		return false
	var reference: WeakRef = _occupants.get(slot)
	var occupant: Object = reference.get_ref() if reference != null else null
	if not is_instance_valid(occupant) or (occupant is Node and not (occupant as Node).is_inside_tree()):
		_occupants.erase(slot)
		return true
	return occupant == animal

func claim(animal: Node2D, slot: int, data: Definition) -> bool:
	if not is_instance_valid(animal) or not animal.is_inside_tree() or not can_supply(data) or not slot_available(slot, animal):
		return false
	_occupants[slot] = weakref(animal)
	return true

func owns_slot(animal: Node2D, slot: int) -> bool:
	var reference: WeakRef = _occupants.get(slot)
	return reference != null and reference.get_ref() == animal

func release(animal: Node2D) -> void:
	for slot: int in _occupants.keys():
		var reference: WeakRef = _occupants[slot]
		if reference.get_ref() == null or reference.get_ref() == animal:
			_occupants.erase(slot)

## No stock is spent until a reserved animal is physically at its serving point.
func serve(animal: Node2D, needs: Needs, data: Definition, slot: int) -> float:
	if not is_instance_valid(animal) or not is_instance_valid(needs) or not can_supply(data) or not owns_slot(animal, slot):
		return 0.0
	if slot < 0 or slot >= access_offsets.size() or animal.global_position.distance_to(access_position(slot)) > 3.0:
		return 0.0
	var units: int = portion_size(data)
	var amount: float = restoration_per_unit * units
	var restored: float = needs.feed(amount) if kind == Kind.FOOD else needs.drink(amount)
	if restored > 0.0:
		stock -= units
	return restored

func refill(units: int) -> int:
	var before: int = stock
	stock += maxi(0, units)
	return stock - before

func _update_visual() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = full_texture if stock > 0 else empty_texture
