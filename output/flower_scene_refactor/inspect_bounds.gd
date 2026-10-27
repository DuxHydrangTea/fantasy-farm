extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var garden: Variant = load("res://scenes/flowers/flower_garden.tscn").instantiate()
	root.add_child(garden)
	var pot: Variant = garden.pots[Vector2i.ZERO]
	var bounds: Rect2 = Rect2()
	var initialized: bool = false
	for i: int in range(1,31):
		var path: String = "res://flowers/definitions/flower_%02d.tres" % i
		var definition: Resource = load(path)
		for frames: SpriteFrames in definition.stage_frames:
			pot.visual.show_plant(frames)
			for f: int in range(6):
				pot.sprite.frame = f
				var rect: Rect2 = pot.get_visual_rect()
				bounds = bounds.merge(rect) if initialized else rect
				initialized = true
	print("BOUNDS=",bounds," pot=",pot.visual.pot_sprite.position," socket=",pot.visual.plant_socket.position," flower=",pot.sprite.position)
	print("POSITION=",pot.global_position," placed=",Rect2(pot.global_position+bounds.position,bounds.size))
	quit()
