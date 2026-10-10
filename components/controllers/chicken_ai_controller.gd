class_name ChickenController
extends Controller

@onready var decision_timer: Timer = $Timer

const WALK_DIRECTIONS: Array[Vector2] = [
	Vector2.LEFT,
	Vector2.RIGHT,
	Vector2.UP,
	Vector2.DOWN,
]

func _ready() -> void:
	super._ready()
	decision_timer.timeout.connect(_choose_behavior)
	decision_timer.start(1)

func _choose_behavior() -> void:
	decision_timer.start(randf_range(2.0, 4.0))
	
	var current: State = actor.state_machine.current_state
	
	if not (current is WalkState or current is IdleState):
		return
	
	match randi_range(0, 4):
		0:
			actor.movement_vector = Vector2.ZERO
			actor.state_machine.change_state(&"idle")
		1:
			var index: int = randi_range(0, WALK_DIRECTIONS.size() - 1)
			actor.movement_vector = WALK_DIRECTIONS[index]
			actor.state_machine.change_state(&"walk")
		2:
			actor.state_machine.change_state(&"peck")
		3:
			actor.state_machine.change_state(&"rest")
		4:
			actor.state_machine.change_state(&"sleep")
