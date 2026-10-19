extends Area2D
## A reusable pickup sensor. Bind an Inventory directly or a node exposing it.
const Inventory = preload("res://components/inventory_component.gd")
const Pickup = preload("res://components/item_pickup.gd")
@export var inventory: Inventory
@export var inventory_source: Node
var _collecting: bool = false

func _ready() -> void:
	if inventory == null and inventory_source != null:
		inventory = inventory_source as Inventory
		if inventory == null:
			inventory = inventory_source.get("inventory") as Inventory
	if inventory == null:
		return
	area_entered.connect(_on_area_entered)
	inventory.changed.connect(_collect_overlaps)

func _on_area_entered(area: Area2D) -> void:
	var pickup: Pickup = area as Pickup
	if pickup != null and inventory != null:
		pickup.collect(inventory)

func _collect_overlaps() -> void:
	if _collecting or inventory == null or not is_inside_tree():
		return
	_collecting = true
	for area: Area2D in get_overlapping_areas():
		_on_area_entered(area)
	_collecting = false
