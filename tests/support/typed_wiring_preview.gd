extends Node
## Full farm playtest without binding or writing the user's local save profile.
const WORLD: PackedScene = preload("res://world/main_world.tscn")
var world: FarmWorld

func _ready() -> void:
	world = WORLD.instantiate() as FarmWorld
	add_child(world)
	assert(world.player.farming_actions.farming == world.farming)
	print("typed_wiring_preview_ready")
