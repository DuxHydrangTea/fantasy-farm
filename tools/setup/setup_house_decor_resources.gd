extends SceneTree

# godot --headless --path . --script res://tools/setup/setup_house_decor_resources.gd
const SOURCE_ROOT := "res://world/decorations/house/art"
const TILESET_PATH := "res://world/decorations/house/tilesets/house_decor_tiles.tres"
const FRAMES_ROOT := "res://world/decorations/house/animations"
const TILE_SIZE := Vector2i(16, 16)
const DEFAULT_FPS := 8.0

# Thứ tự cố định là source_id trong TileSet. Thêm sheet mới ở cuối danh sách.
# [PNG, chiều rộng, chiều cao].
const STATIC_SHEETS := [
	["Bathroom_Furniture.png", 128, 432],
	["Beds.png", 112, 192],
	["BookShelves.png", 192, 112],
	["Carpets.png", 224, 640],
	["Chairs.png", 224, 448],
	["Clocks.png", 96, 32],
	["Doors.png", 176, 384],
	["Fireplaces.png", 96, 48],
	["Furnaces.png", 32, 32],
	["Furniture_Other.png", 192, 352],
	["House_Plants.png", 208, 640],
	["Indoor_Decor.png", 96, 256],
	["Kitchen.png", 1040, 384],
	["Kitchen_Furniture.png", 112, 96],
	["Placeable_Decoration.png", 144, 176],
	["Planters.png", 160, 96],
	["Standing_Lamps.png", 160, 288],
	["Tables.png", 336, 896],
	["windows.png", 80, 128],
]
const ANIMATED_SHEETS := [
	["Anvil_Anim.png", 128, 16],
	["Chest_Anim.png", 96, 16],
	["Chimney_smoke_Anim.png", 160, 32],
	["Furnace_Anim.png", 80, 32],
	["Golden_Chest_Anim.png", 96, 16],
	["Golden_Jeweled_Chest_Anim.png", 96, 80],
	["Metal_Chest_Anim.png", 96, 16],
]

var _textures: Dictionary = {}
var _images: Dictionary = {}
var _failed := 0
var _saved := 0
var _tile_count := 0


func _initialize() -> void:
	if not _load_sources():
		quit(1)
		return
	_generate_tileset()
	for chest in [
		["Chest_Anim.png", "chest"],
		["Golden_Chest_Anim.png", "golden_chest"],
		["Metal_Chest_Anim.png", "metal_chest"],
	]:
		_generate_chest(String(chest[0]), String(chest[1]), 0)
	for row in range(5):
		_generate_chest("Golden_Jeweled_Chest_Anim.png", "golden_jeweled_chest_%02d" % (row + 1), row)
	_generate_furnace()
	_generate_anvil()
	_generate_smoke()
	print("House Decor: %d resource, %d tile, %d lỗi." % [_saved, _tile_count, _failed])
	quit(1 if _failed > 0 else 0)


func _load_sources() -> bool:
	var configs: Array = STATIC_SHEETS + ANIMATED_SHEETS
	var expected_files: Array[String] = []
	for config in configs:
		expected_files.append(String(config[0]))
	for file_name in DirAccess.get_files_at(SOURCE_ROOT):
		if file_name.get_extension().to_lower() == "png" and not expected_files.has(file_name):
			_fail("Sheet chưa có mapping: " + file_name)
	if _failed > 0:
		return false
	for config in configs:
		var name := String(config[0])
		var path := SOURCE_ROOT.path_join(name)
		var texture := load(path) as Texture2D
		if texture == null or Vector2i(texture.get_size()) != Vector2i(config[1], config[2]):
			_fail("Texture thiếu hoặc kích thước đã thay đổi: " + path)
			return false
		var image := Image.new()
		var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
		if error != OK:
			_fail("Không đọc được PNG gốc: " + path)
			return false
		_textures[name] = texture
		_images[name] = image
	return true


func _generate_tileset() -> void:
	# Dùng generator theo ma trận đã duyệt cho cùng đường dẫn resource chính.
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/setup/setup_house_decor_tiles_v2.gd",
	]), output, true)
	if exit_code != 0:
		_fail("Không tạo được TileSet theo ma trận: " + str(output))
		return
	var tileset := load(TILESET_PATH) as TileSet
	if tileset == null:
		_fail("Không nạp được TileSet: " + TILESET_PATH)
		return
	for index in range(tileset.get_source_count()):
		var source := tileset.get_source(tileset.get_source_id(index)) as TileSetAtlasSource
		_tile_count += source.get_tiles_count()
	_saved += 1


func _generate_chest(file_name: String, variant: String, row: int) -> void:
	var frames := _new_frames(variant)
	var closed_region := Rect2i(0, row * 16, 16, 16)
	var opened_region := Rect2i(80, row * 16, 16, 16)
	_add_animation(frames, "closed", file_name, [closed_region], true)
	_add_animation(frames, "opened", file_name, [opened_region], true)
	var open_regions: Array[Rect2i] = []
	for column in range(6):
		open_regions.append(Rect2i(column * 16, row * 16, 16, 16))
	_add_animation(frames, "open", file_name, open_regions, false)
	var close_regions := open_regions.duplicate()
	close_regions.reverse()
	_add_animation(frames, "close", file_name, close_regions, false)
	_save(frames, FRAMES_ROOT.path_join(variant + "_frames.tres"))


func _generate_furnace() -> void:
	var frames := _new_frames("furnace")
	# Furnaces.png: hình lò tắt bên trái, lò cháy bên phải.
	_add_animation(frames, "off", "Furnaces.png", [Rect2i(0, 0, 16, 32)], true)
	_add_animation(frames, "burn", "Furnace_Anim.png", _strip_regions(Vector2i(16, 32), 5), true)
	_save(frames, FRAMES_ROOT.path_join("furnace_frames.tres"))


func _generate_anvil() -> void:
	var frames := _new_frames("anvil")
	_add_animation(frames, "idle", "Anvil_Anim.png", [Rect2i(0, 0, 16, 16)], true)
	# Chuỗi thay đổi ánh sáng trên bề mặt đe, không có động tác búa.
	_add_animation(frames, "shine", "Anvil_Anim.png", _strip_regions(Vector2i(16, 16), 8), true)
	_save(frames, FRAMES_ROOT.path_join("anvil_frames.tres"))


func _generate_smoke() -> void:
	var frames := _new_frames("chimney_smoke")
	# Mỗi cụm khói chiếm 32x32, không cắt thành ô 16x16.
	_add_animation(frames, "smoke", "Chimney_smoke_Anim.png", _strip_regions(Vector2i(32, 32), 5), true)
	_save(frames, FRAMES_ROOT.path_join("chimney_smoke_frames.tres"))


func _strip_regions(cell: Vector2i, count: int) -> Array[Rect2i]:
	var regions: Array[Rect2i] = []
	for column in range(count):
		regions.append(Rect2i(Vector2i(column * cell.x, 0), cell))
	return regions


func _new_frames(variant: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.resource_name = variant
	frames.remove_animation(&"default")
	return frames


func _add_animation(frames: SpriteFrames, animation_name: String, file_name: String, regions: Array, loop: bool) -> void:
	var texture: Texture2D = _textures[file_name]
	var image: Image = _images[file_name]
	var name := StringName(animation_name)
	frames.add_animation(name)
	frames.set_animation_speed(name, DEFAULT_FPS)
	frames.set_animation_loop(name, loop)
	for region in regions:
		if not Rect2i(Vector2i.ZERO, image.get_size()).encloses(region) or image.get_region(region).is_invisible():
			_fail("Vùng animation trống hoặc vượt sheet: %s/%s" % [file_name, animation_name])
			return
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(region)
		atlas.filter_clip = true
		frames.add_frame(name, atlas)


func _save(resource: Resource, path: String) -> void:
	if _failed > 0:
		return
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error == OK:
		# PNG giữ làm external resource; các atlas là subresource.
		error = ResourceSaver.save(resource, path)
	if error != OK:
		_fail("Không lưu được %s: lỗi %d" % [path, error])
		return
	_saved += 1
	print("Đã lưu: ", path)


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
