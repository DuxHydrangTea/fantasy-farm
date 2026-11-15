extends RefCounted
## Ghép hoạt ảnh chặt rìu cho trang phục Farmer Bob từ các lớp ảnh hiện có.
## Kết quả được cache và tạo từ bản sao SpriteFrames nguồn.

## Đường dẫn bộ frame Farmer Bob được hỗ trợ.
const BOB_FRAMES: String = "res://sprite_frames/character/farmer_bob_frames.tres"
## Các lớp cơ thể và trang phục được ghép theo thứ tự.
const BODY_LAYERS: Array[String] = [
	"res://assets/Player/Player_Base/Player_Base_animations.png",
	"res://assets/Player/Legs/Farmer_Pants/Farmer_Pants_1_Blue.png",
	"res://assets/Player/Chest/Farmer_Shirt/Farmer_Shirt_1_Blue.png",
	"res://assets/Player/Feet/Shoes_1_Brown.png",
	"res://assets/Player/Head/Hair_1/Hair_1_Brown.png",
	"res://assets/Player/Accessories/Farmer_Hat_1.png",
]
## Ảnh công cụ rìu.
const AXE_LAYER: String = "res://assets/Player/Tools/Iron/Iron_Tools.png"
## Ảnh bàn tay.
const HANDS_LAYER: String = "res://assets/Player/Hands/Hands_1_Bare.png"
## Các hướng có clip riêng; hướng trái được xử lý bằng lật ảnh.
const DIRECTIONS: Array[String] = ["down", "right", "up"]
static var _cached_frames: SpriteFrames

## Trả bản sao có clip chặt cho bộ Farmer Bob, hoặc nguồn nguyên vẹn nếu khác.
## Các lần gọi sau tái sử dụng bộ frame đã ghép.
static func for_player(source: SpriteFrames) -> SpriteFrames:
	if source == null or source.resource_path != BOB_FRAMES:
		return source
	if _cached_frames != null:
		return _cached_frames
	var layers: Array[Image] = []
	for path: String in BODY_LAYERS:
		layers.append((load(path) as Texture2D).get_image())
	var axe: Image = (load(AXE_LAYER) as Texture2D).get_image()
	var hands: Image = (load(HANDS_LAYER) as Texture2D).get_image()
	var result: SpriteFrames = source.duplicate() as SpriteFrames
	for direction: int in range(DIRECTIONS.size()):
		var clip: StringName = StringName("chop_" + DIRECTIONS[direction])
		result.add_animation(clip)
		result.set_animation_loop(clip, false)
		result.set_animation_speed(clip, source.get_animation_speed(StringName("tool_" + DIRECTIONS[direction])))
		for frame: int in range(6):
			# Modular character rows 35–37 are axe swings; tool rows 0–2
			# match down/right/up. Left reuses right through AnimationComponent.
			var region: Rect2i = Rect2i(frame * 64, (35 + direction) * 64, 64, 64)
			var image: Image = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
			for layer: Image in layers:
				image.blend_rect(layer, region, Vector2i.ZERO)
			image.blend_rect(axe, Rect2i(frame * 64, direction * 64, 64, 64), Vector2i.ZERO)
			image.blend_rect(hands, region, Vector2i.ZERO)
			result.add_frame(clip, ImageTexture.create_from_image(image))
	_cached_frames = result
	return result
