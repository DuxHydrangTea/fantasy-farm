extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	create_timer(20.0).timeout.connect(func() -> void: quit(1))
	assert(Engine.is_editor_hint())
	var scene: PackedScene = load("res://scenes/flowers/flower_garden.tscn")
	var garden: Variant = scene.instantiate()
	root.add_child(garden)
	await process_frame
	assert(garden.pots.size() == 112)
	assert(not garden.starter_flowers_added)
	for pot: Variant in garden.pots.values():
		assert(pot.definition == null)
		assert(pot.planted_at == 0.0)
		assert(pot.growth_started_at == -1.0)
		assert(pot.progress == 0.0)
		assert(pot.preview_flower != null)
		assert(pot.sprite.visible)
	var block: Node2D = garden.get_node("Pots/BlockBottomLeft")
	assert(block.get_child_count() == 28)
	var pot: Variant = garden.pots[Vector2i(0, 4)]
	pot.visual.plant_offset.position = Vector2(2, 3)
	pot.preview_stage = 2
	assert(pot.visual.plant_offset.position == Vector2(2, 3))
	assert(pot.definition == null)
	print("EDITOR_PREVIEW_OK: 112 serialized pots, preview visible, zero gameplay-state mutation, offsets retained")
	garden.free()
	quit()
