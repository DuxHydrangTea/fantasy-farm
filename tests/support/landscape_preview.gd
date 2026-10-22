extends Node
## Render the authored farm and verify clear planting/road space without binding saves.
var world: FarmWorld

func _ready() -> void:
	_preview.call_deferred()

func _preview() -> void:
	world = load("res://world/main_world.tscn").instantiate() as FarmWorld
	get_tree().root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.weather.day_night.ambient.color = Color.WHITE
	world.weather.hud.hide()
	for light: PointLight2D in world.weather.day_night.lights:
		light.enabled = false
	world.player.camera.enabled = false
	for child: Node in world.player.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).hide()
	var camera: Camera2D = Camera2D.new()
	camera.position = Vector2(1110, 830)
	camera.zoom = Vector2(0.67, 0.67)
	world.add_child(camera)
	for index: int in range(5):
		await get_tree().physics_frame
	_validate()
	for index: int in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var output: Image = get_viewport().get_texture().get_image()
	output.save_png("res://.godot/landscape-overview.png")
	camera.position = Vector2(1440, 590)
	camera.zoom = Vector2(1.65, 1.65)
	for index: int in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/landscape-detail.png")
	# Exercise real animation and animal movement in this non-persistent preview world.
	var butterflies: Array[Node] = world.get_node("FarmLandscape/ButterflySwarm").get_children()
	var before: Array[Vector2] = []
	for butterfly: Node in butterflies:
		before.append((butterfly as AnimatedSprite2D).position)
	world.process_mode = Node.PROCESS_MODE_INHERIT
	await get_tree().create_timer(2.0).timeout
	var moved: int = 0
	var playing: int = 0
	for index: int in range(butterflies.size()):
		var butterfly: AnimatedSprite2D = butterflies[index] as AnimatedSprite2D
		if butterfly.position.distance_to(before[index]) > 1.0:
			moved += 1
		if butterfly.is_playing():
			playing += 1
	print("LANDSCAPE_MOTION ", JSON.stringify({"butterfly_count": butterflies.size(), "butterflies_moving": moved, "animations_playing": playing}))
	print("LANDSCAPE_PREVIEW_OK")
	get_tree().quit()

func _validate() -> void:
	var landscape: Node2D = world.get_node("FarmLandscape") as Node2D
	var blocked: Array[String] = []
	var plots: int = 0
	for kind: int in [TreeDefinition.Kind.FRUIT, TreeDefinition.Kind.TIMBER]:
		var region: Rect2i = TreePlantation.region_for(kind as TreeDefinition.Kind)
		var definition: TreeDefinition = world.trees.definitions[&"apple" if kind == TreeDefinition.Kind.FRUIT else &"oak"]
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				var cell: Vector2i = Vector2i(x, y)
				if TreePlantation.valid_cell(cell, kind as TreeDefinition.Kind):
					plots += 1
					if not world.trees.can_place(cell, definition):
						blocked.append("plant " + str(cell))
	var road: TileMapLayer = world.get_node("Road") as TileMapLayer
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(10, 6)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = 7
	var road_cells: int = 0
	for cell: Vector2i in road.get_used_cells():
		road_cells += 1
		query.transform = Transform2D(0, road.map_to_local(cell))
		for hit: Dictionary in world.get_world_2d().direct_space_state.intersect_shape(query):
			var collider: Node = hit["collider"] as Node
			if landscape.is_ancestor_of(collider):
				blocked.append("road " + str(cell) + " " + str(collider.name))
	var farm_cells: int = 0
	for y: int in range(19, 53):
		for x: int in range(9, 57):
			farm_cells += 1
			query.transform = Transform2D(0, Vector2(x * 16 + 8, y * 16 + 8))
			for hit: Dictionary in world.get_world_2d().direct_space_state.intersect_shape(query):
				var collider: Node = hit["collider"] as Node
				if landscape.is_ancestor_of(collider):
					blocked.append("farm " + str(Vector2i(x, y)))
	var access_points: int = 0
	for trough: Node in get_tree().get_nodes_in_group(&"animal_troughs"):
		if trough is AnimalTrough and world.is_ancestor_of(trough):
			for offset: Vector2 in (trough as AnimalTrough).access_offsets:
				access_points += 1
				query.transform = Transform2D(0, (trough as AnimalTrough).to_global(offset))
				for hit: Dictionary in world.get_world_2d().direct_space_state.intersect_shape(query):
					if landscape.is_ancestor_of(hit["collider"] as Node):
						blocked.append("trough " + str(trough.name))
	print("LANDSCAPE_VALIDATION ", JSON.stringify({"planting_positions": plots, "farm_plots": farm_cells, "road_cells": road_cells, "trough_access_points": access_points, "blocked": blocked}))
	if not blocked.is_empty():
		push_error("Landscape blocks gameplay: " + str(blocked))
