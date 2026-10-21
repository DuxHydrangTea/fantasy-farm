class_name BeeVisualComponent
extends Node2D
## Cosmetic only. Hidden bees stop processing; production is owned by the farm clock.
var hive: Beehive
var _bees: Array[AnimatedSprite2D] = []
var _phase: float = 0.0
var _on_screen: bool = false
var _sheltered: bool = false

func set_sheltered(value: bool) -> void:
	if _sheltered == value:
		return
	_sheltered = value
	_visibility(_on_screen)

func _ready() -> void:
	z_index = 2
	for index: int in range(2):
		var bee: AnimatedSprite2D = AnimatedSprite2D.new()
		bee.sprite_frames = preload("res://sprite_frames/animals/bee_frames.tres")
		bee.play(&"fly" if index == 0 else &"fly_alt")
		add_child(bee)
		_bees.append(bee)
	var notifier: VisibleOnScreenNotifier2D = VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-144,-144,288,288)
	notifier.screen_entered.connect(_visibility.bind(true))
	notifier.screen_exited.connect(_visibility.bind(false))
	add_child(notifier)
	_phase = float(String(hive.persistent_id).hash() % 1000) / 100.0
	_visibility(false)

func _visibility(value: bool) -> void:
	# Keep this CanvasItem visible: its child notifier must see the screen to
	# wake the bees again. Hiding this parent also hides the notifier permanently.
	_on_screen = value
	value = value and not _sheltered
	set_process(value)
	for bee: AnimatedSprite2D in _bees:
		bee.visible = value
		if value:
			bee.play()
		else:
			bee.pause()
	if value:
		_process(0.0)

func _process(delta: float) -> void:
	_phase += delta * 1.8
	var destination: Vector2 = to_local(hive.pollination.source_point) if hive.pollination.active() else Vector2(22,0)
	for index: int in range(_bees.size()):
		var t: float = _phase + index * PI
		var bee: AnimatedSprite2D = _bees[index]
		bee.position = destination * (0.5 - 0.5*cos(t)) + Vector2(sin(t*2)*7,-12-absf(sin(t))*6)
		bee.flip_h = sin(t) < 0
