@tool
class_name FlowerGarden
extends Node2D
@export var pot_container: Node2D
## Four authored 5x4 blocks, preserving historical cell IDs.
const Layout = preload("res://scripts/flower_garden_layout.gd")
@export var persistent_id: StringName = &"flower_garden_01"
@export var time_manager: FarmClock
var apiary: ApiarySystem
var pots: Dictionary[Vector2i, FlowerPot] = {}
var _growth: GrowthSchedule = GrowthSchedule.new()
var starter_flowers_added: bool = false
var starter_content_locked: bool = false
var _lock_notice: Label
var _initial_supplies: Array[Dictionary] = []
var _legacy_flowers: Array[Dictionary] = []
const SIZE: Vector2 = Vector2(384, 256)

func _ready() -> void:
	if pot_container == null:
		return
	if not Engine.is_editor_hint():
		var warnings: PackedStringArray = _get_configuration_warnings()
		if not warnings.is_empty():
			push_error("Invalid flower garden scene: " + "; ".join(warnings))
			return
	_register_pots(pot_container)
	if Engine.is_editor_hint():
		return
	for child: Node in get_children():
		if child is ItemPickup:
			_initial_supplies.append({"id": child.persistent_id, "position": child.position, "item": child.item, "amount": child.amount})
			if starter_content_locked:
				child.free()
	add_to_group(&"flower_gardens")
	if time_manager == null:
		time_manager = TimeManager
	time_manager.tick.connect(refresh)
	add_starter_flowers(time_manager.now())
	set_starter_content_locked(starter_content_locked)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if pot_container == null:
		return PackedStringArray(["Assign the Pots container."])
	var cells: Dictionary = {}
	var count: int = 0
	for node: Node in pot_container.find_children("*", "StaticBody2D", true, false):
		if not node is FlowerPot:
			continue
		var pot: FlowerPot = node as FlowerPot
		count += 1
		if cells.has(pot.cell):
			warnings.append("Duplicate pot cell: " + str(pot.cell))
		if not Layout.contains_cell(pot.cell):
			warnings.append("Pot cell outside the authored layout: " + str(pot.cell))
		cells[pot.cell] = true
	if count != Layout.CAPACITY:
		warnings.append("Expected %d authored pots, found %d." % [Layout.CAPACITY, count])
	for cell: Vector2i in HoneyGardenSystem.CENTERS:
		if not cells.has(cell):
			warnings.append("Missing fixed hive cell: " + str(cell))
	return warnings

func _register_pots(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is FlowerPot:
			var pot: FlowerPot = child as FlowerPot
			if pots.has(pot.cell) and pots[pot.cell] != pot:
				push_error("Duplicate flower pot cell: " + str(pot.cell))
				continue
			pot.garden = self
			pots[pot.cell] = pot
			if not pot.changed.is_connected(_pot_changed.bind(pot)):
				pot.changed.connect(_pot_changed.bind(pot))
		else:
			_register_pots(child)

func set_starter_content_locked(value: bool) -> void:
	starter_content_locked = value
	if not is_node_ready() or Engine.is_editor_hint():
		return
	if _lock_notice == null:
		_lock_notice = Label.new()
		_lock_notice.text = "Buy your first land expansion to unlock the flower garden."
		_lock_notice.position = Vector2(32, 112)
		_lock_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lock_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_lock_notice.add_theme_color_override("font_color", Color.WHITE)
		_lock_notice.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
		_lock_notice.add_theme_constant_override("outline_size", 2)
		_lock_notice.add_theme_font_size_override("font_size", 10)
		_lock_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_lock_notice)
		_lock_notice.size = Vector2(320, 24)
	_lock_notice.visible = value
	if not value:
		restore_legacy_flowers()

## One-time starting plants, also applied to old saves without this content flag.
## Occupied pots are preserved; harvested starting plants never respawn on load.
func add_starter_flowers(now: float) -> void:
	if starter_content_locked:
		starter_flowers_added = true
		return
	if starter_flowers_added:
		return
	starter_flowers_added = true
	var cells: Array[Vector2i] = [Vector2i(1, 0), Vector2i(4, 0), Vector2i(8, 0), Vector2i(11, 0), Vector2i(1, 7), Vector2i(4, 7), Vector2i(8, 7), Vector2i(11, 7)]
	var ids: Array[int] = [1, 3, 5, 7, 2, 4, 6, 10]
	var progress: Array[float] = [0.0, 0.25, 0.5, 1.0, 0.0, 0.5, 0.75, 1.0]
	for index: int in range(cells.size()):
		var pot: FlowerPot = pots[cells[index]]
		if pot.definition != null:
			continue
		var path: String = "res://flowers/definitions/flower_%02d.tres" % ids[index]
		var flower: Resource = load(path)
		var planted: float = maxf(0.0, now - progress[index] * flower.growth_seconds)
		var watered: bool = progress[index] > 0.0
		pot.restore_state({"planted_at": planted, "growth_started_at": planted if watered else -1.0,
			"matures_at": planted + flower.growth_seconds if watered else 0.0, "progress": progress[index]}, flower, now)

func refresh(now: float) -> void:
	if apiary != null:
		apiary.advance(now)
	for pot: FlowerPot in _growth.take_due(now):
		pot.refresh(now)
		_schedule_pot(pot)

func _schedule_pot(pot: FlowerPot) -> void:
	_growth.cancel(pot)
	if pot.definition != null and pot.growth_started_at >= 0.0 and not pot.is_mature():
		_growth.schedule(pot, pot.growth_started_at + float(pot.stage + 1) / 4.0 * (pot.matures_at - pot.growth_started_at))

func _pot_changed(pot: FlowerPot) -> void:
	_schedule_pot(pot)
	# Legacy migration runs during load/unlock only. Harvesting or clearing must
	# leave this pot empty; pending legacy plants remain in capture().

func restore_flower(data: Dictionary, flower: FlowerDefinition, now: float) -> void:
	var cell: Vector2i = Vector2i(int(data.cell[0]), int(data.cell[1]))
	if pots.has(cell):
		pots[cell].restore_state(data, flower, now)
	else:
		_legacy_flowers.append(data.duplicate(true))

func restore_legacy_flowers() -> void:
	if _legacy_flowers.is_empty() or starter_content_locked:
		return
	for pot: FlowerPot in pots.values():
		if _legacy_flowers.is_empty():
			break
		if pot.definition != null or pot.reserved or pot.cell in HoneyGardenSystem.CENTERS:
			continue
		var data: Dictionary = _legacy_flowers.pop_front()
		var path: String = "res://flowers/definitions/%s.tres" % String(data.flower)
		var flower: FlowerDefinition = load(path)
		pot.restore_state(data, flower, time_manager.now())

func capture(now: float) -> Dictionary:
	var flowers: Array[Dictionary] = []
	for pot: FlowerPot in pots.values():
		if pot.definition != null:
			flowers.append(pot.capture(now))
	flowers.append_array(_legacy_flowers.duplicate(true))
	return {"id": String(persistent_id), "flowers": flowers, "starter_flowers_added": starter_flowers_added}

func reset() -> void:
	_growth.clear()
	_legacy_flowers.clear()
	starter_flowers_added = false
	for pot: FlowerPot in pots.values():
		pot.clear()

func restore_initial_supplies() -> void:
	if starter_content_locked:
		return
	for row: Dictionary in _initial_supplies:
		var pickup: ItemPickup = ItemPickup.create()
		pickup.persistent_id = row.id
		pickup.position = row.position
		pickup.item = row.item
		pickup.amount = row.amount
		add_child(pickup)

func focused_pot(point: Vector2, facing: Vector2) -> FlowerPot:
	var nearest: FlowerPot
	var distance: float = 28.0
	for pot: FlowerPot in pots.values():
		if pot.reserved:
			continue
		var offset: Vector2 = pot.global_position - point
		var length: float = offset.length()
		if length <= distance and length > 2.0 and offset.normalized().dot(facing) > 0.4:
			distance = length
			nearest = pot
	return nearest
