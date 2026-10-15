extends SceneTree

# godot --headless --path . --script res://tools/setup/setup_house_decor_tiles_v2.gd
const SOURCE_ROOT := "res://world/decorations/house/art"
const MATRIX_PATH := "res://tools/setup/data/house_decor_selection_matrix_v2.json"
const OUTPUT_PATH := "res://world/decorations/house/tilesets/house_decor_tiles.tres"
const PREVIEW_TEMPLATE := "res://tools/setup/data/house_decor_tiles_v2_preview.template.html"
const PREVIEW_PATH := "res://docs/house_decor_tiles_v2_preview.html"
const CELL_SIZE := Vector2i(16, 16)

# Giữ source ID của từng PNG; không tự sắp lại theo DirAccess.
const SOURCE_FILES := [
	"Bathroom_Furniture.png", "Beds.png", "BookShelves.png", "Carpets.png",
	"Chairs.png", "Clocks.png", "Doors.png", "Fireplaces.png", "Furnaces.png",
	"Furniture_Other.png", "House_Plants.png", "Indoor_Decor.png", "Kitchen.png",
	"Kitchen_Furniture.png", "Placeable_Decoration.png", "Planters.png",
	"Standing_Lamps.png", "Tables.png", "windows.png",
]
const ANIMATION_FILES := [
	"Anvil_Anim.png", "Chest_Anim.png", "Chimney_smoke_Anim.png", "Furnace_Anim.png",
	"Golden_Chest_Anim.png", "Golden_Jeweled_Chest_Anim.png", "Metal_Chest_Anim.png",
]

var _images: Dictionary = {}
var _textures: Dictionary = {}
var _failed := 0
var _selection_count := 0
var _multi_cell_count := 0


func _initialize() -> void:
	var json := JSON.new()
	var error := json.parse(FileAccess.get_file_as_string(MATRIX_PATH))
	if error != OK or not json.data is Dictionary:
		_fail("Không đọc được ma trận: %s (dòng %d)." % [json.get_error_message(), json.get_error_line()])
		quit(1)
		return
	var manifest: Dictionary = json.data
	if not _preflight(manifest):
		quit(1)
		return
	# Chỉ tạo atlas sau khi kiểm tra xong toàn bộ ma trận của mọi PNG.
	var tileset := _build_tileset(manifest)
	error = DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	if error == OK:
		error = ResourceSaver.save(tileset, OUTPUT_PATH)
	if error != OK:
		_fail("Không lưu được TileSet: lỗi %d." % error)
	else:
		_write_preview(manifest)
		print("House Decor v2: %d selection (%d nhiều ô), %d source, %d lỗi. %s" % [_selection_count, _multi_cell_count, SOURCE_FILES.size(), _failed, OUTPUT_PATH])
	quit(1 if _failed > 0 else 0)


func _preflight(manifest: Dictionary) -> bool:
	if manifest.get("schema_version") != 1 or manifest.get("coordinate_unit") != "atlas_cell" or manifest.get("output") != OUTPUT_PATH:
		_fail("Schema, đơn vị tọa độ hoặc đường dẫn output không đúng.")
		return false
	if not _integer_array(manifest.get("tile_size_px"), 2) or Vector2i(manifest["tile_size_px"][0], manifest["tile_size_px"][1]) != CELL_SIZE:
		_fail("Ma trận phải dùng ô 16 x 16.")
		return false
	if not manifest.get("sources") is Array or manifest["sources"].size() != SOURCE_FILES.size():
		_fail("Ma trận phải có đủ %d source." % SOURCE_FILES.size())
		return false
	if not FileAccess.file_exists(PREVIEW_TEMPLATE):
		_fail("Thiếu template xem trước: " + PREVIEW_TEMPLATE)
	for file_name in DirAccess.get_files_at(SOURCE_ROOT):
		if file_name.get_extension().to_lower() == "png" and not SOURCE_FILES.has(file_name) and not ANIMATION_FILES.has(file_name):
			_fail("PNG mới cần xác định vùng chọn trước: " + file_name)
	for source_id in range(SOURCE_FILES.size()):
		var config: Variant = manifest["sources"][source_id]
		if not config is Dictionary or config.get("source_id") != source_id or config.get("file") != SOURCE_FILES[source_id]:
			_fail("Tên file/source ID không đúng ở vị trí %d." % source_id)
			continue
		_validate_source(config)
	return _failed == 0


func _validate_source(config: Dictionary) -> void:
	var file_name := String(config["file"])
	var path := SOURCE_ROOT.path_join(file_name)
	if not _integer_array(config.get("size_px"), 2) or not config.get("groups") is Array or config["groups"].is_empty():
		_fail("Kích thước/nhóm vùng chọn không hợp lệ: " + file_name)
		return
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != config.get("sha256"):
		_fail("PNG thiếu hoặc đã đổi; cần kiểm tra lại ma trận: " + file_name)
		return
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	if error != OK or image.get_size() != Vector2i(config["size_px"][0], config["size_px"][1]):
		_fail("PNG không đúng kích thước ma trận: " + file_name)
		return
	var grid := image.get_size() / CELL_SIZE
	if grid * CELL_SIZE != image.get_size():
		_fail("Kích thước PNG không chia hết cho ô 16 x 16: " + file_name)
		return
	var coverage: Dictionary = {}
	var names: Dictionary = {}
	for group in config["groups"]:
		if not group is Dictionary or not group.get("name") is String or String(group["name"]).is_empty() or not group.get("rects") is Array or group["rects"].is_empty():
			_fail("Nhóm vùng chọn không hợp lệ: " + file_name)
			continue
		var group_name := String(group["name"])
		if names.has(group_name):
			_fail("Nhóm vùng chọn bị trùng: %s/%s" % [file_name, group_name])
		names[group_name] = true
		for value in group["rects"]:
			if not _integer_array(value, 4):
				_fail("Vùng chọn phải là [x, y, width, height] nguyên: " + file_name)
				continue
			var region := Rect2i(Vector2i(value[0], value[1]), Vector2i(value[2], value[3]))
			if region.size.x <= 0 or region.size.y <= 0 or not Rect2i(Vector2i.ZERO, grid).encloses(region):
				_fail("Vùng chọn vượt sheet hoặc rỗng: %s %s" % [file_name, value])
				continue
			if image.get_region(Rect2i(region.position * CELL_SIZE, region.size * CELL_SIZE)).is_invisible():
				_fail("Vùng chọn không có hình: %s %s" % [file_name, value])
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					var cell := Vector2i(x, y)
					if coverage.has(cell):
						_fail("Vùng chọn chồng lấn: %s tại %s" % [file_name, cell])
					coverage[cell] = true
	for y in range(grid.y):
		for x in range(grid.x):
			var cell := Vector2i(x, y)
			if not coverage.has(cell) and not image.get_region(Rect2i(cell * CELL_SIZE, CELL_SIZE)).is_invisible():
				_fail("Ma trận bỏ sót phần hình: %s tại %s" % [file_name, cell])
	var texture := load(path) as Texture2D
	if texture == null or Vector2i(texture.get_size()) != image.get_size():
		_fail("Không nạp được texture: " + file_name)
		return
	_images[file_name] = image
	_textures[file_name] = texture


func _integer_array(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for component in value:
		if typeof(component) != TYPE_INT and typeof(component) != TYPE_FLOAT:
			return false
		if float(component) != floor(float(component)):
			return false
	return true


func _build_tileset(manifest: Dictionary) -> TileSet:
	var tileset := TileSet.new()
	tileset.resource_name = "house_decor_tiles"
	tileset.tile_size = CELL_SIZE
	tileset.set_meta("selection_matrix", MATRIX_PATH)
	for config in manifest["sources"]:
		var file_name := String(config["file"])
		var source := TileSetAtlasSource.new()
		source.resource_name = file_name.get_basename().to_snake_case()
		source.texture = _textures[file_name]
		source.texture_region_size = CELL_SIZE
		source.use_texture_padding = true
		for group in config["groups"]:
			for value in group["rects"]:
				var coords := Vector2i(value[0], value[1])
				var size := Vector2i(value[2], value[3])
				# Một tile Godot chứa toàn bộ vùng atlas, ví dụ cửa size (1, 2).
				source.create_tile(coords, size)
				_selection_count += 1
				if size.x * size.y > 1:
					_multi_cell_count += 1
		tileset.add_source(source, int(config["source_id"]))
	return tileset


func _write_preview(manifest: Dictionary) -> void:
	var images: Dictionary = {}
	for file_name in SOURCE_FILES:
		var bytes := FileAccess.get_file_as_bytes(SOURCE_ROOT.path_join(file_name))
		images[file_name] = "data:image/png;base64," + Marshalls.raw_to_base64(bytes)
	var html := FileAccess.get_file_as_string(PREVIEW_TEMPLATE)
	html = html.replace("__MATRIX_JSON__", JSON.stringify(manifest)).replace("__IMAGES_JSON__", JSON.stringify(images))
	var error := DirAccess.make_dir_recursive_absolute(PREVIEW_PATH.get_base_dir())
	if error != OK:
		_fail("Không tạo được thư mục preview: lỗi %d." % error)
		return
	var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Không ghi được trang xem trước ma trận.")
		return
	file.store_string(html)
	print("Preview: ", PREVIEW_PATH)


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
