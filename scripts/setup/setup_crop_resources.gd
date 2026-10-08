extends SceneTree

# Chạy: godot --headless --path . --script res://scripts/setup/setup_crop_resources.gd
const SOURCE_ROOT := "res://assets/Crops"
const OUTPUT_ROOT := "res://crops"
const NAME_CATALOG := "res://scripts/setup/data/object_scene_names.json"
const SOURCE_SIZES := {
	"Crops.png": Vector2i(112, 704),
	"Crops_2.png": Vector2i(112, 256),
	"Fruit_Tree_Stages.png": Vector2i(96, 64),
	"Apple_Tree.png": Vector2i(32, 64),
	"Pear_Tree.png": Vector2i(32, 64),
	"Peach_Tree.png": Vector2i(32, 64),
	"Cherry_Tree.png": Vector2i(32, 64),
	"Fruit_Trees_Fruit_Objects.png": Vector2i(80, 16),
	"Grapes_Bower.png": Vector2i(288, 160),
	"Berries.png": Vector2i(64, 64),
}
# Thứ tự icon quả trong Fruit_Trees_Fruit_Objects.png, từ trái sang phải.
const FRUIT_NAMES := ["grapes", "apple", "pear", "peach", "cherry"]

var _textures: Dictionary = {}
var _crop_names: Array[String] = []
var _entries: Array[Dictionary] = []
var _saved := 0
var _failed := 0


func _initialize() -> void:
	if not _load_crop_names():
		quit(1)
		return
	if not _load_sources():
		quit(1)
		return
	_build_entries()
	# Xác minh mọi vùng trước khi ghi các resource.
	for entry in _entries:
		var texture: Texture2D = _textures[entry["source"]]
		var region: Rect2i = entry["region"]
		if not Rect2i(Vector2i.ZERO, Vector2i(texture.get_size())).encloses(region):
			_fail("Vùng cắt vượt PNG: " + String(entry["path"]))
		elif texture.get_image().get_region(region).is_invisible():
			_fail("Vùng cắt trống: " + String(entry["path"]))
	if _failed == 0:
		for entry in _entries:
			_save_texture(entry)
	print("Crop AtlasTexture: %d đã lưu, %d lỗi. Output: %s" % [_saved, _failed, OUTPUT_ROOT])
	quit(1 if _failed > 0 else 0)


func _load_crop_names() -> bool:
	var catalog := JSON.new()
	if catalog.parse(FileAccess.get_file_as_string(NAME_CATALOG)) != OK or not catalog.data is Dictionary:
		_fail("Không đọc được danh mục tên cây: " + NAME_CATALOG)
		return false
	var names: Dictionary = catalog.data.get("crops", {})
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*$")
	for row in range(22):
		var source_name := "crop_%02d" % (row + 1)
		var crop_name := String(names.get(source_name, ""))
		if pattern.search(crop_name) == null or _crop_names.has(crop_name):
			_fail("Tên cây thiếu, không hợp lệ hoặc trùng: " + source_name)
			return false
		_crop_names.append(crop_name)
	return true


func _load_sources() -> bool:
	for file_name in SOURCE_SIZES:
		var texture := load(SOURCE_ROOT.path_join(file_name)) as Texture2D
		if texture == null or Vector2i(texture.get_size()) != SOURCE_SIZES[file_name]:
			_fail("Không load được hoặc kích thước sheet thay đổi: " + String(file_name))
			return false
		_textures[file_name] = texture
	# So sánh PNG gốc, tránh RGB ở pixel trong suốt bị importer fix_alpha_border thay đổi.
	var main_image := Image.new()
	var duplicate_image := Image.new()
	var main_error := main_image.load_png_from_buffer(
		FileAccess.get_file_as_bytes(SOURCE_ROOT.path_join("Crops.png"))
	)
	var duplicate_error := duplicate_image.load_png_from_buffer(
		FileAccess.get_file_as_bytes(SOURCE_ROOT.path_join("Crops_2.png"))
	)
	if main_error != OK or duplicate_error != OK:
		_fail("Không đọc được PNG gốc để kiểm tra sheet trùng.")
		return false
	main_image.convert(Image.FORMAT_RGBA8)
	duplicate_image.convert(Image.FORMAT_RGBA8)
	var last_rows := main_image.get_region(Rect2i(0, 448, 112, 256))
	if last_rows.get_data() != duplicate_image.get_data():
		_fail("Crops_2.png không còn trùng 8 hàng cuối Crops.png; cần cập nhật mapping.")
		return false
	return true


func _build_entries() -> void:
	# Mỗi hàng: biển, hạt giống, 4 giai đoạn cây, hình thu hoạch.
	# Stage giữ cả ô 16x32; biển/hạt/thu hoạch lấy ô 16x16 phía dưới.
	for row in range(22):
		var folder := "field/" + _crop_names[row]
		_add("Crops.png", Rect2i(0, row * 32 + 16, 16, 16), folder + "/sign")
		_add("Crops.png", Rect2i(16, row * 32 + 16, 16, 16), folder + "/seed_icon")
		for stage in range(4):
			_add(
				"Crops.png", Rect2i((stage + 2) * 16, row * 32, 16, 32),
				folder + "/stage_%02d" % (stage + 1)
			)
		_add("Crops.png", Rect2i(96, row * 32 + 16, 16, 16), folder + "/harvest_icon")

	# Ba giai đoạn cây chung. Cây có quả là texture riêng, dùng khi sẵn sàng thu hoạch.
	for stage in range(3):
		_add(
			"Fruit_Tree_Stages.png", Rect2i(stage * 32, 0, 32, 64),
			"fruit_trees/shared/stage_%02d" % (stage + 1)
		)
	for fruit in ["apple", "pear", "peach", "cherry"]:
		var source := String(fruit).capitalize() + "_Tree.png"
		_add(source, Rect2i(0, 0, 32, 64), "fruit_trees/%s/ready" % fruit)
	for column in range(FRUIT_NAMES.size()):
		_add(
			"Fruit_Trees_Fruit_Objects.png", Rect2i(column * 16, 0, 16, 16),
			"fruit_objects/" + FRUIT_NAMES[column]
		)

	# Giàn nho có 3 trạng thái hàng đầu, 2 trạng thái hàng dưới; ô thứ 6 trống.
	for stage in range(5):
		var column := stage % 3
		var row := stage / 3
		_add(
			"Grapes_Bower.png", Rect2i(column * 96, row * 80, 96, 80),
			"grapes_bower/stage_%02d" % (stage + 1)
		)

	# Berries: 4 hình bụi mỗi màu, không giả định thứ tự tăng trưởng hay loop.
	for variant in range(2):
		var color := "red" if variant == 0 else "purple"
		for pose in range(4):
			_add(
				"Berries.png", Rect2i(variant * 32, pose * 16, 16, 16),
				"berries/%s/appearance_%02d" % [color, pose + 1]
			)
		_add(
			"Berries.png", Rect2i(variant * 32 + 16, 0, 16, 16),
			"berries/%s/harvest_icon" % color
		)


func _add(source: String, region: Rect2i, path: String) -> void:
	_entries.append({"source": source, "region": region, "path": path})


func _save_texture(entry: Dictionary) -> void:
	var output_path := OUTPUT_ROOT.path_join(String(entry["path"]) + ".tres")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if mkdir_error != OK:
		_fail("Không tạo được folder %s: lỗi %d" % [output_path.get_base_dir(), mkdir_error])
		return
	var atlas := AtlasTexture.new()
	atlas.resource_name = String(entry["path"]).replace("/", "_")
	atlas.atlas = _textures[entry["source"]]
	atlas.region = Rect2(entry["region"])
	atlas.filter_clip = true
	# Giữ PNG là external resource; không bundle cache .godot/imported.
	var save_error := ResourceSaver.save(atlas, output_path)
	if save_error != OK:
		_fail("Không lưu được %s: lỗi %d" % [output_path, save_error])
		return
	_saved += 1


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
