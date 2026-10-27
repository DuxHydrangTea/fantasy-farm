class_name BeeVisualComponent
extends Node2D
## Cosmetic only. Hidden bees stop processing; production is owned by the farm clock.
const BEE_COUNT: int = 6
const ROAM_RADIUS: float = 64.0
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
	for index: int in range(BEE_COUNT):
		var bee: AnimatedSprite2D = AnimatedSprite2D.new()
		bee.sprite_frames = preload("res://sprite_frames/animals/bee_frames.tres")
		bee.play(&"fly" if index % 2 == 0 else &"fly_alt")
		add_child(bee)
		_bees.append(bee)
	var notifier: VisibleOnScreenNotifier2D = VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-160,-160,320,320)
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
	var gathering: bool = hive.pollination.active()
	var source: Vector2 = to_local(hive.pollination.source_point) if gathering else Vector2.ZERO
	for index: int in range(_bees.size()):
		var offset: float = float(index) * TAU / float(_bees.size())
		var t: float = _phase + offset
		var destination: Vector2 = source if gathering else Vector2.from_angle(offset) * ROAM_RADIUS
		var bee: AnimatedSprite2D = _bees[index]
		bee.position = destination * (0.5 - 0.5*cos(t)) + Vector2(sin(t*2+offset)*18,-12-absf(sin(t))*14)
		bee.flip_h = sin(t) < 0
