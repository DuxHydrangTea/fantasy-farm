@tool
extends EditorScript

const SOURCE_ROOT := "res://entities/npcs/art"
const OUTPUT_ROOT := "res://entities/npcs/animations"
const CELL := Vector2i(64, 64)
const DEFAULT_FPS := 8.0

# [Tên animation, số frame, loop], theo thứ tự hàng trên spritesheet.
# Hướng trái dùng flip_h của animation hướng phải, giống Farmer Bob.
const BASE_CONFIG := [
	["idle_down", 6, true],
	["idle_right", 6, true],
	["idle_up", 6, true],
	["walk_down", 6, true],
	["walk_right", 6, true],
	["walk_up", 6, true],
	["faint", 4, false],
]
# Hàng dùng công cụ/tưới nước: phải, xuống, lên (khác idle/walk).
const TOOL_CONFIG := [
	["tool_right", 6, false],
	["tool_down", 6, false],
	["tool_up", 6, false],
]
const WATER_CONFIG := [
	["water_right", 6, false],
	["water_down", 6, false],
	["water_up", 6, false],
]
# Fisherman có thứ tự hướng riêng: phải, xuống, lên.
# Mỗi hướng có một hàng thả cần (9 frame) và một hàng thu cần (8 frame).
const FISHING_CONFIG := [
	["cast_right", 9, false],
	["reel_right", 8, false],
	["cast_down", 9, false],
	["reel_down", 8, false],
	["cast_up", 9, false],
	["reel_up", 8, false],
]
const PROFILES := {
	"Bartender_Bruno": [],
	"Bartender_Katy": [],
	"Chef_Chloe": [],
	"Farmer_Bob": TOOL_CONFIG + WATER_CONFIG,
	"Farmer_Buba": TOOL_CONFIG + WATER_CONFIG,
	"Fisherman_Fin": FISHING_CONFIG,
	"Lumberjack_Jack": TOOL_CONFIG,
	"Miner_Mike": TOOL_CONFIG,
}


func _run() -> void:
	generate_all()


func generate_all() -> int:
	var failed := 0
	var saved := 0
	var files := DirAccess.get_files_at(SOURCE_ROOT)
	files.sort()
	for file_name in files:
		if file_name.get_extension().to_lower() != "png":
			continue
		if generate_npc(file_name.get_basename()):
			saved += 1
		else:
			failed += 1
	print("NPC SpriteFrames: %d đã lưu, %d lỗi. Output: %s" % [saved, failed, OUTPUT_ROOT])
	return failed


func generate_npc(npc_name: String) -> bool:
	if not PROFILES.has(npc_name):
		push_error("Chưa có profile animation cho NPC: " + npc_name)
		return false
	var source_path := SOURCE_ROOT.path_join(npc_name + ".png")
	var texture := load(source_path) as Texture2D
	if texture == null:
		push_error("Không load được texture: " + source_path)
		return false
	var config: Array = BASE_CONFIG + PROFILES[npc_name]
	var expected_width := 576 if npc_name == "Fisherman_Fin" else 384
	if texture.get_width() != expected_width or texture.get_height() != config.size() * CELL.y:
		push_error("Kích thước sheet không khớp profile: " + source_path)
		return false

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row in range(config.size()):
		var animation_name := StringName(config[row][0])
		var frame_count := int(config[row][1])
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, DEFAULT_FPS)
		frames.set_animation_loop(animation_name, bool(config[row][2]))
		for column in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(column * CELL.x, row * CELL.y, CELL.x, CELL.y)
			frames.add_frame(animation_name, atlas)

	var mkdir_error := DirAccess.make_dir_recursive_absolute(OUTPUT_ROOT)
	if mkdir_error != OK:
		push_error("Không tạo được thư mục NPC: lỗi %d" % mkdir_error)
		return false
	var output_path := OUTPUT_ROOT.path_join(npc_name.to_lower() + "_frames.tres")
	# PNG là external resource; không bundle đường dẫn cache .godot/imported.
	var save_error := ResourceSaver.save(frames, output_path)
	if save_error != OK:
		push_error("Không lưu được %s: lỗi %d" % [output_path, save_error])
		return false
	print("Đã lưu: ", output_path)
	return true
