extends RefCounted
## Gắn điểm thu sản phẩm vào các chuồng và tòa nhà tương ứng trong thế giới.
## Mỗi chuồng sở hữu bộ đệm sản phẩm và điểm tương tác riêng.

## Tìm chuồng và tòa nhà đã biết, bật kho và tạo điểm thu cho từng cặp tồn tại.
## Chuồng bò cho phép chọn sản phẩm trên bảng trạng thái.
func configure(world: Node2D) -> void:
	var entrances: Array[Array] = [
		["CoopPen", "Coop", Vector2(0, 12), preload("res://items/animal_produces/chicken_egg.tres")],
		["BarnPen", "Barn", Vector2(0, 12), preload("res://items/animal_produces/cow_milk.tres")],
		["PondPen", "PondPen/DuckShelter", Vector2(52, -36), preload("res://items/animal_produces/duck_egg.tres")],
	]
	for entrance: Array in entrances:
		var pen: AnimalPen = world.get_node_or_null(entrance[0]) as AnimalPen
		var building: Node2D = world.get_node_or_null(entrance[1]) as Node2D
		if pen == null or building == null:
			continue
		pen.produce_storage_enabled = true
		var access: StaticBody2D = load("res://scenes/animals/pen_produce_access.tscn").instantiate() as StaticBody2D
		access.pen = pen
		access.building = building
		access.default_product = entrance[3]
		access.choose_product = pen.name == &"BarnPen"
		access.position = entrance[2]
		pen.produce_access = access
		building.add_child(access)
