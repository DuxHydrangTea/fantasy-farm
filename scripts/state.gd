class_name State
extends Node

var actor: CharacterBase
var state_machine: StateMachine
var animation_component: AnimationComponent
var movement_component: MovementComponent

func setup(p_actor: CharacterBase, p_state_machine: StateMachine) -> void:
	actor = p_actor
	state_machine = p_state_machine
	animation_component = p_actor.animation_component
	movement_component = p_actor.movement_component

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
