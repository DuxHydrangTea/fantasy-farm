class_name CharacterBase
extends CharacterBody2D

@onready var animation_component: AnimationComponent = $AnimationComponent
@onready var state_machine: StateMachine = $StateMachine
@onready var movement_component: MovementComponent = $MovementComponent

var movement_vector: Vector2 = Vector2.ZERO
const MOVE_DEADZONE_SQ := 0.01

func _ready() -> void:
	state_machine.init(self)
	
func has_move_intent() -> bool:
	return movement_vector.length_squared() > MOVE_DEADZONE_SQ
