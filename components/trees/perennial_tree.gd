class_name PerennialTree
extends StaticBody2D
## Timestamp là nguồn sự thật; tween chỉ thay đổi hình ảnh.
const TREE_WIND: ShaderMaterial = preload("res://resources/effects/tree_wind_48.tres")
static var _wind_materials: Dictionary[Texture2D, ShaderMaterial] = {}
var definition: TreeDefinition
var plantation: TreePlantation
var cell: Vector2i
var planted_at: float = 0.0
var growth_started_at: float = -1.0
var matures_at: float = 0.0
var last_at: float = 0.0
var stage: int = 0
var removed: bool = false
var sprite: Sprite2D
var motion: VisualMotionComponent
var trunk: CollisionShape2D
var visual: Node2D

func _ready() -> void:
	add_to_group(&"perennial_trees")
	collision_layer = 1
	collision_mask = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual = Node2D.new()
	add_child(visual)
	sprite = Sprite2D.new()
	sprite.name = "TreeVisual"
	visual.add_child(sprite)
	trunk = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(15, 6)
	trunk.shape = shape
	trunk.position = Vector2(0, -3)
	add_child(trunk)
	motion = VisualMotionComponent.new()
	motion.target = visual
	motion.pivot = Vector2.ZERO
	add_child(motion)
	update_visual()

func initialize(now: float) -> void:
	planted_at = now
	last_at = now
	growth_started_at = -1.0
	matures_at = 0.0
	stage = 0
	removed = false

func refresh(now: float, _fruit_rate: float = 1.0) -> void:
	last_at = maxf(last_at, now)
	if growth_started_at >= 0.0:
		var progress: float = clampf((last_at - growth_started_at) / (matures_at - growth_started_at), 0.0, 1.0)
		stage = mini(2, int(floor(progress * 2.0)))
	update_visual()

func is_mature() -> bool:
	return not removed and growth_started_at >= 0.0 and last_at >= matures_at

func update_visual() -> void:
	if sprite == null or definition == null:
		return
	set_texture(definition.stage_textures[stage])

func set_texture(texture: Texture2D) -> void:
	if sprite.texture == texture:
		return
	sprite.texture = texture
	# Bỏ khoảng đệm trong suốt khi neo gốc, giữ collider và hình cây trùng nhau.
	var bounds: Rect2i = texture.get_image().get_used_rect()
	sprite.position = Vector2(0, texture.get_height() * 0.5 - bounds.end.y)
	# Chia sẻ material theo texture; TIME và vị trí thế giới tạo nhịp riêng trên GPU.
	# Không thêm _process/Tween lặp cho từng cây và không làm lệch collider.
	if texture == definition.stump_texture:
		sprite.material = null
		return
	if not _wind_materials.has(texture):
		var wind: ShaderMaterial = TREE_WIND.duplicate() as ShaderMaterial
		wind.set_shader_parameter(&"anchor_visible_root", true)
		wind.set_shader_parameter(&"ground_y", -sprite.position.y)
		wind.set_shader_parameter(&"plant_height", float(maxi(1, bounds.size.y)))
		wind.set_shader_parameter(&"amplitude", clampf(bounds.size.y * 0.04, 0.35, 2.4))
		_wind_materials[texture] = wind
	sprite.material = _wind_materials[texture]

func get_status_sprite() -> Node2D:
	return sprite

func set_status_focused(value: bool) -> void:
	if is_instance_valid(motion):
		motion.set_focused(value and not removed)

func react() -> void:
	if motion != null:
		motion.react()

func retire() -> void:
	removed = true
	if plantation != null:
		plantation.remove_tree(self)
	if is_inside_tree():
		queue_free()

func action_text(_item: ItemDefinition) -> String:
	return definition.display_name

func capture() -> Dictionary:
	return {"tree": String(definition.tree_id), "cell": [cell.x, cell.y], "planted_at": planted_at, "growth_started_at": growth_started_at, "matures_at": matures_at, "last_at": last_at}

func restore_state(row: Dictionary) -> void:
	planted_at = float(row.planted_at)
	growth_started_at = float(row.growth_started_at)
	matures_at = float(row.matures_at)
	last_at = float(row.last_at)
	refresh(last_at)
