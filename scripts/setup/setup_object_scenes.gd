extends SceneTree

# godot --headless --path . --script res://scripts/setup/setup_object_scenes.gd
# Thêm -- --overwrite để tạo lại các scene đã sinh, sau khi đã lưu chỉnh sửa riêng.
const OUTPUT_ROOT := "res://scenes/objects"
const INDEX_PATH := "res://docs/object_scenes_index.json"
const DECOR_MATRIX := "res://scripts/setup/data/house_decor_selection_matrix_v2.json"
const DECOR_TILESET := "res://tilesets/house_decor/house_decor_tiles.tres"
const COLLISION_POLICY := "res://scripts/setup/data/object_collision_policy.json"
const NAME_CATALOG := "res://scripts/setup/data/object_scene_names.json"
const FRUIT_NAMES := ["apple", "pear", "peach", "cherry"]

var _names: Dictionary = {}
var _collision_policy: Dictionary = {}
var _entries: Array[Dictionary] = []
var _failed := 0
var _saved := 0
var _skipped := 0
var _overwrite := false


func _initialize() -> void:
	_overwrite = OS.get_cmdline_user_args().has("--overwrite")
	var catalog := JSON.new()
	if catalog.parse(FileAccess.get_file_as_string(NAME_CATALOG)) != OK or not catalog.data is Dictionary:
		_fail("Không đọc được danh mục tên scene.")
		quit(1)
		return
	_names = catalog.data
	if catalog.parse(FileAccess.get_file_as_string(COLLISION_POLICY)) != OK or not catalog.data is Dictionary:
		_fail("Không đọc được quy tắc collision.")
		quit(1)
		return
	_collision_policy = catalog.data
	_add_characters()
	_add_animated_props("res://sprite_frames/house_decor", "house_decor/animated")
	_add_animated_props("res://sprite_frames/outdoor_decor", "outdoor_decor")
	_add_house_decor()
	_add_crops()
	_add_items()
	_validate_entries()
	if _failed > 0:
		quit(1)
		return
	var counts: Dictionary = {}
	var index: Array[Dictionary] = []
	for entry in _entries:
		counts[entry["category"]] = int(counts.get(entry["category"], 0)) + 1
		_save_scene(entry)
		index.append({
			"scene": entry["path"], "object_id": String(entry["path"]).get_file().get_basename(), "category": entry["category"], "kind": entry["kind"],
			"body": "CharacterBody2D" if entry["movable"] else "StaticBody2D",
			"sprite": "AnimatedSprite2D" if entry["visual"] is SpriteFrames else "Sprite2D",
			"source": entry["source"], "animation": entry.get("animation", ""),
			"texture_options": entry.get("texture_paths", []),
			"atlas_cells": entry.get("atlas_cells", []),
			"has_collision": _needs_collision(entry),
		})
	if _failed == 0:
		_save_index({"scene_count": index.size(), "categories": counts, "scenes": index})
	print("Object scenes: %d tạo, %d giữ scene đã có, %d lỗi. Nhóm: %s" % [_saved, _skipped, _failed, counts])
	quit(1 if _failed > 0 else 0)


func _add_characters() -> void:
	for file_name in DirAccess.get_files_at("res://sprite_frames/character"):
		if file_name.get_extension() != "tres":
			continue
		var name := file_name.get_basename().trim_suffix("_frames")
		_add_animated("characters/" + name, "res://sprite_frames/character/" + file_name, "characters", name, &"idle_down", true)


func _add_animated_props(source_folder: String, output_folder: String) -> void:
	for file_name in DirAccess.get_files_at(source_folder):
		if file_name.get_extension() != "tres":
			continue
		var name := file_name.get_basename().trim_suffix("_frames")
		var animation := &"idle"
		if name.contains("chest") or name.contains("gate"):
			animation = &"closed"
		elif name == "furnace":
			animation = &"off"
		elif name == "chimney_smoke":
			animation = &"smoke"
		elif name == "fountain":
			animation = &"flow"
		elif name.contains("torch") or name.contains("fireplace") or name == "campfire":
			animation = &"burn"
		var category := "house_decor_animated" if output_folder.begins_with("house_decor") else "outdoor_decor"
		var scene_name := String(_names.get("outdoor_decor", {}).get(name, name)) if category == "outdoor_decor" else name
		_add_animated(output_folder + "/" + scene_name, source_folder.path_join(file_name), category, scene_name, animation)


func _add_animated(relative_path: String, resource_path: String, category: String, kind: String, animation: StringName, movable: bool = false) -> void:
	var frames := load(resource_path) as SpriteFrames
	if frames == null or not frames.has_animation(animation) or frames.get_frame_count(animation) == 0:
		_fail("Thiếu SpriteFrames/animation: %s %s" % [resource_path, animation])
		return
	var entry := _entry(relative_path, frames, category, kind, resource_path)
	entry["animation"] = animation
	entry["movable"] = movable
	_entries.append(entry)


func _add_house_decor() -> void:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(DECOR_MATRIX)) != OK or not json.data is Dictionary:
		_fail("Không đọc được ma trận nội thất.")
		return
	var tileset := load(DECOR_TILESET) as TileSet
	if tileset == null:
		_fail("Không nạp được TileSet nội thất.")
		return
	for config in json.data["sources"]:
		var source_id := int(config["source_id"])
		if not tileset.has_source(source_id):
			_fail("Thiếu atlas source nội thất: %d" % source_id)
			continue
		var source := tileset.get_source(source_id) as TileSetAtlasSource
		var folder := String(config["file"]).get_basename().to_snake_case()
		if source == null or source.texture.resource_path != "res://assets/Buildings/House_Decor/" + config["file"]:
			_fail("PNG của atlas source không khớp ma trận: " + String(config["file"]))
			continue
		for group in config["groups"]:
			var kind := String(group["name"])
			# Đây là các mảnh ghép mặt bếp, không phải object nguyên khối.
			if kind == "modular_countertop":
				continue
			for index in range(group["rects"].size()):
				var value: Array = group["rects"][index]
				var coords := Vector2i(value[0], value[1])
				var size := Vector2i(value[2], value[3])
				if not source.has_tile(coords) or source.get_tile_size_in_atlas(coords) != size:
					_fail("TileSet khác ma trận tại %s %s." % [config["file"], coords])
					continue
				var atlas := AtlasTexture.new()
				atlas.atlas = source.texture
				atlas.region = Rect2(source.get_tile_texture_region(coords))
				atlas.filter_clip = true
				var name := "%s_%03d" % [kind, index + 1]
				var entry := _entry("house_decor/" + folder + "/" + name, atlas, "house_decor_static", kind, source.texture.resource_path)
				entry["atlas_cells"] = value
				_entries.append(entry)


func _add_crops() -> void:
	for crop_number in range(1, 23):
		var source_name := "crop_%02d" % crop_number
		var name := _semantic_name("crops", source_name)
		var folder := "res://crops/field/" + source_name
		var paths: Array[String] = []
		for stage in range(1, 5):
			paths.append(folder + "/stage_%02d.tres" % stage)
		_add_texture_options("crops/field/" + name, paths, "crop", 0, "growth_textures")
		_add_static("crops/signs/" + name + "_sign", folder + "/sign.tres", "crops", "crop_sign")
		_add_static("items/seeds/" + name + "_seed", folder + "/seed_icon.tres", "items", "seed")
		_add_static("items/harvest/" + name + "_harvest", folder + "/harvest_icon.tres", "items", "harvest")
	for fruit in FRUIT_NAMES:
		var paths: Array[String] = []
		for stage in range(1, 4):
			paths.append("res://crops/fruit_trees/shared/stage_%02d.tres" % stage)
		paths.append("res://crops/fruit_trees/%s/ready.tres" % fruit)
		_add_texture_options("crops/fruit_trees/" + fruit + "_tree", paths, "fruit_tree", 3, "growth_textures")
	var grape_paths: Array[String] = []
	for stage in range(1, 6):
		grape_paths.append("res://crops/grapes_bower/stage_%02d.tres" % stage)
	_add_texture_options("crops/grapes_bower", grape_paths, "grapes_bower", 4, "growth_textures")
	for color in ["red", "purple"]:
		var paths: Array[String] = []
		for pose in range(1, 5):
			paths.append("res://crops/berries/%s/appearance_%02d.tres" % [color, pose])
		_add_texture_options("crops/berries/" + color + "_berry_bush", paths, "berry_bush", 0, "appearance_textures")
		_add_static("items/harvest/" + color + "_berries", "res://crops/berries/" + color + "/harvest_icon.tres", "items", "harvest")
	for fruit in ["grapes", "apple", "pear", "peach", "cherry"]:
		_add_static("items/fruits/" + fruit, "res://crops/fruit_objects/" + fruit + ".tres", "items", "fruit")


func _add_texture_options(relative_path: String, paths: Array[String], kind: String, initial: int, metadata_key: String) -> void:
	var textures: Array[Texture2D] = []
	for path in paths:
		var texture := load(path) as Texture2D
		if texture == null:
			_fail("Thiếu texture biến thể/giai đoạn: " + path)
			return
		textures.append(texture)
	var entry := _entry(relative_path, textures[initial], "crops", kind, paths[initial])
	entry["texture_paths"] = paths
	entry["texture_options"] = textures
	entry["options_key"] = metadata_key
	_entries.append(entry)


func _add_items() -> void:
	for style in ["outline", "no_outline"]:
		for category in ["food", "materials", "tools", "other"]:
			var folder: String = "res://icons/" + style + "/" + category
			for file_name in DirAccess.get_files_at(folder):
				if file_name.get_extension() == "tres":
					var name := _semantic_name("icons", file_name.get_basename(), category)
					_add_static("items/" + style + "/" + category + "/" + name, folder.path_join(file_name), "items", category)


func _semantic_name(group: String, key: String, category: String = "") -> String:
	var mapping: Dictionary = _names.get(group, {})
	if not category.is_empty():
		mapping = mapping.get(category, {})
	var value := String(mapping.get(key, ""))
	if value.is_empty() or value.to_snake_case() != value or value.contains("/"):
		_fail("Tên scene thiếu/không hợp lệ: %s/%s/%s" % [group, category, key])
	return value


func _add_static(relative_path: String, resource_path: String, category: String, kind: String) -> void:
	var texture := load(resource_path) as Texture2D
	if texture == null:
		_fail("Thiếu texture: " + resource_path)
		return
	_entries.append(_entry(relative_path, texture, category, kind, resource_path))


func _entry(relative_path: String, visual: Resource, category: String, kind: String, source: String) -> Dictionary:
	return {"path": OUTPUT_ROOT.path_join(relative_path + ".tscn"), "visual": visual, "category": category, "kind": kind, "source": source, "movable": false}


func _validate_entries() -> void:
	var paths: Dictionary = {}
	for entry in _entries:
		var path := String(entry["path"])
		if paths.has(path):
			_fail("Scene path trùng: " + path)
		paths[path] = true
		var texture := _initial_texture(entry)
		if texture == null or texture.get_image() == null or texture.get_image().get_used_rect().size == Vector2i.ZERO:
			_fail("Sprite khởi đầu không có hình: " + path)


func _initial_texture(entry: Dictionary) -> Texture2D:
	if entry["visual"] is SpriteFrames:
		var frames: SpriteFrames = entry["visual"]
		return frames.get_frame_texture(entry["animation"], 0)
	return entry["visual"] as Texture2D


func _visual_bounds(entry: Dictionary) -> Rect2i:
	var bounds := _initial_texture(entry).get_image().get_used_rect()
	# Một vị trí gốc dùng chung cho toàn bộ stage; không căn lại khi đổi texture.
	for texture in entry.get("texture_options", []):
		bounds = bounds.merge(texture.get_image().get_used_rect())
	return bounds


func _needs_collision(entry: Dictionary) -> bool:
	var category := String(entry["category"])
	var kind := String(entry["kind"])
	if category in _collision_policy["categories_without_collision"]:
		return false
	if category == "crops" and kind in _collision_policy["crop_kinds_without_collision"]:
		return false
	if category == "house_decor_static" and kind in _collision_policy["house_decor_kinds_without_collision"]:
		return false
	if category in ["outdoor_decor", "house_decor_animated"] and kind in _collision_policy["animated_kinds_without_collision"]:
		return false
	return true


func _save_scene(entry: Dictionary) -> void:
	var path := String(entry["path"])
	if FileAccess.file_exists(path) and not _overwrite:
		_skipped += 1
		return
	var body: PhysicsBody2D = CharacterBody2D.new() if entry["movable"] else StaticBody2D.new()
	body.name = path.get_file().get_basename().to_pascal_case()
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.set_meta("object_id", path.get_file().get_basename())
	body.set_meta("object_kind", entry["kind"])
	body.set_meta("source_visual", entry["source"])
	if entry.has("texture_options"):
		body.set_meta(entry["options_key"], entry["texture_options"])
	var texture := _initial_texture(entry)
	var bounds := _visual_bounds(entry)
	var sprite: Node2D
	if entry["visual"] is SpriteFrames:
		var animated := AnimatedSprite2D.new()
		animated.name = "AnimatedSprite2D"
		animated.sprite_frames = entry["visual"]
		animated.animation = entry["animation"]
		# Phát idle và hiệu ứng loop; trạng thái mở/phá chỉ được chọn khi thêm logic.
		if animated.sprite_frames.get_animation_loop(animated.animation):
			animated.autoplay = String(animated.animation)
		sprite = animated
	else:
		var still := Sprite2D.new()
		still.name = "Sprite2D"
		still.texture = texture
		sprite = still
	# Gốc object nằm ở đáy pixel hiển thị, kể cả sprite có padding 64x64 của NPC.
	sprite.position.y = texture.get_height() * 0.5 - bounds.end.y
	body.add_child(sprite)
	sprite.owner = body
	if _needs_collision(entry):
		var shape := RectangleShape2D.new()
		shape.size = Vector2(10, 4) if entry["movable"] else Vector2(maxf(4.0, bounds.size.x * 0.7), clampf(bounds.size.y * 0.2, 3.0, 12.0))
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		collision.shape = shape
		collision.position.y = -shape.size.y * 0.5
		# Kích thước chỉ là footprint tham khảo. Bật sau khi chỉnh theo object/gameplay.
		collision.disabled = true
		body.add_child(collision)
		collision.owner = body
	var packed := PackedScene.new()
	var error := packed.pack(body)
	if error == OK:
		error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error == OK:
		error = ResourceSaver.save(packed, path)
	body.free()
	if error != OK:
		_fail("Không lưu được scene %s: lỗi %d." % [path, error])
		return
	_saved += 1


func _save_index(index: Dictionary) -> void:
	var file := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Không lưu được danh mục scene.")
		return
	file.store_string(JSON.stringify(index, "\t") + "\n")


func _fail(message: String) -> void:
	_failed += 1
	push_error(message)
