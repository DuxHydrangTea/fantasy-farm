extends Node2D
## Isolated scene for UI layout reporting; does not bind personal saves.
func _ready() -> void:
	Language.set_language("vi")
	var world: FarmWorld = preload("res://world/main_world.tscn").instantiate() as FarmWorld
	world.name = "Farm"
	add_child(world)
	world.tool_upgrades.profile_ready = true
	var carrot: ItemDefinition = preload("res://items/harvest_produces/carrot_produces.tres")
	world.player.selection.inventory.add(carrot, 80, 0)
	world.player.selection.inventory.add(carrot, 40, 1)
	var access: FarmStorageAccess = world.storage_accesses["produce_warehouse"]
	world.player.global_position = access.global_position + Vector2(0, 24)
	access.open_shop(world.player)
	var menu: FarmStorageMenu = access.menu as FarmStorageMenu
	menu.name = "StorageMenu"
	menu._select(carrot.item_id, true)
	set_meta("menu_path", str(get_path_to(menu.root)))
