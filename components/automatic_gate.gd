extends StaticBody2D
## Opens for nearby farm players; separate radii prevent flickering at the edge.

@export_range(8.0, 256.0, 1.0) var open_distance: float = 48.0
@export_range(8.0, 256.0, 1.0) var close_distance: float = 64.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var is_open: bool = false

func _ready() -> void:
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play(&"closed")
	_update_proximity()

func _physics_process(_delta: float) -> void:
	_update_proximity()

func _update_proximity() -> void:
	var radius: float = maxf(open_distance, close_distance) if is_open else open_distance
	var nearby: bool = false
	for candidate: Node in get_tree().get_nodes_in_group(&"farm_players"):
		var player: Node2D = candidate as Node2D
		if player == null or player.is_queued_for_deletion() or player.get_viewport() != get_viewport():
			continue
		if global_position.distance_squared_to(player.global_position) <= radius * radius:
			nearby = true
			break
	if nearby != is_open:
		_set_open(nearby)

func _set_open(opened: bool) -> void:
	is_open = opened
	var next_animation: StringName = &"open" if opened else &"close"
	var reversing: bool = sprite.animation == &"open" or sprite.animation == &"close"
	var previous_frame: int = sprite.frame
	var previous_progress: float = sprite.frame_progress
	sprite.play(next_animation)
	# Both asset animations use the same five poses in opposite order.
	if reversing:
		var last_frame: int = sprite.sprite_frames.get_frame_count(next_animation) - 1
		sprite.set_frame_and_progress(last_frame - previous_frame, 1.0 - previous_progress)

func _on_animation_finished() -> void:
	sprite.play(&"opened" if is_open else &"closed")
