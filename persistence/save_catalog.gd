class_name SaveCatalog
extends RefCounted
## Danh mục resource có sẵn trong game dùng để kiểm tra và khôi phục save.
## Các mã trong JSON được đối chiếu với danh mục thay vì tải đường dẫn từ save.

## Mã vật phẩm sang ItemDefinition.
var items: Dictionary = {}
## Mã cây trồng sang CropDefinition.
var crops: Dictionary = {}
## Mã vật nuôi sang AnimalDefinition.
var animals: Dictionary = {}
## Mã skin vật nuôi sang đường dẫn SpriteFrames đã quét.
var skins: Dictionary = {}
## Mã hoa sang FlowerDefinition.
var flowers: Dictionary = {}
## Mã cây sang TreeDefinition.
var trees: Dictionary = {}

func _init() -> void:
	_scan_items("res://items")
	for file: String in ResourceLoader.list_directory("res://trees/definitions"):
		if file.ends_with(".tres"):
			var definition: TreeDefinition = load("res://trees/definitions/" + file) as TreeDefinition
			if definition != null:
				trees[String(definition.tree_id)] = definition
	for file: String in ResourceLoader.list_directory("res://flowers/definitions"):
		if file.ends_with(".tres"):
			var flower: FlowerDefinition = load("res://flowers/definitions/" + file) as FlowerDefinition
			if flower != null:
				flowers[String(flower.flower_id)] = flower
	for entry: String in ResourceLoader.list_directory("res://crops/field"):
		if not entry.ends_with("/"):
			continue
		var folder: String = entry.trim_suffix("/")
		var path: String = "res://crops/field/%s/%s.tres" % [folder, folder]
		if ResourceLoader.exists(path):
			var crop: CropDefinition = load(path) as CropDefinition
			if crop != null:
				crops[String(crop.crop_id)] = crop
	for file: String in ResourceLoader.list_directory("res://animals/definitions"):
		if file.ends_with(".tres"):
			var animal: AnimalDefinition = load("res://animals/definitions/" + file) as AnimalDefinition
			if animal != null:
				animals[String(animal.animal_id)] = animal
	for file: String in ResourceLoader.list_directory("res://sprite_frames/animals"):
		if file.ends_with("_frames.tres"):
			skins[file.trim_suffix("_frames.tres")] = "res://sprite_frames/animals/" + file

func _scan_items(folder: String) -> void:
	for file: String in ResourceLoader.list_directory(folder):
		if file.ends_with(".tres"):
			var item: ItemDefinition = load(folder + "/" + file) as ItemDefinition
			if item != null:
				items[String(item.item_id)] = item
		elif file.ends_with("/"):
			_scan_items(folder + "/" + file.trim_suffix("/"))

## Lấy mã skin từ tên file resource, bỏ hậu tố _frames.tres.
func skin_id(frames: SpriteFrames) -> String:
	return frames.resource_path.get_file().trim_suffix("_frames.tres") if frames != null else ""

## Kiểm tra skin rỗng hoặc skin đã biết phù hợp mã loài.
## Gà còn chấp nhận các skin rooster.
func valid_skin(animal: String, skin: String) -> bool:
	if skin.is_empty():
		return true
	return skins.has(skin) and (skin == animal or skin.begins_with(animal + "_") or (animal == "chicken" and (skin == "rooster" or skin.begins_with("rooster_"))))

## Tải SpriteFrames theo mã đã biết, trả null nếu mã không có trong catalog.
func load_skin(id: String) -> SpriteFrames:
	return load(skins[id]) as SpriteFrames if skins.has(id) else null
