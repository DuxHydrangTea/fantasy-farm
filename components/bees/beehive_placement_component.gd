class_name BeehivePlacementComponent
extends Node2D
## Placement input adapter and world preview; inventory/world mutations stay in ApiarySystem.
signal feedback_changed
var player: FarmPlayer
var range_display: BeehiveRangeDisplay
var ghost: Sprite2D
var _feedback: String = ""
var _feedback_until: int = 0:
	set(value):
		_feedback_until = value
		feedback_changed.emit()

func _ready() -> void:
	range_display = BeehiveRangeDisplay.new()
	range_display.footprint = true
	range_display.z_index = 50
	add_child(range_display)
	ghost = Sprite2D.new()
	ghost.texture = preload("res://resources/bees/beehive.tres").idle_texture
	ghost.position.y = -8
	range_display.add_child(ghost)
	range_display.hide()

func apiary() -> ApiarySystem:
	var farm: FarmingController = player.farming_actions.get_farming_controller()
	return farm.apiary if farm != null else null

func selected() -> bool:
	var item: ItemDefinition = player.selection.get_selected_item()
	return apiary() != null and item == apiary().definition.hive_item

func _process(_delta: float) -> void:
	if not selected() or player.selection.is_menu_open():
		range_display.hide()
		return
	var system: ApiarySystem = apiary()
	var point: Vector2 = system.snap_position(get_global_mouse_position())
	range_display.global_position = point
	range_display.radius = system.effective_radius(system.clock.now())
	range_display.allowed = system.placement_error(point).is_empty() and player.global_position.distance_to(point) <= 96.0
	ghost.modulate = Color(1,1,1,0.7) if range_display.allowed else Color(1,0.35,0.3,0.7)
	range_display.queue_redraw()
	range_display.show()

func click(point: Vector2) -> bool:
	if not selected():
		return false
	player.state.navigation.cancel()
	var result: Dictionary = apiary().place(point,player,player.selection.selected_index)
	_feedback = "Hive placed!" if result.ok else String(result.error)
	_feedback_until = Time.get_ticks_msec()+2000
	return true

func feedback_source() -> String:
	if Time.get_ticks_msec() < _feedback_until:
		return _feedback
	return "Left-click nearby ground to place. Select another slot to cancel." if selected() else ""

func feedback_expires_at() -> int:
	return _feedback_until if not _feedback.is_empty() else 0
