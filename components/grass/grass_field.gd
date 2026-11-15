class_name GrassField
extends Node2D
## Field thử nghiệm vẽ một batch cỏ GPU từ mẫu tĩnh.
## Mỗi bụi không có callback riêng; field này không chia chunk hoặc nhận actor.

## Shader cỏ mặc định.
const SHADER: Shader = preload("res://shaders/grass_field.gdshader")
## Số bụi tạo mặc định khi chưa cung cấp mẫu.
@export_range(1, 500) var tuft_count: int = 324
## Số cột của lưới mẫu mặc định.
@export_range(1, 50) var columns: int = 18
## Khoảng cách giữa các mẫu mặc định.
@export var spacing: Vector2 = Vector2(24, 22)
## Cường độ gió từ 0 đến 6.
@export_range(0.0, 6.0) var wind_strength: float = 0.85
## Hướng gió truyền cho shader.
@export var wind_direction: Vector2 = Vector2.RIGHT
## Bật hoạt ảnh khung hình cỏ.
@export var animate_frames: bool = true
## Catalog texture và loại cỏ.
var catalog: GrassSourceCatalog = GrassSourceCatalog.new()
## Bộ vẽ một batch.
var renderer: GrassPocRenderer = GrassPocRenderer.new()
## Material shader dùng chung.
var effect: ShaderMaterial
## Danh sách mẫu chứa loại, transform và pha.
var samples: Array[Dictionary] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_notify_transform(true)
	effect = ShaderMaterial.new()
	effect.shader = SHADER
	set_wind(wind_strength, wind_direction)
	set_animation(animate_frames)
	if samples.is_empty():
		for index: int in range(tuft_count):
			var row: int = floori(float(index) / float(columns))
			var origin: Vector2 = Vector2(index % columns, row) * spacing
			samples.append({"type": row % catalog.size(), "transform": Transform2D(0.0, origin), "phase": float(index % 17) / 17.0})
	set_samples(samples)

## Đặt mẫu và dựng lại batch nếu material đã sẵn sàng.
func set_samples(values: Array[Dictionary]) -> void:
	samples = values.duplicate()
	if effect == null:
		return
	renderer.build(get_canvas_item(), catalog, samples, effect)
	_refresh_bounds()

## Đặt gió, cập nhật shader và biên culling.
func set_wind(strength: float, direction: Vector2 = Vector2.RIGHT) -> void:
	wind_strength = clampf(strength, 0.0, 6.0)
	wind_direction = direction
	if effect != null:
		effect.set_shader_parameter(&"wind_strength", wind_strength)
		effect.set_shader_parameter(&"wind_direction", wind_direction)
	_refresh_bounds()

## Bật hoặc tắt hoạt ảnh khung hình trong shader.
func set_animation(enabled: bool) -> void:
	animate_frames = enabled
	if effect != null:
		effect.set_shader_parameter(&"animate_frames", enabled)

## Đặt thời gian shader cố định tùy chọn để kiểm thử.
func set_test_time(value: float, enabled: bool = true) -> void:
	effect.set_shader_parameter(&"use_test_time", enabled)
	effect.set_shader_parameter(&"test_time", value)

func _refresh_bounds() -> void:
	if not is_inside_tree():
		return
	var basis: Transform2D = get_global_transform()
	var minimum_scale: float = maxf(0.001, minf(basis.x.length(), basis.y.length()))
	renderer.update_bounds(wind_strength * 1.25 / minimum_scale)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and renderer != null:
		_refresh_bounds()

func _exit_tree() -> void:
	renderer.clear()
