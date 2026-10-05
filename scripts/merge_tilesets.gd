@tool
extends EditorScript

# 1. Đường dẫn file .tres tổng hợp bạn muốn tạo ra
const TARGET_TILESET_PATH = "res://tilesets/all_decor_tileset.tres"

# 2. Thư mục chứa các file .tres lẻ hiện tại (đổi theo folder thực tế của bạn)
const SOURCE_DIR = "res://tilesets/"

# 3. Kích thước chuẩn của tile (ví dụ 16x16)
const TILE_SIZE = Vector2i(16, 16)

func _run() -> void:
	# Tạo hoặc nạp TileSet đích
	var target_tileset: TileSet
	if FileAccess.file_exists(TARGET_TILESET_PATH):
		target_tileset = load(TARGET_TILESET_PATH)
	else:
		target_tileset = TileSet.new()
		target_tileset.tile_size = TILE_SIZE

	var dir = DirAccess.open(SOURCE_DIR)
	if not dir:
		printerr("Không thể mở thư mục: ", SOURCE_DIR)
		return

	var merged_sources_count = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		# Chỉ lấy file .tres, bỏ qua file target để tránh đệ quy lặp lại chính nó
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path = SOURCE_DIR.path_join(file_name)
			
			if full_path != TARGET_TILESET_PATH:
				var res = load(full_path)
				
				# Chỉ xử lý nếu file .tres đó đúng là kiểu TileSet
				if res is TileSet:
					print("Đang gộp từ: ", file_name)
					merged_sources_count += _merge_sources_from_tileset(res, target_tileset)
		
		file_name = dir.get_next()

	# Lưu lại file .tres tổng
	var err = ResourceSaver.save(target_tileset, TARGET_TILESET_PATH)
	if err == OK:
		print("--- THÀNH CÔNG: Đã gộp tổng cộng %d nguồn atlas vào %s! ---" % [merged_sources_count, TARGET_TILESET_PATH])
	else:
		printerr("Lỗi khi lưu TileSet đích: ", err)

# Hàm sao chép tất cả các atlas source từ TileSet nguồn sang TileSet đích
func _merge_sources_from_tileset(source_ts: TileSet, target_ts: TileSet) -> int:
	var added = 0
	for i in range(source_ts.get_source_count()):
		var source_id = source_ts.get_source_id(i)
		var source = source_ts.get_source(source_id)

		if source is TileSetAtlasSource:
			# Kiểm tra xem texture này đã có trong target_ts chưa (tránh trùng lặp)
			var already_exists = false
			for j in range(target_ts.get_source_count()):
				var t_id = target_ts.get_source_id(j)
				var t_source = target_ts.get_source(t_id)
				if t_source is TileSetAtlasSource and t_source.texture == source.texture:
					already_exists = true
					break

			if not already_exists:
				# Nhân bản (duplicate) source để giữ nguyên toàn bộ config animation, speed, collision
				var new_source = source.duplicate(true)
				target_ts.add_source(new_source)
				added += 1

	return added
