extends "res://tests/support/grass_gpu_chunks_poc.gd"
## 1 player + 86 animated actor proxies; gameplay/AI remain untouched.
var herd: Array[Node2D] = []
var origins: Array[Vector2] = []
var moving_herd: bool = true
var _g3_time: float = 0.0

func _ready() -> void:
	super._ready()
	field.set_interactions_enabled(true)
	field.interactions.register_actor(player)
	field.interactions.register_actor(animal, 18)
	for i: int in range(85):
		var member: Node2D = _marker(Color("9dcfff"))
		var point: Vector2 = Vector2(180 + i % 12 * 24, 120 + floori(float(i) / 12.0) * 25)
		member.position = point
		add_child(member)
		herd.append(member)
		origins.append(point)
		field.interactions.register_actor(member, 14)

func _marker(color: Color) -> Node2D:
	var root: Node2D = Node2D.new()
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	var path: String = "res://sprite_frames/character/farmer_bob_frames.tres" if color == Color("f6c54a") else "res://sprite_frames/animals/cow_01_frames.tres"
	sprite.sprite_frames = load(path) as SpriteFrames
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"idle_down", 0)
	sprite.offset.y = -float(texture.get_height()) * 0.5
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play(&"idle_down")
	root.add_child(sprite)
	return root

func _process(delta: float) -> void:
	var animal_before: Vector2 = animal.position
	var elapsed_before: float = _elapsed
	super._process(delta)
	if moving_herd:
		_g3_time += delta
		for i: int in range(herd.size()):
			herd[i].position = origins[i] + Vector2(sin(_g3_time * 1.2 + i) * 12, cos(_g3_time * 0.8 + i) * 10)
	else:
		animal.position = animal_before
		_elapsed = elapsed_before
	var stats: Dictionary = field.interactions.stats()
	_hud.text = "G3 GRASS / arrows move player / wheel zoom\nI interaction / U 30-60 Hz / M freeze herd\nC chunk / H hide / R reload / F teleport\nActors eligible %d / uploaded %d / capacity %d\nRegistry %d / rate %d Hz / grass nodes 1\nGPU wind + footprint + swept capsule\n%s" % [stats.eligible, stats.uploaded, stats.capacity, stats.registered, field.interaction_hz, stats.error]

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_I:
				field.set_interactions_enabled(not field.interaction_enabled)
				if field.interaction_enabled:
					field.interactions.register_actor(player)
					field.interactions.register_actor(animal, 18)
					for member: Node2D in herd:
						field.interactions.register_actor(member, 14)
			KEY_U:
				field.interaction_hz = 30 if field.interaction_hz == 60 else 60
			KEY_M:
				moving_herd = not moving_herd
			KEY_F:
				player.position += Vector2(320, 0)
				field.interactions.reset_motion(player)
