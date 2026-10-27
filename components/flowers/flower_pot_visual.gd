@tool
class_name FlowerPotVisual
extends Node2D
## Two independent layers. PlantOffset and VisualRoot transforms stay editor-owned.
@export var pot_sprite: Sprite2D
@export var plant_socket: Node2D
@export var plant_offset: Node2D
@export var flower: AnimatedSprite2D
var _pot: PotDefinition
var _bounds: Dictionary[Texture2D, Rect2] = {}

func apply_definition(value: PotDefinition) -> void:
	if value == _pot:
		return
	if _pot != null and _pot.changed.is_connected(_apply_pot):
		_pot.changed.disconnect(_apply_pot)
	_pot = value
	if _pot != null:
		_pot.changed.connect(_apply_pot)
	_apply_pot()

func _apply_pot() -> void:
	if _pot == null or pot_sprite == null or plant_socket == null:
		return
	pot_sprite.texture = _pot.texture
	pot_sprite.position = _pot.pot_offset
	plant_socket.position = _pot.plant_socket
	_bounds.clear()

func show_plant(frames: SpriteFrames) -> void:
	if flower == null:
		return
	flower.visible = frames != null
	if frames != null and flower.sprite_frames != frames:
		flower.sprite_frames = frames
		flower.play(&"grow")

func status_sprite() -> Node2D:
	return flower if flower != null and flower.visible else pot_sprite

func _clear_bounds() -> void:
	_bounds.clear()

func bounds_in(reference: Node2D) -> Rect2:
	var result: Rect2 = Rect2()
	var initialized: bool = false
	for layer: Node2D in [pot_sprite, flower]:
		if layer == null or not layer.visible:
			continue
		var texture: Texture2D
		if layer is Sprite2D:
			texture = (layer as Sprite2D).texture
		else:
			var animated: AnimatedSprite2D = layer as AnimatedSprite2D
			if animated.sprite_frames != null and animated.sprite_frames.has_animation(animated.animation):
				texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		if texture == null:
			continue
		if not _bounds.has(texture):
			var image: Image = texture.get_image()
			_bounds[texture] = Rect2(image.get_used_rect()) if image != null else Rect2(Vector2.ZERO, texture.get_size())
			if not texture.changed.is_connected(_clear_bounds):
				texture.changed.connect(_clear_bounds)
		var rect: Rect2 = _bounds[texture]
		if not rect.has_area():
			continue
		var size: Vector2 = texture.get_size()
		if layer is Sprite2D and (layer as Sprite2D).region_enabled:
			size = (layer as Sprite2D).region_rect.size
			rect = Rect2(Vector2.ZERO, size)
		if bool(layer.get("flip_h")):
			rect.position.x = size.x - rect.end.x
		if bool(layer.get("flip_v")):
			rect.position.y = size.y - rect.end.y
		rect.position += Vector2(layer.get("offset")) - (size * 0.5 if bool(layer.get("centered")) else Vector2.ZERO)
		var relative: Transform2D = reference.global_transform.affine_inverse() * layer.global_transform
		var transformed: Rect2 = relative * rect
		result = result.merge(transformed) if initialized else transformed
		initialized = true
	return result
