@tool
class_name PotDefinition
extends Resource
## Appearance only. Gameplay ownership remains on FlowerPot.
@export var pot_id: StringName = &"clay":
	set(value):
		pot_id = value
		emit_changed()
@export var texture: Texture2D:
	set(value):
		texture = value
		emit_changed()
@export var pot_offset: Vector2 = Vector2(-16, -24):
	set(value):
		pot_offset = value
		emit_changed()
@export var plant_socket: Vector2 = Vector2(0, -15):
	set(value):
		plant_socket = value
		emit_changed()
