class_name ItemPickup
extends Area2D
@export var sprite: Sprite2D
@export var quantity_label: Label
@export var persistent_id: StringName
## Inventory-aware adaptation of the Godot skill's collectible template.
signal collected(item: ItemDefinition, amount: int)
@export var item: ItemDefinition
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

func collect(inventory: InventoryComponent) -> int:
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
	if sprite != null:
		sprite.texture = item.icon if item != null else null
	if quantity_label != null:
		quantity_label.visible = amount > 1 and (item == null or item.show_world_quantity)
		quantity_label.text = str(amount) if amount <= 999 else "999+"
