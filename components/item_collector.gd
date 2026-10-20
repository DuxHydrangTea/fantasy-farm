class_name ItemCollector
extends Area2D
## A reusable pickup sensor. Bind an Inventory directly or a node exposing it.
@export var inventory: InventoryComponent
@export var inventory_source: ToolSelectionComponent
var _collecting: bool = false

func _ready() -> void:
	if inventory == null and inventory_source != null:
		inventory = inventory_source.inventory
	if inventory == null:
		return
	area_entered.connect(_on_area_entered)
	inventory.changed.connect(_collect_overlaps)

func _on_area_entered(area: Area2D) -> void:
	var pickup: ItemPickup = area as ItemPickup
	if pickup != null and inventory != null:
		pickup.collect(inventory)

func _collect_overlaps() -> void:
	if _collecting or inventory == null or not is_inside_tree():
		return
	_collecting = true
	for area: Area2D in get_overlapping_areas():
		_on_area_entered(area)
	_collecting = false
