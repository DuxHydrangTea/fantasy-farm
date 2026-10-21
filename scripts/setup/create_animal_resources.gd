@tool
extends SceneTree

func _init() -> void:
	print("--- Bắt đầu tạo animal resources ---")

	var produces_dir := "res://items/animal_produces"
	var productions_dir := "res://animals/productions"
	var definitions_dir := "res://animals/definitions"

	DirAccess.make_dir_recursive_absolute(produces_dir)
	DirAccess.make_dir_recursive_absolute(productions_dir)
	DirAccess.make_dir_recursive_absolute(definitions_dir)

	var configs := [
		{
			"species_enum": AnimalTypes.Species.COW,
			"animal_id": &"cow",
			"display_name": "Cow",
			"frames_path": "res://sprite_frames/animals/cow_01_frames.tres",
			"has_production": true,
			"item_id": &"cow_milk",
			"item_name": "Cow Milk",
			"icon_path": "res://icons/no_outline/food/food_r10_c08.tres",
			"production_seconds": 60.0,
			"collection_mode": AnimalProductionDefinition.CollectionMode.WORLD_DROP,
			"hydration_depletion": 600.0,
			"satiety_depletion": 600.0,
		},
		{
			"species_enum": AnimalTypes.Species.SHEEP,
			"animal_id": &"sheep",
			"display_name": "Sheep",
			"frames_path": "res://sprite_frames/animals/sheep_01_frames.tres",
			"has_production": true,
			"item_id": &"sheep_wool",
			"item_name": "Wool",
			"icon_path": "res://icons/no_outline/materials/materials_r05_c04.tres",
			"production_seconds": 60.0,
			"collection_mode": AnimalProductionDefinition.CollectionMode.WORLD_DROP,
			"hydration_depletion": 600.0,
			"satiety_depletion": 600.0,
		},
		{
			"species_enum": AnimalTypes.Species.DUCK,
			"animal_id": &"duck",
			"display_name": "Duck",
			"frames_path": "res://sprite_frames/animals/duck_01_frames.tres",
			"has_production": true,
			"item_id": &"duck_egg",
			"item_name": "Duck Egg",
			"icon_path": "res://icons/no_outline/food/food_r02_c07.tres",
			"production_seconds": 40.0,
			"collection_mode": AnimalProductionDefinition.CollectionMode.WORLD_DROP,
			"hydration_depletion": 300.0,
			"satiety_depletion": 600.0,
		},
		{
			"species_enum": AnimalTypes.Species.GOOSE,
			"animal_id": &"goose",
			"display_name": "Goose",
			"frames_path": "res://sprite_frames/animals/goose_01_frames.tres",
			"has_production": true,
			"item_id": &"goose_egg",
			"item_name": "Goose Egg",
			"icon_path": "res://icons/no_outline/food/food_r02_c07.tres",
			"production_seconds": 50.0,
			"collection_mode": AnimalProductionDefinition.CollectionMode.WORLD_DROP,
			"hydration_depletion": 300.0,
			"satiety_depletion": 600.0,
		},
		{
			"species_enum": AnimalTypes.Species.PIG,
			"animal_id": &"pig",
			"display_name": "Pig",
			"frames_path": "res://sprite_frames/animals/pig_01_frames.tres",
			"has_production": true,
			"item_id": &"pig_truffle",
			"item_name": "Truffle",
			"icon_path": "res://icons/no_outline/food/food_r01_c05.tres",
			"production_seconds": 60.0,
			"collection_mode": AnimalProductionDefinition.CollectionMode.WORLD_DROP,
			"hydration_depletion": 600.0,
			"satiety_depletion": 600.0,
		},
		{
			"species_enum": AnimalTypes.Species.HORSE,
			"animal_id": &"horse",
			"display_name": "Horse",
			"frames_path": "res://sprite_frames/animals/horse_01_frames.tres",
			"has_production": false,
			"hydration_depletion": 600.0,
			"satiety_depletion": 600.0,
		},
	]

	for cfg in configs:
		var prod_def: AnimalProductionDefinition = null

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
			prod_def = AnimalProductionDefinition.new()
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
