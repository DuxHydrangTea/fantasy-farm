class_name FarmWorld
extends Node2D
## MainWorld composition root. References are serialized in the scene.
@export var player: FarmPlayer
@export var farming: FarmingController

func _enter_tree() -> void:
	assert(player != null and farming != null, "Assign MainWorld player and farming references")
	player.farming_actions.farming = farming
