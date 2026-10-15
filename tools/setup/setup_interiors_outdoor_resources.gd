extends SceneTree

# godot --headless --path . --script res://tools/setup/setup_interiors_outdoor_resources.gd
const INTERIORS_ROOT := "res://world/buildings/art/Houses_Interiors"
const OUTDOOR_ROOT := "res://world/decorations/outdoor/art"
const OTHER_ROOT := OUTDOOR_ROOT + "/Outdoor_Decor_Animations/Other_Animations"
const BREAK_ROOT := OUTDOOR_ROOT + "/Outdoor_Decor_Animations/Break_Animations"
const TILESET_PATH := "res://world/buildings/tilesets/interiors/house_interiors_tiles.tres"
const FRAMES_ROOT := "res://world/decorations/outdoor/animations"
const TILE_SIZE := Vector2i(16, 16)
const DEFAULT_FPS := 8.0

# Thứ tự cố định là source_id. Thêm sheet mới ở cuối để giữ map đã vẽ.
const INTERIOR_SHEETS := [
	["Brick_Wall_Fillers.png", 32, 32],
	["Greenhouse_Interior_Tiles.png", 288, 160],
	["Interior_Walls.png", 224, 96],
	["Stone_Wall_Fillers.png", 32, 32],
	["Wood_Floor_Tiles.png", 128, 128],
	["Wood_Stairs.png", 64, 32],
	["Wood_Wall_Fillers.png", 64, 32],
]
# [thư mục, PNG, chiều rộng, chiều cao]. Chỉ các animation trong phạm vi yêu cầu.
const OUTDOOR_SHEETS := [
	[OUTDOOR_ROOT, "Big_Torch_Anim.png", 128, 48],
	[OTHER_ROOT, "Campfire_Anim.png", 128, 32],
	[OTHER_ROOT, "Fence_Big_Gate.png", 240, 64],
	[OTHER_ROOT, "Fence_Big_Gate_Vertical.png", 160, 80],
	[OTHER_ROOT, "Fireplace_Anim.png", 256, 96],
	[OTHER_ROOT, "Fountain_Anim.png", 256, 48],
	[OTHER_ROOT, "Torch_Anim.png", 128, 32],
	[OTHER_ROOT, "Torch_small_anim.png", 96, 16],
	[BREAK_ROOT, "Barrel_1_Anim.png", 240, 48],
	[BREAK_ROOT, "Crate_Anim.png", 288, 48],
	[BREAK_ROOT, "Sign_1_Anim.png", 240, 48],
	[BREAK_ROOT, "Sign_2_Anim.png", 240, 48],
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
	_generate_interiors()
	_generate_loop("campfire", OTHER_ROOT.path_join("Campfire_Anim.png"), Vector2i(16, 32), 8, "burn")
	_generate_loop("torch", OTHER_ROOT.path_join("Torch_Anim.png"), Vector2i(16, 32), 8, "burn")
	_generate_loop("small_torch", OTHER_ROOT.path_join("Torch_small_anim.png"), Vector2i(16, 16), 6, "burn")
	_generate_loop("big_torch", OUTDOOR_ROOT.path_join("Big_Torch_Anim.png"), Vector2i(16, 48), 8, "burn")
	for row in range(2):
		_generate_loop("fireplace_%02d" % (row + 1), OTHER_ROOT.path_join("Fireplace_Anim.png"), Vector2i(32, 48), 8, "burn", row)
	_generate_loop("fountain", OTHER_ROOT.path_join("Fountain_Anim.png"), Vector2i(32, 48), 8, "flow")
	# Hai hàng cổng ngang mở lên/mở xuống; cổng dọc chứa cả hai cánh trong một frame.
	for row in range(2):
		_generate_gate("horizontal_gate_%02d" % (row + 1), "Fence_Big_Gate.png", Vector2i(48, 32), row)
	_generate_gate("vertical_gate", "Fence_Big_Gate_Vertical.png", Vector2i(32, 80), 0)
	for config in [
		["barrel", "Barrel_1_Anim.png", 5],
		["crate", "Crate_Anim.png", 6],
		["sign_01", "Sign_1_Anim.png", 5],
		["sign_02", "Sign_2_Anim.png", 5],
	]:
		_generate_breakable(String(config[0]), String(config[1]), int(config[2]))
	print("Interiors + Outdoor: %d resource, %d tile, %d lỗi." % [_saved, _tile_count, _failed])
	quit(1 if _failed > 0 else 0)


func _load_sources() -> bool:
	var expected_files: Array[String] = []
	for config in INTERIOR_SHEETS:
		expected_files.append(String(config[0]))
	for file_name in DirAccess.get_files_at(INTERIORS_ROOT):
		if file_name.get_extension().to_lower() == "png" and not expected_files.has(file_name):
			_fail("Sheet nội thất chưa có mapping: " + file_name)
	for config in INTERIOR_SHEETS:
		_load_sheet(INTERIORS_ROOT.path_join(String(config[0])), Vector2i(config[1], config[2]))
	for config in OUTDOOR_SHEETS:
		_load_sheet(String(config[0]).path_join(String(config[1])), Vector2i(config[2], config[3]))
	return _failed == 0


func _load_sheet(path: String, expected_size: Vector2i) -> void:
	var texture := load(path) as Texture2D
	if texture == null or Vector2i(texture.get_size()) != expected_size:
		_fail("Texture thiếu hoặc kích thước đã thay đổi: " + path)
		return
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	if error != OK:
		_fail("Không đọc được PNG gốc: " + path)
		return
	_textures[path] = texture
	_images[path] = image


func _generate_interiors() -> void:
	var tileset := TileSet.new()
	tileset.resource_name = "house_interiors_tiles"
	tileset.tile_size = TILE_SIZE
	for source_id in range(INTERIOR_SHEETS.size()):
		var file_name := String(INTERIOR_SHEETS[source_id][0])
		var path := INTERIORS_ROOT.path_join(file_name)
		var image: Image = _images[path]
		var source := TileSetAtlasSource.new()
		source.resource_name = file_name.get_basename().to_snake_case()
		source.texture = _textures[path]
		source.texture_region_size = TILE_SIZE
		source.use_texture_padding = true
		for row in range(image.get_height() / TILE_SIZE.y):
			for column in range(image.get_width() / TILE_SIZE.x):
				var coords := Vector2i(column, row)
				if image.get_region(Rect2i(coords * TILE_SIZE, TILE_SIZE)).is_invisible():
					continue
				source.create_tile(coords)
				_tile_count += 1
		tileset.add_source(source, source_id)
	_save(tileset, TILESET_PATH)


func _generate_loop(variant: String, path: String, cell: Vector2i, count: int, animation: String, row: int = 0) -> void:
	var frames := _new_frames(variant)
	_add_animation(frames, animation, path, _strip_regions(cell, count, row), true)
	_save(frames, FRAMES_ROOT.path_join(variant + "_frames.tres"))


func _generate_gate(variant: String, file_name: String, cell: Vector2i, row: int) -> void:
	var frames := _new_frames(variant)
	var path := OTHER_ROOT.path_join(file_name)
	var regions := _strip_regions(cell, 5, row)
	_add_animation(frames, "closed", path, [regions.front()], true)
	_add_animation(frames, "opened", path, [regions.back()], true)
	_add_animation(frames, "open", path, regions, false)
	var reversed := regions.duplicate()
	reversed.reverse()
	_add_animation(frames, "close", path, reversed, false)
	_save(frames, FRAMES_ROOT.path_join(variant + "_frames.tres"))


func _generate_breakable(variant: String, file_name: String, count: int) -> void:
	var frames := _new_frames(variant)
	var path := BREAK_ROOT.path_join(file_name)
	# Giữ đủ canvas 48x48 để mảnh vỡ không bị cắt hoặc nhảy vị trí.
	var regions := _strip_regions(Vector2i(48, 48), count)
	_add_animation(frames, "idle", path, [regions.front()], true)
	_add_animation(frames, "break", path, regions, false)
	_add_animation(frames, "broken", path, [regions.back()], true)
	_save(frames, FRAMES_ROOT.path_join(variant + "_frames.tres"))


func _strip_regions(cell: Vector2i, count: int, row: int = 0) -> Array[Rect2i]:
	var regions: Array[Rect2i] = []
	for column in range(count):
		regions.append(Rect2i(Vector2i(column * cell.x, row * cell.y), cell))
	return regions


func _new_frames(variant: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.resource_name = variant
	frames.remove_animation(&"default")
	return frames


func _add_animation(frames: SpriteFrames, animation_name: String, path: String, regions: Array, loop: bool) -> void:
	var texture: Texture2D = _textures[path]
	var image: Image = _images[path]
	var name := StringName(animation_name)
	frames.add_animation(name)
	frames.set_animation_speed(name, DEFAULT_FPS)
	frames.set_animation_loop(name, loop)
	for region in regions:
		if not Rect2i(Vector2i.ZERO, image.get_size()).encloses(region) or image.get_region(region).is_invisible():
			_fail("Vùng animation trống hoặc vượt sheet: %s/%s" % [path, animation_name])
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
		error = ResourceSaver.save(resource, path)
	if error != OK:
		_fail("Không lưu được %s: lỗi %d" % [path, error])
		return
	_saved += 1
	print("Đã lưu: ", path)


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
