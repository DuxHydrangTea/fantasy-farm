class_name GrassSourceCatalog
extends RefCounted
## Catalog cỏ được dựng từ dữ liệu đã bake và atlas khung hình.

## Dữ liệu các loại cỏ.
const DATA = preload("res://resources/grass/grass_catalog_data.gd")
## Đường dẫn atlas dùng để vẽ.
const ATLAS_PATH: String = "res://resources/grass/grass_poc_atlas.png"
## Cạnh ô khung hình trong atlas.
const FRAME_SIZE: int = 16
## Số khung hình mỗi loại.
const FRAME_COUNT: int = 8
## Texture atlas.
var texture: Texture2D = load(ATLAS_PATH) as Texture2D
## Danh sách mô tả loại cỏ.
var types: Array[Dictionary] = []

func _init() -> void:
	types.assign(DATA.TYPES)

## Số loại trong catalog.
func size() -> int:
	return types.size()

## Lấy mô tả loại theo chỉ số hợp lệ.
func source(index: int) -> Dictionary:
	assert(index >= 0 and index < size(), "Unknown grass source")
	return types[index]

## Biên khung cỏ trong tọa độ gốc, căn theo root_y của loại.
func local_bounds(index: int) -> Rect2:
	return Rect2(-8.0, -float(source(index).root_y), 16.0, 16.0)

## Vùng atlas của loại và frame hợp lệ.
func atlas_region(index: int, frame: int) -> Rect2i:
	assert(frame >= 0 and frame < FRAME_COUNT)
	return Rect2i(frame * FRAME_SIZE, index * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
