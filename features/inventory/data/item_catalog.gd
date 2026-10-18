class_name ItemCatalog
extends Resource

@export var items: Array[ItemDefinition] = []

var _by_id: Dictionary[StringName, ItemDefinition] = {}

func build_index() -> bool:
	var next_index: Dictionary[StringName, ItemDefinition] = {}
	
	for definition: ItemDefinition in items:
		if definition == null or not definition.is_valid():
			push_error("ItemCatalog chứa vật phẩm thiếu hoặc không hợp lệ")
			return false
		if next_index.has(definition.item_id):
			push_error("ItemCatalog trùng ID: %s" % definition.item_id)
			return false
		next_index[definition.item_id] = definition
	
	_by_id = next_index
	return true

func get_item(item_id: StringName) -> ItemDefinition:
	return _by_id.get(item_id) as ItemDefinition
