extends SceneTree

func _initialize() -> void:
	var names: Array[String] = ["seed_storage", "produce_warehouse", "cattle_barn", "chicken_coop"]
	for label: String in names:
		var packed: PackedScene = load("res://scenes/buildings/converted_farm/" + label + ".tscn") as PackedScene
		assert(packed != null, label + " loads")
		var building: StaticBody2D = packed.instantiate() as StaticBody2D
		assert(building != null and building.get_script() == null, label + " is independent")
		var sprite: Sprite2D = building.get_node("Sprite2D") as Sprite2D
		assert(sprite.texture != null, label + " has texture")
		var shapes: int = 0
		for child: Node in building.get_children():
			if child is CollisionShape2D:
				assert((child as CollisionShape2D).shape != null)
				shapes += 1
		assert(shapes > 0)
		if label.ends_with("storage") or label == "produce_warehouse":
			assert(building.has_node("StorageAccess/InteractionArea/CollisionShape2D"))
		print("BUILDING_OK ", label, " size=", sprite.texture.get_size(), " colliders=", shapes)
		building.free()
	var world_scene: PackedScene = load("res://world/main_world.tscn") as PackedScene
	assert(world_scene != null)
	var world: Node = world_scene.instantiate()
	for label: String in ["SeedInventory", "Warehouse", "Barn", "Coop"]:
		var building: Node = world.get_node(label)
		assert(building.scene_file_path.begins_with("res://scenes/buildings/converted_farm/"))
		assert(building.get_script() == null)
		print("WORLD_REPLACED ", label, " ", building.scene_file_path)
	world.free()
	print("BUILDING_VERIFICATION_PASSED")
	quit()
