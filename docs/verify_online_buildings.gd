extends SceneTree

func _initialize() -> void:
	var cases: Dictionary = {
		"SeedInventory": ["seed_storage", "farm_supply_storage"],
		"Warehouse": ["produce_warehouse", "produce_warehouse"],
		"BlacksmithShop": ["tool_upgrade_store", ""],
		"PetShop": ["livestock_shop", ""],
		"House1": ["restaurant", ""],
		"FlowerShop": ["flower_seed_store", ""],
		"SeedFlowerShop": ["crop_seed_store", ""]
	}
	var packed: PackedScene = load("res://world/main_world.tscn") as PackedScene
	assert(packed != null)
	var world: Node = packed.instantiate()
	for label: String in cases:
		var data: Array = cases[label]
		var building: Node = world.get_node(label)
		assert(building.scene_file_path == "res://scenes/buildings/online_farm/" + str(data[0]) + ".tscn")
		assert(building.get_script() == null)
		var sprite: Sprite2D = building.get_node("Sprite2D") as Sprite2D
		assert(sprite.texture != null)
		assert(sprite.texture.resource_path.begins_with("res://assets/Buildings/online-assets/buildings/"))
		var count: int = 0
		for child: Node in building.get_children():
			if child is CollisionShape2D:
				assert((child as CollisionShape2D).shape != null)
				count += 1
		assert(count > 0)
		if str(data[1]) != "":
			var access: Node = building.get_node("StorageAccess")
			assert(access.get("storage_id") == data[1])
			assert(access.has_node("InteractionArea/CollisionShape2D"))
		print("ONLINE_BUILDING_OK ", label, " texture=", sprite.texture.get_size(), " colliders=", count)
	assert(world.has_node("BlacksmithMerchant"))
	assert(world.has_node("PetMerchant"))
	assert(world.has_node("Chef"))
	assert(world.get_node("LaiBuon").get("catalog").resource_path == "res://resources/shops/seed_flower_shop.tres")
	assert(world.get_node("FlowerMerchant").get("catalog").resource_path == "res://resources/shops/flower_shop.tres")
	assert(world.get_node("Chef").get_script() != null)
	world.free()
	print("ONLINE_BUILDINGS_VERIFIED")
	quit()
