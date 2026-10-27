extends SceneTree

func _initialize() -> void:
	call_deferred("_build")

func attach(parent: Node, child: Node, scene_owner: Node) -> void:
	parent.add_child(child)
	child.owner = scene_owner

func save_scene(node: Node, path: String) -> void:
	var uid: int = ResourceLoader.get_resource_uid(path)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(node) == OK)
	packed.take_over_path(path)
	assert(ResourceSaver.save(packed, path) == OK)
	if uid > 0:
		assert(ResourceSaver.set_uid(path, uid) == OK)

func _build() -> void:
	var actor: StaticBody2D = StaticBody2D.new()
	actor.name = "FlowerPot"
	actor.set_script(load("res://components/flowers/flower_pot.gd"))
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.collision_mask = 0
	var visual: Node2D = Node2D.new()
	visual.name = "VisualRoot"
	visual.set_script(load("res://components/flowers/flower_pot_visual.gd"))
	attach(actor, visual, actor)
	var pot: Sprite2D = Sprite2D.new()
	pot.name = "PotSprite"
	pot.centered = false
	pot.position = Vector2(-16, -24)
	pot.texture = load("res://assets/Flowers/Unzoom30/clay_pot_32x24.png")
	attach(visual, pot, actor)
	var socket: Node2D = Node2D.new()
	socket.name = "PlantSocket"
	socket.position = Vector2(0, -15)
	attach(visual, socket, actor)
	var offset: Node2D = Node2D.new()
	offset.name = "PlantOffset"
	attach(socket, offset, actor)
	var plant: AnimatedSprite2D = AnimatedSprite2D.new()
	plant.name = "Flower"
	plant.centered = false
	plant.position = Vector2(-16, -30)
	plant.sprite_frames = load("res://flowers/frames/flower_01_stage_1.tres")
	plant.animation = &"grow"
	plant.visible = false
	# Same z as the pot: the whole actor must keep participating in world Y-sort.
	plant.z_index = 0
	attach(offset, plant, actor)
	visual.set("pot_sprite", pot)
	visual.set("plant_socket", socket)
	visual.set("plant_offset", offset)
	visual.set("flower", plant)
	var focus: Sprite2D = Sprite2D.new()
	focus.name = "Focus"
	focus.position = Vector2(0, -8)
	focus.texture = load("res://resources/ui/soil_focus.tres")
	focus.visible = false
	attach(actor, focus, actor)
	var progress: TextureRect = TextureRect.new()
	progress.name = "Progress"
	progress.position = Vector2(-7.5, -58)
	progress.size = Vector2(15, 7)
	progress.visible = false
	progress.z_index = 2
	progress.z_as_relative = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.texture = load("res://assets/Ui/progress_bar.png")
	attach(actor, progress, actor)
	var bar: ProgressBar = ProgressBar.new()
	bar.name = "Bar"
	bar.position = Vector2(2, 2)
	bar.size = Vector2(11, 2)
	bar.max_value = 1
	bar.step = 0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", load("res://flowers/progress_empty.tres"))
	bar.add_theme_stylebox_override("fill", load("res://flowers/progress_fill.tres"))
	bar.size = Vector2(11, 2)
	attach(progress, bar, actor)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.position = Vector2(0, -2)
	collision.shape = load("res://flowers/pot_collision.tres")
	attach(actor, collision, actor)
	actor.set("visual", visual)
	actor.set("sprite", plant)
	actor.set("marker", focus)
	actor.set("progress_frame", progress)
	actor.set("bar", bar)
	# Resolve theme minimum-size changes before serializing the 2px fill bar.
	root.add_child(actor)
	await process_frame
	bar.size = Vector2(11, 2)
	save_scene(actor, "res://scenes/flowers/flower_pot.tscn")
	root.remove_child(actor)
	actor.free()
	var garden: Node2D = load("res://scenes/flowers/flower_garden.tscn").instantiate() as Node2D
	var container: Node2D = garden.get_node("Pots") as Node2D
	for old: Node in container.get_children():
		old.free()
	var names: Array[String] = ["BlockTopLeft", "BlockTopRight", "BlockBottomLeft", "BlockBottomRight"]
	var layout: Script = load("res://scripts/flower_garden_layout.gd")
	var scene: PackedScene = ResourceLoader.load("res://scenes/flowers/flower_pot.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	for block: int in range(4):
		var group: Node2D = Node2D.new()
		group.name = names[block]
		group.position = Vector2((block % 2) * 192, (block / 2) * 128)
		group.y_sort_enabled = true
		attach(container, group, garden)
		for y: int in range(4):
			for x: int in range(7):
				var cell: Vector2i = Vector2i(x + (block % 2)*7, y + (block / 2)*4)
				var instance: Node2D = scene.instantiate() as Node2D
				instance.name = "Pot_%02d_%02d" % [cell.x, cell.y]
				instance.set("cell", cell)
				instance.position = layout.position_for(cell) - group.position
				var preview_path: String = "res://flowers/definitions/flower_%02d.tres" % ((cell.y*14+cell.x)%30+1)
				instance.set("preview_flower", load(preview_path))
				attach(group, instance, garden)
				garden.set_editable_instance(instance, true)
	save_scene(garden, "res://scenes/flowers/flower_garden.tscn")
	garden.free()
	print("SCENE_BUILD_OK: separate pot/flower nodes; 112 serialized instances in four editable blocks")
	quit()
