class_name BoosterInteractionComponent
extends Node2D
## Player-side input/presentation adapter. StateComponent owns the tool animation.
var player: FarmPlayer
var service: BoosterService = BoosterService.new()
var _animal: AnimalActor
var _cell: Vector2i
var _item: ItemDefinition
var _slot: int = -1
var _pending: StringName = &""
var _feedback: String = ""
var _feedback_until: int = 0

func _ready() -> void:
	player.state.state_changed.connect(_state_changed)
	player.animation.animated_sprite.frame_changed.connect(_frame_changed)
	player.animation.animated_sprite.animation_changed.connect(_frame_changed, CONNECT_DEFERRED)

func selected_booster() -> ItemDefinition:
	var item: ItemDefinition = player.selection.get_selected_item()
	return item if item != null and item.item_type == ItemDefinition.ItemType.BOOSTER else null

func find_animal() -> AnimalActor:
	var nearest: AnimalActor
	var distance: float = 32.0 * 32.0
	for node: Node in get_tree().get_nodes_in_group(&"animal_status_targets"):
		var animal: AnimalActor = node as AnimalActor
		if animal == null or animal.is_queued_for_deletion() or not animal.is_visible_in_tree():
			continue
		var offset: Vector2 = animal.global_position - player.global_position
		if offset.length_squared() > distance or offset.normalized().dot(player.animation.facing_vector) < 0.5:
			continue
		var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(player.global_position, animal.global_position, 1, [player.get_rid()])
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		distance = offset.length_squared()
		nearest = animal
	return nearest

func prepare_action() -> StringName:
	_pending = &""
	_item = selected_booster()
	if _item == null:
		return &""
	_slot = player.selection.selected_index
	_cell = player.farming_actions.get_focused_cell()
	_animal = find_animal() if _item.booster_kind == ItemDefinition.BoosterKind.ANIMAL_TONIC else null
	_pending = &"fertilize" if _item.booster_kind == ItemDefinition.BoosterKind.FERTILIZER else &"animal_tonic"
	return _pending

func _state_changed(_old: StringName, current: StringName) -> void:
	if current != &"tool":
		_pending = &""
		_animal = null

func _frame_changed() -> void:
	if _pending.is_empty() or not player.animation.impact_reached(3):
		return
	var action: StringName = _pending
	_pending = &""
	if player.state.current_state != StateComponent.State.TOOL or player.state.active_action != action or player.selection.is_menu_open() or player.selection.selected_index != _slot or selected_booster() != _item:
		return
	if action == &"animal_tonic" and (not is_instance_valid(_animal) or find_animal() != _animal):
		_feedback = "Face a nearby animal to use the tonic."
	else:
		var result: Dictionary = service.use(player.farming_actions.get_farming_controller(), _cell, _animal, player.selection.inventory, _slot, _item, player)
		_feedback = "Booster applied!" if result.ok else String(result.error)
	_feedback_until = Time.get_ticks_msec() + 1800

func feedback_source() -> String:
	if Time.get_ticks_msec() >= _feedback_until or player.selection.selected_index != _slot:
		return ""
	return _feedback
