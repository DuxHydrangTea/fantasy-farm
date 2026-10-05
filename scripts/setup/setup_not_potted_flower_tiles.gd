@tool
extends EditorScript

# 1. Đường dẫn file .tres đích
const TILESET_PATH = "res://tilesets/my_decor_not_potted_flower_tileset.tres"

# 2. Folder chứa các file sheet hoa/decor (hỗ trợ cả các subfolder bên trong)
const SHEETS_DIR = "res://assets/Outdoor decoration/Outdoor_Decor_Animations/Flower_Animations/Not_Potted/"

# 3. Kích thước 1 ô tile và số frame mỗi hàng
const TILE_SIZE = Vector2i(16, 16)
const FRAME_COLUMNS = 6   # 6 cột tương ứng 6 frames animation
const FPS = 8.0

func _run() -> void:
	var tileset: TileSet = load(TILESET_PATH)
	if not tileset:
		printerr("Không thể tải TileSet tại: ", TILESET_PATH)
		return

	var processed_files = _scan_and_setup_sheets(SHEETS_DIR, tileset)

	var err = ResourceSaver.save(tileset, TILESET_PATH)
	if err == OK:
		print("--- HOÀN THÀNH: Đã xử lý %d file spritesheet vào TileSet! ---" % processed_files)
	else:
		printerr("Lỗi khi lưu TileSet: ", err)

# Đệ quy quét qua folder và các folder con
func _scan_and_setup_sheets(current_dir_path: String, tileset: TileSet) -> int:
	var dir = DirAccess.open(current_dir_path)
	if not dir:
		printerr("Không thể mở folder: ", current_dir_path)
		return 0

	var count = 0
	dir.list_dir_begin()
	var item_name = dir.get_next()

	while item_name != "":
		if item_name == "." or item_name == "..":
			item_name = dir.get_next()
			continue

		var full_path = current_dir_path.path_join(item_name)

		if dir.current_is_dir():
			# Đi sâu vào folder con nếu có
			count += _scan_and_setup_sheets(full_path, tileset)
		elif item_name.ends_with(".png") or item_name.ends_with(".webp"):
			var tex: Texture2D = load(full_path)
			if tex:
				_setup_multi_row_sheet(tileset, tex)
				count += 1

		item_name = dir.get_next()

	return count

func _setup_multi_row_sheet(tileset: TileSet, tex: Texture2D) -> void:
	# 1. Tìm hoặc tạo mới TileSetAtlasSource cho texture này
	var source: TileSetAtlasSource = null
	for i in range(tileset.get_source_count()):
		var s_id = tileset.get_source_id(i)
		var s = tileset.get_source(s_id)
		if s is TileSetAtlasSource and s.texture == tex:
			source = s
			break

	if not source:
		source = TileSetAtlasSource.new()
		source.texture = tex
		source.texture_region_size = TILE_SIZE
		tileset.add_source(source)

	# 2. Tự động tính số hàng dựa trên chiều cao thực tế của ảnh
	var tex_height = tex.get_height()
	var rows = tex_height / TILE_SIZE.y

	# 3. Duyệt qua từng hàng và gán animation 6 frames
	for row in range(rows):
		var base_tile = Vector2i(0, row)

		# Tạo tile gốc tại cột đầu tiên của hàng
		if not source.has_tile(base_tile):
			source.create_tile(base_tile)

		# Thiết lập chuỗi 6 frames ngang
		source.set_tile_animation_columns(base_tile, FRAME_COLUMNS)
		source.set_tile_animation_frames_count(base_tile, FRAME_COLUMNS)
		source.set_tile_animation_speed(base_tile, FPS)
