extends Node2D

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.size = Vector2i(900, 600)
	var world: Node2D = load("res://world/main_world.tscn").instantiate() as Node2D
	var original_fence: TileMapLayer = world.get_node("Fence") as TileMapLayer
	assert(world.y_sort_enabled and original_fence.y_sort_enabled)
	var container: Node2D = Node2D.new()
	container.y_sort_enabled = world.y_sort_enabled
	container.scale = Vector2(6, 6)
	container.position = Vector2(450, 300)
	add_child(container)
	var fence: TileMapLayer = TileMapLayer.new()
	fence.tile_set = original_fence.tile_set
	fence.y_sort_enabled = original_fence.y_sort_enabled
	for x: int in range(-2, 3):
		fence.set_cell(Vector2i(x, 0), 1, Vector2i(2, 0))
	container.add_child(fence)
	var actor: Node2D = Node2D.new()
	container.add_child(actor)
	var actor_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	actor_sprite.sprite_frames = load("res://sprite_frames/character/farmer_bob_frames.tres") as SpriteFrames
	actor_sprite.animation = &"idle_down"
	actor_sprite.position = Vector2(0, -7)
	actor.add_child(actor_sprite)
	for value: float in [8.0, 24.0]:
		actor.position = Vector2(8, value)
		for frame: int in range(6):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://debug_saves/fence_sort/" + ("behind" if value < 16.0 else "front") + ".png")
	print("FENCE_SORT_PREVIEW_OK")
	world.free()
	get_tree().quit()
