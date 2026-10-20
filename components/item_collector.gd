class_name ItemCollector
extends Area2D
signal item_acquired(item: ItemDefinition, amount: int)
## A reusable pickup sensor. Bind an Inventory directly or a node exposing it.
@export var inventory: InventoryComponent
@export var inventory_source: ToolSelectionComponent
@export_range(14.0, 160.0) var attraction_radius: float = 48.0
var _collecting: bool = false

func _ready() -> void:
	if inventory == null and inventory_source != null:
		inventory = inventory_source.inventory
	if inventory == null:
		return
	# Duplicate the shape so changing this player's radius cannot affect another.
	for child: Node in get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			child.shape = child.shape.duplicate()
			(child.shape as CircleShape2D).radius = attraction_radius
	area_entered.connect(_on_area_entered)
	inventory.changed.connect(_collect_overlaps)

func _on_area_entered(area: Area2D) -> void:
	var pickup: ItemPickup = area as ItemPickup
	if pickup != null and inventory != null:
		if pickup.item != null and pickup.amount > 0 and inventory.capacity_for(pickup.item) == 0:
			inventory.report_capacity_blocked(pickup.item, pickup.amount)
		else:
			pickup.attract_to(self)

func can_accept(pickup: ItemPickup) -> bool:
	return inventory != null and pickup != null and not pickup.is_queued_for_deletion() and pickup.amount > 0 and pickup.item != null and inventory.capacity_for(pickup.item) > 0

func _collect_overlaps() -> void:
	if _collecting or inventory == null or not is_inside_tree():
		return
	_collecting = true
	for area: Area2D in get_overlapping_areas():
		_on_area_entered(area)
	_collecting = false
