@tool
extends EditorScript

# Đường dẫn file .tres đích
const TILESET_PATH = "res://world/decorations/outdoor/tilesets/my_decor_rock_tileset.tres"

# Thư mục cha chứa tất cả các thư mục decor con (hoa, gỗ, đá...)
const ROOT_DIR = "res://world/decorations/outdoor/art/Outdoor_Decor_Animations/Rock_Animations/"

const TILE_SIZE = Vector2i(16, 16)
const FRAME_COUNT = 8
const FPS = 8.0

func _run() -> void:
	var tileset: TileSet = load(TILESET_PATH)
	if not tileset: 
		printerr("Không thể tải TileSet tại: ", TILESET_PATH)
		return
	
	var processed_count = _scan_and_setup(ROOT_DIR, tileset)
	
	var err = ResourceSaver.save(tileset, TILESET_PATH)
	if err == OK:
		print("Đã tự động nạp và tạo animation 8 frames thành công cho %d file decor!" % processed_count)
	else:
		printerr("Lỗi khi lưu TileSet: ", err)

# Hàm đệ quy duyệt qua thư mục và toàn bộ thư mục con
func _scan_and_setup(current_dir_path: String, tileset: TileSet) -> int:
	var dir = DirAccess.open(current_dir_path)
	if not dir:
		printerr("Không thể mở folder: ", current_dir_path)
		return 0
	
	var count = 0
	dir.list_dir_begin()
	var item_name = dir.get_next()
	
	while item_name != "":
		# Bỏ qua thư mục điều hướng hệ thống
		if item_name == "." or item_name == "..":
			item_name = dir.get_next()
			continue
			
		var full_path = current_dir_path.path_join(item_name)
		
		if dir.current_is_dir():
			# Nếu là thư mục con, đệ quy tiếp vào bên trong
			count += _scan_and_setup(full_path, tileset)
		elif item_name.ends_with(".png") or item_name.ends_with(".webp"):
			var tex: Texture2D = load(full_path)
			if tex:
				_setup_atlas_source(tileset, tex)
				count += 1
		
		item_name = dir.get_next()
	
	return count

func _setup_atlas_source(tileset: TileSet, tex: Texture2D) -> void:
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
		
	var base_tile = Vector2i(0, 0)
	
	if not source.has_tile(base_tile):
		source.create_tile(base_tile)
	
	source.set_tile_animation_columns(base_tile, FRAME_COUNT)
	source.set_tile_animation_frames_count(base_tile, FRAME_COUNT)
	source.set_tile_animation_speed(base_tile, FPS)
