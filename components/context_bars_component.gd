class_name ContextBarsComponent
extends Node2D
## One focused target and one mouse target; targets own their UI and attention response.
## Crop hover uses cell lookup, avoiding a scan through every planted field tile.
@export var mouse_padding: float = 5.0
@export var animal_focus_reach: float = 32.0
@export var refresh_interval: float = 0.05
@export var player: FarmPlayer
@export var animation: AnimationComponent
@export var actions: FarmingActionComponent
@export var selection: ToolSelectionComponent
@export var trough_interaction: TroughInteractionComponent
@export var flower_interaction: FlowerInteraction
@export var animal_info: AnimalInfoPanel
var _visible: Array[Node2D] = []
var _bounds: Dictionary[Texture2D, Rect2] = {}
var _elapsed: float = 0.0

func _ready() -> void:
	if animal_info == null:
		animal_info = preload("res://scenes/ui/animal_info.tscn").instantiate() as AnimalInfoPanel
		add_child(animal_info)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < refresh_interval:
		return
	_elapsed = 0.0
	refresh_at(get_global_mouse_position(), get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position()))

func refresh_at(mouse_world: Vector2, pointer_inside: bool = true) -> void:
	var next: Array[Node2D] = []
	var inspected: AnimalActor
	if not selection.is_menu_open():
		var focused: Node2D = _focused_target()
		if is_instance_valid(focused):
			next.append(focused)
			inspected = focused as AnimalActor
		var hovered: Node2D = _hovered_target(mouse_world) if pointer_inside else null
		if is_instance_valid(hovered) and not next.has(hovered):
			next.append(hovered)
		if hovered is AnimalActor:
			inspected = hovered as AnimalActor
	for target: Node2D in _visible:
		if is_instance_valid(target) and not target.is_queued_for_deletion() and not next.has(target):
			target.set_status_focused(false)
	for target: Node2D in next:
		target.set_status_focused(true)
	_visible = next
	if is_instance_valid(animal_info):
		animal_info.inspect(inspected)

func _exit_tree() -> void:
	if is_instance_valid(animal_info):
		animal_info.inspect(null)
	for target: Node2D in _visible:
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			target.set_status_focused(false)

func _focused_target() -> Node2D:
	if player.interactions != null and player.interactions.focused != null:
		var target: InteractionTarget = player.interactions.focused
		if target.valid() and target.priority() < 3:
			return target.node if target.kind == InteractionTarget.Kind.ANIMAL else null
	if trough_interaction != null and is_instance_valid(trough_interaction.focused_trough):
		return null
	if flower_interaction != null and is_instance_valid(flower_interaction.focused_pot):
		return flower_interaction.focused_pot
	var nearest: AnimalActor
	var distance: float = animal_focus_reach * animal_focus_reach
	for node: Node in get_tree().get_nodes_in_group(&"animal_status_targets"):
		var animal: AnimalActor = node as AnimalActor
		if not is_instance_valid(animal) or animal.is_queued_for_deletion():
			continue
		var offset: Vector2 = animal.global_position - player.global_position
		if offset.length_squared() <= distance and offset.normalized().dot(animation.facing_vector) > 0.5:
			distance = offset.length_squared()
			nearest = animal
	if nearest != null:
		return nearest
	var farm: Node = actions.get_farming_controller()
	return farm.get_crop(actions.get_focused_cell()) as Node2D if farm != null else null

# Tối ưu tìm cây dưới chuột: đổi chuột sang ô đất rồi chỉ thử vùng 5x5 ô quanh đó,
# thay vì duyệt toàn bộ hàng nghìn cây. Vùng lân cận còn bắt được tán vươn khỏi ô gốc.
# Sau đó đổi chuột world -> local sprite để hit-test theo ảnh thật, kể cả camera zoom/scale/rotation.
# Nếu so tọa độ màn hình trực tiếp với rect local, hover sẽ lệch khi zoom hoặc camera di chuyển.
# Chỉ giữ một focus và một hover để không hiện hàng loạt thanh cùng lúc; số mục tiêu là lựa chọn UI.
func _hovered_target(point: Vector2) -> Node2D:
	var candidates: Array[Node2D] = []
	for node: Node in get_tree().get_nodes_in_group(&"animal_status_targets"):
		var animal: AnimalActor = node as AnimalActor
		if is_instance_valid(animal):
			candidates.append(animal)
	for node: Node in get_tree().get_nodes_in_group(&"flower_gardens"):
		for pot: FlowerPot in (node as FlowerGarden).pots.values():
			if pot.definition != null:
				candidates.append(pot)
	var farm: Node = actions.get_farming_controller()
	if farm != null and farm.farmland != null and farm.farmland.tile_set != null:
		var center: Vector2i = farm.world_to_cell(point)
		for y: int in range(-2, 3):
			for x: int in range(-2, 3):
				var crop: Node2D = farm.get_crop(center + Vector2i(x, y)) as Node2D
				if crop != null:
					candidates.append(crop)
	var nearest: Node2D
	var distance: float = INF
	for target: Node2D in candidates:
		if target.is_queued_for_deletion():
			continue
		var sprite: Node2D = target.get_status_sprite()
		var rect: Rect2 = _sprite_bounds(sprite)
		var local_point: Vector2 = sprite.to_local(point)
		if rect.has_area() and rect.grow(mouse_padding).has_point(local_point):
			var score: float = point.distance_squared_to(sprite.to_global(rect.get_center()))
			if score < distance:
				distance = score
				nearest = target
	return nearest

func _sprite_bounds(sprite: Node2D) -> Rect2:
	var texture: Texture2D
	if sprite is Sprite2D:
		texture = (sprite as Sprite2D).texture
	elif sprite is AnimatedSprite2D:
		var animated: AnimatedSprite2D = sprite as AnimatedSprite2D
		if animated.sprite_frames != null and animated.sprite_frames.has_animation(animated.animation) and animated.sprite_frames.get_frame_count(animated.animation) > 0:
			texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
	if texture == null:
		return Rect2()
	if not _bounds.has(texture):
		var image: Image = texture.get_image()
		_bounds[texture] = Rect2(image.get_used_rect()) if image != null else Rect2(Vector2.ZERO, texture.get_size())
	var used: Rect2 = _bounds[texture]
	var size: Vector2 = texture.get_size()
	if bool(sprite.get("flip_h")):
		used.position.x = size.x - used.end.x
	if bool(sprite.get("flip_v")):
		used.position.y = size.y - used.end.y
	used.position += Vector2(sprite.get("offset")) - (size * 0.5 if bool(sprite.get("centered")) else Vector2.ZERO)
	return used
