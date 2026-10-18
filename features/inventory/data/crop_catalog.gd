class_name CropCatalog
extends Resource

@export var crops: Array[CropDefinition] = []

var _by_seed_id: Dictionary[StringName, CropDefinition] = {}

func build_index() -> bool:
	var next_index: Dictionary[StringName, CropDefinition] = {}
	
	for crop: CropDefinition in crops:
		if crop == null or not crop.is_valid():
			push_error("CropCatalog chứa cây thiếu hoặc không hợp lệ.")
			return false
		
		var seed_id: StringName = crop.seed_item.item_id
		
		if next_index.has(seed_id):
			push_error("CropCatalog trùng ID hạt: %s" % seed_id)
			return false
		
		next_index[seed_id] = crop
	
	_by_seed_id = next_index
	return true

func get_crop_by_seed(seed_id: StringName) -> CropDefinition:
	return _by_seed_id.get(seed_id) as CropDefinition
