class_name ActorState
extends Node

func enter() -> void:
	print("Entered state: ", name)
	
func exit() -> void:
	print("Exited state: ", name)

func handle_direction(_dir: Vector2) -> void:
	pass
