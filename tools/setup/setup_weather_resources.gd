extends SceneTree

# godot --headless --path . --script res://tools/setup/setup_weather_resources.gd
const SOURCE_ROOT := "res://features/weather/art"
const TEXTURES_ROOT := "res://features/weather/textures"
const FRAMES_ROOT := "res://features/weather/animations"
const SHEETS := [
	["Clouds.png", 128, 128],
	["Rain_Drop.png", 16, 16],
	["Rain_Drop_Impact.png", 112, 16],
	["Wind_Anim.png", 224, 16],
]
# Bốn bóng mây riêng, đọc trái sang phải rồi trên xuống; giữ canvas 64x64.
const CLOUD_REGIONS := [
	Rect2i(0, 0, 64, 64), Rect2i(64, 0, 64, 64),
	Rect2i(0, 64, 64, 64), Rect2i(64, 64, 64, 64),
]

var _textures: Dictionary = {}
var _failed := 0
var _saved := 0


func _initialize() -> void:
	if not _load_sources():
		quit(1)
		return
	for index in range(CLOUD_REGIONS.size()):
		var name := "cloud_%02d" % (index + 1)
		var atlas := _atlas("Clouds.png", CLOUD_REGIONS[index])
		atlas.resource_name = name
		_save(atlas, TEXTURES_ROOT.path_join("clouds/" + name + ".tres"))
	var drop := _atlas("Rain_Drop.png", Rect2i(0, 0, 16, 16))
	drop.resource_name = "rain_drop"
	_save(drop, TEXTURES_ROOT.path_join("rain_drop.tres"))
	_generate_frames("rain_drop_impact", "Rain_Drop_Impact.png", "impact", 7, 12.0)
	_generate_frames("wind", "Wind_Anim.png", "gust", 14, 12.0)
	print("Weather: %d resource, %d lỗi." % [_saved, _failed])
	quit(1 if _failed > 0 else 0)


func _load_sources() -> bool:
	var expected_files: Array[String] = []
	for config in SHEETS:
		expected_files.append(String(config[0]))
	for file_name in DirAccess.get_files_at(SOURCE_ROOT):
		if file_name.get_extension().to_lower() == "png" and not expected_files.has(file_name):
			_fail("Sheet mới cần mapping: " + file_name)
	for config in SHEETS:
		var file_name := String(config[0])
		var path := SOURCE_ROOT.path_join(file_name)
		var texture := load(path) as Texture2D
		if texture == null or Vector2i(texture.get_size()) != Vector2i(config[1], config[2]):
			_fail("Texture thiếu hoặc kích thước đã thay đổi: " + path)
			continue
		var image := Image.new()
		if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
			_fail("Không đọc được PNG: " + path)
			continue
		var regions: Array = CLOUD_REGIONS if file_name == "Clouds.png" else []
		if file_name != "Clouds.png":
			for column in range(image.get_width() / 16):
				regions.append(Rect2i(column * 16, 0, 16, 16))
		for region in regions:
			if not Rect2i(Vector2i.ZERO, image.get_size()).encloses(region) or image.get_region(region).is_invisible():
				_fail("Vùng chọn trống hoặc vượt sheet: %s %s" % [file_name, region])
		_textures[file_name] = texture
	return _failed == 0


func _atlas(file_name: String, region: Rect2i) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _textures[file_name]
	atlas.region = Rect2(region)
	atlas.filter_clip = true
	return atlas


func _generate_frames(variant: String, file_name: String, animation: String, count: int, fps: float) -> void:
	var frames := SpriteFrames.new()
	frames.resource_name = variant
	frames.remove_animation(&"default")
	frames.add_animation(animation)
	frames.set_animation_speed(animation, fps)
	frames.set_animation_loop(animation, false)
	for column in range(count):
		frames.add_frame(animation, _atlas(file_name, Rect2i(column * 16, 0, 16, 16)))
	_save(frames, FRAMES_ROOT.path_join(variant + "_frames.tres"))


func _save(resource: Resource, path: String) -> void:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error == OK:
		error = ResourceSaver.save(resource, path)
	if error != OK:
		_fail("Không lưu được %s: lỗi %d." % [path, error])
		return
	_saved += 1
	print("Đã lưu: ", path)


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
