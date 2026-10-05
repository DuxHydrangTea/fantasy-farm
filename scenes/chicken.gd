extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer

var current_anim: StringName = &"idle_down_left"
var anim_list: PackedStringArray = []
var anim_count: int = 0

func _ready() -> void:
	animated_sprite.play(current_anim)
	anim_list = animated_sprite.sprite_frames.get_animation_names()
	anim_count = anim_list.size()
	timer.wait_time = randf_range(1.0, 10.0)
	
func _on_timer_timeout() -> void:
	_update_rand_anim()

func _update_rand_anim():
	current_anim = anim_list[randi() % anim_count]
	animated_sprite.play(current_anim)
	
