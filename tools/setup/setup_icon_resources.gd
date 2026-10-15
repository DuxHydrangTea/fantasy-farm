extends SceneTree

# Chạy: godot --headless --path . --script res://tools/setup/setup_icon_resources.gd
const SOURCE_ROOT := "res://common/ui/icons/art"
const OUTPUT_ROOT := "res://common/ui/icons/textures"
const CELL_SIZE := 16
const STYLES := [
	["Outline", "outline", "Outline"],
	["No Outline", "no_outline", "NO_Outline"],
]
# [Tiền tố sheet, folder nhóm, số cột, số hàng, số icon không trống].
# Other_Icons_2_Outline là bản sao 17 ô từ các sheet khác, không tạo lặp.
const SHEETS := [
	["Food_Icons", "food", 8, 12, 83],
	["Resources_Icons", "materials", 6, 6, 34],
	["Tool_Icons", "tools", 10, 1, 10],
	["Other_Icons", "other", 5, 3, 11],
]

var _saved := 0
var _failed := 0


func _initialize() -> void:
	for style in STYLES:
		for sheet in SHEETS:
			_generate_sheet(style, sheet)
	print("Icon AtlasTexture: %d đã lưu, %d lỗi. Output: %s" % [_saved, _failed, OUTPUT_ROOT])
	quit(1 if _failed > 0 else 0)


func _generate_sheet(style: Array, sheet: Array) -> void:
	var source_path := SOURCE_ROOT.path_join(String(style[0])).path_join(
		"%s_%s.png" % [sheet[0], style[2]]
	)
	var texture := load(source_path) as Texture2D
	if texture == null:
		_fail("Không load được texture: " + source_path)
		return
	var expected_size := Vector2i(int(sheet[2]) * CELL_SIZE, int(sheet[3]) * CELL_SIZE)
	if Vector2i(texture.get_size()) != expected_size:
		_fail("Kích thước sheet không khớp: " + source_path)
		return
	var image := texture.get_image()
	if image == null:
		_fail("Không đọc được pixel: " + source_path)
		return

	# Kiểm tra toàn bộ ô trước khi ghi resource của sheet.
	var regions: Array[Rect2i] = []
	for row in range(int(sheet[3])):
		for column in range(int(sheet[2])):
			var region := Rect2i(column * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE)
			if not image.get_region(region).is_invisible():
				regions.append(region)
	if regions.size() != int(sheet[4]):
		_fail("Số icon không khớp (%d/%d): %s" % [regions.size(), sheet[4], source_path])
		return

	var output_dir := OUTPUT_ROOT.path_join(String(style[1])).path_join(String(sheet[1]))
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		_fail("Không tạo được %s: lỗi %d" % [output_dir, mkdir_error])
		return
	for region in regions:
		# Hàng/cột trong tên bắt đầu từ 1, đúng vị trí trong PNG.
		var row := region.position.y / CELL_SIZE + 1
		var column := region.position.x / CELL_SIZE + 1
		var icon_name := "%s_r%02d_c%02d" % [sheet[1], row, column]
		var icon := AtlasTexture.new()
		icon.resource_name = icon_name
		icon.atlas = texture
		icon.region = Rect2(region)
		icon.filter_clip = true
		var output_path := output_dir.path_join(icon_name + ".tres")
		# PNG gốc được tham chiếu externally, không bundle cache .godot/imported.
		var save_error := ResourceSaver.save(icon, output_path)
		if save_error != OK:
			_fail("Không lưu được %s: lỗi %d" % [output_path, save_error])
			continue
		_saved += 1
	print("%s/%s: %d icon" % [style[1], sheet[1], regions.size()])


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
