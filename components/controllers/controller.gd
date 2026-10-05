class_name Controller
extends Node

var actor: CharacterBase

func _ready() -> void:
	actor = get_parent() as CharacterBase
	assert(actor != null, "Controller phải là con trực tiếp của CharacterBase")
	# Chạy trước StateMachine để state luôn đọc input mới nhất
	process_physics_priority = -10
