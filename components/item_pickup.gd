extends Area2D
## Inventory-aware adaptation of the Godot skill's collectible template.
const Item = preload("res://scripts/item_definition.gd")
const Inventory = preload("res://components/inventory_component.gd")
signal collected(item: Item, amount: int)
@export var item: Item
@export_range(0, 2147483647) var amount: int = 1:
	set(value):
		amount = maxi(0, value)
		if is_node_ready():
			_update_display()
var _collecting: bool = false

func _ready() -> void:
	add_to_group(&"item_pickups")
	_update_display()

func add_amount(count: int) -> void:
	amount += maxi(0, count)

func collect(inventory: Inventory) -> int:
	if _collecting or is_queued_for_deletion() or inventory == null or item == null or amount <= 0:
		return 0
	_collecting = true
	var accepted: int = inventory.add(item, amount)
	amount -= accepted
	if amount == 0:
		queue_free()
	if accepted > 0:
		collected.emit(item, accepted)
	_collecting = false
	return accepted

func _update_display() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = item.icon if item != null else null
	var label: Label = get_node_or_null("Quantity") as Label
	if label != null:
		label.visible = amount > 1
		label.text = str(amount) if amount <= 999 else "999+"
