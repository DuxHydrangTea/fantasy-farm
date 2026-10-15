@tool
extends SceneTree

func _init() -> void:
	print("--- Bắt đầu tạo animal resources ---")

	var produces_dir := "res://features/inventory/items/animal_produces"
	var productions_dir := "res://entities/animals/productions"
	var definitions_dir := "res://entities/animals/definitions"

	DirAccess.make_dir_recursive_absolute(produces_dir)
	DirAccess.make_dir_recursive_absolute(productions_dir)
	DirAccess.make_dir_recursive_absolute(definitions_dir)

	var configs := [
		{
			"species_enum": AnimalTypes.Species.COW,
			"animal_id": &"cow",
			"display_name": "Bò",
			"frames_path": "res://entities/animals/animations/cow_01_frames.tres",
			"has_production": true,
			"item_id": &"cow_milk",
			"item_name": "Sữa bò",
			"icon_path": "res://common/ui/icons/textures/no_outline/food/food_r10_c08.tres",
			"production_seconds": 60.0,
			"collection_mode": AnimalProductionDefination.CollectionMode.WORLD_DROP,
			"hydration_depletion": 600.0,
			"satiety_depletion": 600.0,
		},
		{
			"species_enum": AnimalTypes.Species.SHEEP,
			"animal_id": &"sheep",
			"display_name": "Cừu",
			"frames_path": "res://entities/animals/animations/sheep_01_frames.tres",
			"has_production": true,
			"item_id": &"sheep_wool",
			"item_name": "Lông cừu",
			"icon_path": "res://common/ui/icons/textures/no_outline/materials/materials_r05_c04.tres",
			"production_seconds": 60.0,
			"collection_mode": AnimalProductionDefination.CollectionMode.WORLD_DROP,
			"hydration_depletion": 600.0,
			"satiety_depletion": 600.0,
		},
		{
			"species_enum": AnimalTypes.Species.DUCK,
			"animal_id": &"duck",
			"display_name": "Vịt",
			"frames_path": "res://entities/animals/animations/duck_01_frames.tres",
			"has_production": true,
			"item_id": &"duck_egg",
			"item_name": "Trứng vịt",
			"icon_path": "res://common/ui/icons/textures/no_outline/food/food_r02_c07.tres",
			"production_seconds": 40.0,
			"collection_mode": AnimalProductionDefination.CollectionMode.WORLD_DROP,
			"hydration_depletion": 300.0,
			"satiety_depletion": 600.0,
		},
		{
			"species_enum": AnimalTypes.Species.GOOSE,
			"animal_id": &"goose",
			"display_name": "Ngỗng",
			"frames_path": "res://entities/animals/animations/goose_01_frames.tres",
			"has_production": true,
			"item_id": &"goose_egg",
			"item_name": "Trứng ngỗng",
			"icon_path": "res://common/ui/icons/textures/no_outline/food/food_r02_c07.tres",
			"production_seconds": 50.0,
			"collection_mode": AnimalProductionDefination.CollectionMode.WORLD_DROP,
			"hydration_depletion": 300.0,
			"satiety_depletion": 600.0,
		},
		{
			"species_enum": AnimalTypes.Species.PIG,
			"animal_id": &"pig",
			"display_name": "Heo",
			"frames_path": "res://entities/animals/animations/pig_01_frames.tres",
			"has_production": true,
			"item_id": &"pig_truffle",
			"item_name": "Nấm Truffle",
			"icon_path": "res://common/ui/icons/textures/no_outline/food/food_r01_c05.tres",
			"production_seconds": 60.0,
			"collection_mode": AnimalProductionDefination.CollectionMode.WORLD_DROP,
			"hydration_depletion": 600.0,
			"satiety_depletion": 600.0,
		},
		{
			"species_enum": AnimalTypes.Species.HORSE,
			"animal_id": &"horse",
			"display_name": "Ngựa",
			"frames_path": "res://entities/animals/animations/horse_01_frames.tres",
			"has_production": false,
			"hydration_depletion": 600.0,
			"satiety_depletion": 600.0,
		},
	]

	for cfg in configs:
		var prod_def: AnimalProductionDefination = null

		if cfg.get("has_production", false):
			# 1. Tạo ItemDefinition
			var item := ItemDefinition.new()
			item.item_id = cfg["item_id"]
			item.display_name = cfg["item_name"]
			item.item_type = ItemDefinition.ItemType.PRODUCE
			item.max_stack = 32000
			if ResourceLoader.exists(cfg["icon_path"]):
				item.icon = load(cfg["icon_path"])
			else:
				push_warning("Không tìm thấy icon: " + cfg["icon_path"])

			var item_path := produces_dir.path_join("%s.tres" % cfg["item_id"])
			var item_err := ResourceSaver.save(item, item_path)
			if item_err != OK:
				push_error("Lỗi lưu item %s: %d" % [item_path, item_err])
				continue
			print("Đã lưu item: ", item_path)
			item = load(item_path)

			# 2. Tạo AnimalProductionDefination
			prod_def = AnimalProductionDefination.new()
			prod_def.production_item = item
			prod_def.production_amount = 1
			prod_def.production_seconds = cfg["production_seconds"]
			prod_def.collection_mode = cfg["collection_mode"]

			var prod_path := productions_dir.path_join("%s_production.tres" % cfg["item_id"])
			var prod_err := ResourceSaver.save(prod_def, prod_path)
			if prod_err != OK:
				push_error("Lỗi lưu production %s: %d" % [prod_path, prod_err])
				continue
			print("Đã lưu production: ", prod_path)
			prod_def = load(prod_path)

		# 3. Tạo AnimalDefinition
		var animal := AnimalDefinition.new()
		animal.animal_id = cfg["animal_id"]
		animal.display_name = cfg["display_name"]
		animal.species = cfg["species_enum"]
		animal.hydration_depletion_seconds = cfg["hydration_depletion"]
		animal.satiety_depletion_seconds = cfg["satiety_depletion"]
		animal.production = prod_def

		if ResourceLoader.exists(cfg["frames_path"]):
			animal.adult_frames = load(cfg["frames_path"])
		else:
			push_error("Không tìm thấy frames: " + cfg["frames_path"])

		if not animal.is_valid():
			push_error("AnimalDefinition không hợp lệ: " + String(cfg["animal_id"]))

		var animal_path := definitions_dir.path_join("%s.tres" % cfg["animal_id"])
		var animal_err := ResourceSaver.save(animal, animal_path)
		if animal_err != OK:
			push_error("Lỗi lưu animal %s: %d" % [animal_path, animal_err])
		else:
			print("Đã lưu animal definition: ", animal_path)

	print("--- Hoàn tất tạo animal resources! ---")
	quit()
