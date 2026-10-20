@tool
extends Node2D
## Four 9x5 blocks at 16px spacing, preserving the cross aisle and garden rim.
const Layout = preload("res://scripts/flower_garden_layout.gd")
const Pot = preload("res://components/flowers/flower_pot.gd")
const Clock = preload("res://components/time_manager.gd")
const Pickup = preload("res://components/item_pickup.gd")
const PICKUP_SCENE: PackedScene = preload("res://scenes/objects/item_pickup.tscn")
const POT_SCENE: PackedScene = preload("res://scenes/flowers/flower_pot.tscn")
@export var persistent_id: StringName = &"flower_garden_01"
@export var time_manager: Clock
var pots: Dictionary[Vector2i, Pot] = {}
var starter_flowers_added: bool = false
var _initial_supplies: Array[Dictionary] = []
const SIZE: Vector2 = Vector2(384, 256)

func _ready() -> void:
	for y: int in range(Layout.ROWS):
		for x: int in range(Layout.COLUMNS):
			var pot: Pot = POT_SCENE.instantiate() as Pot
			pot.name = "Pot_%02d_%02d" % [x, y]
			pot.cell = Vector2i(x, y)
			pot.position = Layout.position_for(pot.cell)
			$Pots.add_child(pot)
			pots[pot.cell] = pot
	if Engine.is_editor_hint():
		add_starter_flowers(1000.0)
		return
	for child: Node in get_children():
		if child is Pickup:
			_initial_supplies.append({"id": child.persistent_id, "position": child.position, "item": child.item, "amount": child.amount})
	add_to_group(&"flower_gardens")
	if time_manager == null:
		time_manager = get_node("/root/TimeManager") as Clock
	time_manager.tick.connect(refresh)
	add_starter_flowers(time_manager.now())

## One-time starting plants, also applied to old saves without this content flag.
## Occupied pots are preserved; harvested starting plants never respawn on load.
func add_starter_flowers(now: float) -> void:
	if starter_flowers_added:
		return
	starter_flowers_added = true
	var cells: Array[Vector2i] = [Vector2i(1, 0), Vector2i(3, 0), Vector2i(6, 0), Vector2i(8, 0), Vector2i(1, 4), Vector2i(3, 4), Vector2i(6, 4), Vector2i(8, 4)]
	var ids: Array[int] = [1, 3, 5, 7, 2, 4, 6, 10]
	var progress: Array[float] = [0.0, 0.25, 0.5, 1.0, 0.0, 0.5, 0.75, 1.0]
	for index: int in range(cells.size()):
		var pot: Pot = pots[Layout.from_legacy(cells[index])]
		if pot.definition != null:
			continue
		var path: String = "res://flowers/definitions/flower_%02d.tres" % ids[index]
		var flower: Resource = load(path)
		var planted: float = maxf(0.0, now - progress[index] * flower.growth_seconds)
		var watered: bool = progress[index] > 0.0
		pot.restore_state({"planted_at": planted, "growth_started_at": planted if watered else -1.0,
			"matures_at": planted + flower.growth_seconds if watered else 0.0, "progress": progress[index]}, flower, now)

func refresh(now: float) -> void:
	for pot: Pot in pots.values():
		pot.refresh(now)

func capture(now: float) -> Dictionary:
	var flowers: Array[Dictionary] = []
	for pot: Pot in pots.values():
		if pot.definition != null:
			flowers.append(pot.capture(now))
	return {"id": String(persistent_id), "flowers": flowers, "starter_flowers_added": starter_flowers_added}

func reset() -> void:
	starter_flowers_added = false
	for pot: Pot in pots.values():
		pot.clear()

func restore_initial_supplies() -> void:
	for row: Dictionary in _initial_supplies:
		var pickup: Pickup = PICKUP_SCENE.instantiate() as Pickup
		pickup.persistent_id = row.id
		pickup.position = row.position
		pickup.item = row.item
		pickup.amount = row.amount
		add_child(pickup)

func focused_pot(point: Vector2, facing: Vector2) -> Pot:
	var nearest: Pot
	var distance: float = 28.0
	for pot: Pot in pots.values():
		var offset: Vector2 = pot.global_position - point
		var length: float = offset.length()
		if length <= distance and length > 2.0 and offset.normalized().dot(facing) > 0.4:
			distance = length
			nearest = pot
	return nearest
