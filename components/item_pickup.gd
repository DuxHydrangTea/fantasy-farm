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
var _attractor: ItemCollector
var _resting_sprite_position: Vector2
var _flight_seconds: float = 0.0

@export var attraction_speed: float = 140.0
@export var attraction_acceleration: float = 600.0

func _ready() -> void:
	add_to_group(&"item_pickups")
	_update_display()
	if sprite != null:
		_resting_sprite_position = sprite.position
	set_physics_process(false)

func is_attracting() -> bool:
	return is_instance_valid(_attractor)

func attract_to(collector: ItemCollector) -> bool:
	if is_attracting() or _collecting or is_queued_for_deletion() or collector == null or sprite == null or not collector.can_accept(self):
		return false
	_attractor = collector
	_flight_seconds = 0.0
	if quantity_label != null:
		quantity_label.hide()
	set_physics_process(true)
	return true

func cancel_attraction() -> void:
	_attractor = null
	set_physics_process(false)
	if sprite != null:
		sprite.position = _resting_sprite_position
	_update_display()

func _physics_process(delta: float) -> void:
	if is_instance_valid(_attractor) and _attractor.inventory != null and item != null and amount > 0 and _attractor.inventory.capacity_for(item) == 0:
		_attractor.inventory.report_capacity_blocked(item, amount)
	if not is_instance_valid(_attractor) or not _attractor.can_accept(self) or global_position.distance_to(_attractor.global_position) > _attractor.attraction_radius * 2.0:
		cancel_attraction()
		return
	_flight_seconds += delta
	var target: Vector2 = _attractor.global_position + Vector2(0, -6)
	var step: float = (attraction_speed + attraction_acceleration * _flight_seconds) * delta
	# Move only the visual. Save coordinates and an animal's linked pile stay stable.
	sprite.global_position = sprite.global_position.move_toward(target, step)
	if sprite.global_position.distance_squared_to(target) <= 1.0:
		var collector: ItemCollector = _attractor
		var accepted: int = collect(collector.inventory)
		cancel_attraction()
		if accepted > 0 and is_instance_valid(collector):
			collector.item_acquired.emit(item, accepted)

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
		quantity_label.visible = not is_attracting() and amount > 1 and (item == null or item.show_world_quantity)
		quantity_label.text = str(amount) if amount <= 999 else "999+"
