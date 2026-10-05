@tool
extends EditorScript

const TEXTURE_PATH = "res://assets/NPCs (Premade)/Farmer_Bob.png"
const SAVE_PATH = "res://tilesets/farmer_bob_frames.tres"

const TOTAL_COLS = 6
const TOTAL_ROWS = 13
const DEFAULT_FPS = 8.0

const ANIM_CONFIG = [
	["idle_down", 6, true],
	["idle_right", 6, true],
	["idle_up", 6, true],
	["walk_down", 6, true],
	["walk_right", 6, true],
	["walk_up", 6, true],
	["faint", 4, false],
	["tool_down", 6, false],
	["tool_right", 6, false],
	["tool_up", 6, false],
	["water_down", 6, false],
	["water_right", 6, false],
	["water_up", 6, false]
]

func _run() -> void:
	# 1. Kiểm tra load Texture
	var tex: Texture2D = load(TEXTURE_PATH)
	if not tex:
		printerr("LỖI: Không tìm thấy ảnh tại đường dẫn: ", TEXTURE_PATH)
		return

	var img_w = tex.get_width()
	var img_h = tex.get_height()
	var frame_w = img_w / TOTAL_COLS
	var frame_h = img_h / TOTAL_ROWS

	print("Kích thước file ảnh: %dx%d pixel" % [img_w, img_h])
	print("Kích thước mỗi frame: %dx%d pixel" % [frame_w, frame_h])

	# 2. Đảm bảo thư mục lưu tồn tại
	var save_dir = SAVE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(save_dir):
		var make_dir_err = DirAccess.make_dir_recursive_absolute(save_dir)
		if make_dir_err != OK:
			printerr("LỖI: Không thể tạo thư mục lưu: ", save_dir)
			return

	# 3. Tạo SpriteFrames
	var sprite_frames = SpriteFrames.new()
	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")

	for row in range(ANIM_CONFIG.size()):
		var anim_name: String = ANIM_CONFIG[row][0]
		var frame_count: int = ANIM_CONFIG[row][1]
		var is_loop: bool = ANIM_CONFIG[row][2]

		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_speed(anim_name, DEFAULT_FPS)
		sprite_frames.set_animation_loop(anim_name, is_loop)

		for col in range(frame_count):
			var atlas = AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
			# Đánh dấu resource để Godot gom bundle vào file .tres chuẩn xác
			atlas.resource_local_to_scene = false
			sprite_frames.add_frame(anim_name, atlas)

	# 4. Lưu file với cờ FLAG_BUNDLE_RESOURCES
	var err = ResourceSaver.save(sprite_frames, SAVE_PATH, ResourceSaver.FLAG_BUNDLE_RESOURCES)
	if err == OK:
		print(">> THÀNH CÔNG: Đã tạo SpriteFrames tại: %s" % SAVE_PATH)
	else:
		printerr(">> THẤT BÀI: Mã lỗi lưu file = %d" % err)
