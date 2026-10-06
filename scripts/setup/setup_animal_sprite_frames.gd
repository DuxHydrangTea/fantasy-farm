@tool
extends EditorScript

const SOURCE_ROOT := "res://assets/Animals"
const OUTPUT_ROOT := "res://sprite_frames/animals"

const DEFAULT_FPS := 8.0
const FLY_FPS := 12.0

# Thứ tự phần tử tương ứng hàng từ trên xuống.
# Số frame riêng cho từng loài, không suy ra từ chiều rộng sheet.
const MAMMAL_NAMES := [
	"idle_left",
	"idle_down",
	"idle_up",
	"walk_left",
	"walk_down",
	"walk_up",
	"graze_left",
	"chew_left",
	"lie_down_left",
	"stand_up_left",
	"sleep_start_left",
	"sleep_left",
	"hurt_left",
	"hurt_down",
	"hurt_up",
]

const MAMMAL_LOOPS := [
	true, true, true,
	true, true, true,
	true, true,
	false, false, false,
	true,
	false, false, false,
]

const MAMMAL_COUNTS := {
	"Cow": [
		2, 2, 2, 8, 8, 8, 8, 8,
		6, 6, 4, 8, 4, 4, 4,
	],
	"Horse": [
		2, 2, 2, 6, 6, 6, 8, 6,
		6, 6, 4, 8, 4, 4, 4,
	],
	"Pig": [
		2, 2, 2, 8, 8, 8, 9, 6,
		4, 4, 4, 8, 4, 4, 4,
	],
	"Sheep": [
		2, 2, 2, 8, 8, 8, 8, 8,
		4, 4, 4, 8, 4, 4, 4,
	],
}

# Chicken và Goose: cùng tên state, khác số frame peck.
# sleep/hurt được suy luận từ ký hiệu Z và chớp trắng.
const POULTRY_ACTIONS := [
	"idle",
	"walk",
	"peck",
	"sit",
	"sleep_start",
	"stand_up",
	"sleep",
	"hurt",
]

const POULTRY_LOOPS := [
	true, true, true, false,
	false, false, true, false,
]

# Duck và Swan: swim_sleep được suy luận từ ký hiệu Z.
const WATERFOWL_ACTIONS := [
	"idle",
	"walk",
	"sit",
	"stand_up",
	"sleep_start",
	"sleep",
	"hurt",
	"swim_idle",
	"swim",
	"swim_sleep",
]

const WATERFOWL_LOOPS := [
	true, true, false, false, false,
	true, false, true, true, true,
]

var _saved_count := 0
var _failed_count := 0


func _run() -> void:
	_saved_count = 0
	_failed_count = 0

	# Cow, Horse, Pig, Sheep.
	for species in ["Cow", "Horse", "Pig", "Sheep"]:
		_generate_species(
			species,
			Vector2i(32, 32),
			MAMMAL_NAMES,
			MAMMAL_COUNTS[species],
			MAMMAL_LOOPS
		)

	# Chicken bao gồm Chicken_01...18 và Rooster.
	_generate_two_directions(
		"Chicken",
		POULTRY_ACTIONS,
		[2, 6, 8, 3, 3, 3, 8, 4],
		POULTRY_LOOPS
	)

	_generate_two_directions(
		"Goose",
		POULTRY_ACTIONS,
		[2, 6, 12, 3, 3, 3, 8, 4],
		POULTRY_LOOPS
	)

	_generate_two_directions(
		"Duck",
		WATERFOWL_ACTIONS,
		[2, 6, 3, 3, 3, 8, 4, 2, 4, 8],
		WATERFOWL_LOOPS
	)

	_generate_two_directions(
		"Swan",
		WATERFOWL_ACTIONS,
		[2, 6, 3, 3, 3, 8, 4, 2, 3, 8],
		WATERFOWL_LOOPS
	)

	# Frog hàng 2: croak là tên suy luận, cần review.
	_generate_species(
		"Frog",
		Vector2i(32, 32),
		[
			"idle_right",
			"croak_right",
			"tongue_attack_right",
			"hurt_right",
		],
		[2, 8, 10, 4],
		[true, false, false, false]
	)

	# Mouse hàng 1–2: idle/walk là tên suy luận.
	_generate_species(
		"Mouse",
		Vector2i(32, 32),
		["idle_right", "walk_right", "eat_right", "hurt_right"],
		[6, 6, 10, 4],
		[true, true, true, false]
	)

	_generate_bee()
	_generate_butterflies()
	_generate_kapybaras()

	print(
		"Hoàn tất: %d SpriteFrames đã lưu, %d lỗi. Output: %s"
		% [_saved_count, _failed_count, OUTPUT_ROOT]
	)


func _generate_species(
	species: String,
	cell: Vector2i,
	names: Array,
	counts: Array,
	loops: Array
) -> void:
	var source_dir := SOURCE_ROOT.path_join(species)

	if not DirAccess.dir_exists_absolute(source_dir):
		_fail("Không tìm thấy thư mục: " + source_dir)
		return

	var files := DirAccess.get_files_at(source_dir)
	files.sort()

	for file_name in files:
		if file_name.get_extension().to_lower() != "png":
			continue

		_generate_sheet(
			source_dir.path_join(file_name),
			species.to_lower(),
			file_name.get_basename().to_lower(),
			cell,
			names,
			counts,
			loops
		)


func _generate_two_directions(
	species: String,
	actions: Array,
	counts_per_direction: Array,
	loops_per_direction: Array
) -> void:
	var names: Array = []
	var counts: Array = []
	var loops: Array = []

	for direction in ["down_left", "up_left"]:
		for index in range(actions.size()):
			names.append("%s_%s" % [actions[index], direction])
			counts.append(counts_per_direction[index])
			loops.append(loops_per_direction[index])

	_generate_species(
		species,
		Vector2i(32, 32),
		names,
		counts,
		loops
	)


func _generate_sheet(
	source_path: String,
	output_species: String,
	variant: String,
	cell: Vector2i,
	names: Array,
	counts: Array,
	loops: Array,
	fps: float = DEFAULT_FPS
) -> void:
	if names.size() != counts.size() or names.size() != loops.size():
		_fail("Cấu hình không đồng bộ: " + source_path)
		return

	var texture := _load_texture(source_path)
	if texture == null:
		return

	if (
		texture.get_width() % cell.x != 0
		or texture.get_height() != names.size() * cell.y
	):
		_fail("Kích thước sheet không khớp cấu hình: " + source_path)
		return

	var frames := _new_sprite_frames()

	for row in range(names.size()):
		if not _add_animation(
			frames,
			texture,
			String(names[row]),
			row,
			cell,
			int(counts[row]),
			bool(loops[row]),
			fps
		):
			return

	_save_frames(frames, output_species, variant)


func _generate_bee() -> void:
	# Hai hàng đều đập cánh.
	# fly_alt là tên tạm vì chưa rõ vai trò khác biệt của hàng 2.
	# Không lấy Bee_Hive.png và Bee_Nest.png.
	_generate_sheet(
		SOURCE_ROOT.path_join("Bee/Bee_Flying_Animation.png"),
		"bee",
		"bee",
		Vector2i(16, 16),
		["fly", "fly_alt"],
		[4, 4],
		[true, true],
		FLY_FPS
	)


func _generate_butterflies() -> void:
	var source_path := SOURCE_ROOT.path_join("Butterfly/Butterfly.png")
	var texture := _load_texture(source_path)

	if texture == null:
		return

	if texture.get_width() != 16 or texture.get_height() != 64:
		_fail("Butterfly phải có kích thước 16 × 64: " + source_path)
		return

	# Mỗi hàng màu -> một SpriteFrames có animation fly gồm 2 frame.
	for row in range(8):
		var frames := _new_sprite_frames()

		if not _add_animation(
			frames,
			texture,
			"fly",
			row,
			Vector2i(8, 8),
			2,
			true,
			FLY_FPS
		):
			return

		_save_frames(
			frames,
			"butterfly",
			"butterfly_%02d" % (row + 1)
		)


func _generate_kapybaras() -> void:
	# [Hậu tố file, state, số frame, loop]
	const CONFIG := [
		["Idle", "idle", 9, true],
		["LookAround", "look_around", 10, false],
		["Dive", "dive", 9, false],
		["LookAround_submerged", "look_around_submerged", 9, false],
		["Bubbles", "bubbles", 25, true],
		["Emerge", "emerge", 10, false],
	]

	for prefix in ["Kapybara", "Albino_Kapybara"]:
		var frames := _new_sprite_frames()
		var valid := true

		for entry in CONFIG:
			var source_path := SOURCE_ROOT.path_join(
				"Kapybara/Static/%s_%s.png" % [prefix, entry[0]]
			)
			var texture := _load_texture(source_path)

			if texture == null:
				valid = false
				break

			var frame_count := int(entry[2])

			if (
				texture.get_width() != frame_count * 32
				or texture.get_height() != 32
			):
				_fail("Kích thước dải Kapybara không khớp: " + source_path)
				valid = false
				break

			if not _add_animation(
				frames,
				texture,
				String(entry[1]),
				0,
				Vector2i(32, 32),
				frame_count,
				bool(entry[3]),
				DEFAULT_FPS
			):
				valid = false
				break

		if valid:
			_save_frames(frames, "kapybara", prefix.to_lower())


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		_fail("Không tìm thấy texture hoặc chưa import: " + path)
		return null

	var texture := load(path) as Texture2D

	if texture == null:
		_fail("Không load được Texture2D: " + path)

	return texture


func _new_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	return frames


func _add_animation(
	frames: SpriteFrames,
	texture: Texture2D,
	animation_name: String,
	row: int,
	cell: Vector2i,
	frame_count: int,
	loop: bool,
	fps: float
) -> bool:
	if (
		frame_count <= 0
		or row < 0
		or frame_count * cell.x > texture.get_width()
		or (row + 1) * cell.y > texture.get_height()
	):
		_fail(
			"Region vượt kích thước texture: %s / %s"
			% [texture.resource_path, animation_name]
		)
		return false

	var name := StringName(animation_name)
	frames.add_animation(name)
	frames.set_animation_speed(name, fps)
	frames.set_animation_loop(name, loop)

	for column in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			column * cell.x,
			row * cell.y,
			cell.x,
			cell.y
		)
		frames.add_frame(name, atlas)

	return true


func _save_frames(
	frames: SpriteFrames,
	species: String,
	variant: String
) -> void:
	var output_dir := OUTPUT_ROOT
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)

	if mkdir_error != OK:
		_fail(
			"Không tạo được thư mục %s: lỗi %d"
			% [output_dir, mkdir_error]
		)
		return

	var output_path := output_dir.path_join(variant + "_frames.tres")

	# Giữ PNG làm external resource.
	# AtlasTexture được lưu thành subresource trong .tres.
	var save_error := ResourceSaver.save(frames, output_path)

	if save_error != OK:
		_fail(
			"Không lưu được %s: lỗi %d"
			% [output_path, save_error]
		)
		return

	_saved_count += 1
	print("Đã lưu: ", output_path)


func _fail(message: String) -> void:
	_failed_count += 1
	push_error(message)
