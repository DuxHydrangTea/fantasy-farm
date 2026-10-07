# Thiết kế cơ chế trồng trọt và hướng dẫn triển khai

Tài liệu dành cho cấu trúc Godot hiện tại của `fantasy-farm`. Đây là thiết kế và code mẫu để triển khai từng bước; tạo tài liệu này chưa thêm cơ chế trồng trọt vào game. Các đoạn thay thế file được ghi rõ; không nối thêm một hàm trùng tên vào file đang có.

## 1. Quy tắc gameplay

Các yêu cầu đã thống nhất:

- Ô đất có số lượng và vị trí cố định, nằm trong `FarmLand`.
- Đất có hai trạng thái: Bình thường (khô) và Đã tưới (ướt).
- Cây có **4 giai đoạn**, dùng `stage_01.tres` đến `stage_04.tres`.
- Không phụ thuộc hệ thống ngày. Đất tự khô sau một khoảng thời gian, ví dụ 300 giây.
- Mỗi lần tưới cây khi đất đang khô giảm thời gian tăng trưởng, ví dụ 5%.

Các lựa chọn của bản đầu, có thể chỉnh sau:

- Cây tự lớn cả khi đất khô. Nước là phần thưởng tăng tiến độ, không phải điều kiện bắt buộc để lớn.
- Mỗi lần tưới hợp lệ cộng tiến độ bằng **5% tổng thời gian tăng trưởng ban đầu**, không phải 5% thời gian còn lại.
- Tưới đất ướt không có tác dụng, không cộng tiến độ và không đặt lại thời gian khô.
- Cho tưới ô trống, nhưng không cộng tiến độ cho cây trồng sau đó. Bonus chỉ áp dụng lên cây có mặt lúc tưới.
- Stage 4 là cây trưởng thành, thu hoạch được ngay; không có khoảng chờ bổ sung ở stage 4.
- Thu hoạch xóa cây, giữ trạng thái đất. Không tự mọc lại ở bản đầu.
- Thời gian chỉ chạy khi đang chơi và world đang hoạt động; pause và thoát game dừng tiến độ. Chưa tính tăng trưởng offline.

Ví dụ cây cần 1.200 giây (20 phút): mỗi lần tưới đất khô cộng 60 giây tiến độ. Nếu còn 30 giây, tưới sẽ đưa cây đến trưởng thành ngay; tiến độ không vượt 1.200 giây.

## 2. Chọn giải pháp

| Giải pháp | Ưu điểm | Đánh đổi |
| --- | --- | --- |
| Mỗi ô là scene có sprite đất, cây và Timer | Dễ nhìn từng ô trong editor | Phải thay cấu trúc đất đang vẽ bằng TileMap; nhiều node và logic lặp |
| Đất và cây đều là tile | Ít node | Cần cấu hình atlas cây; việc thêm hiệu ứng riêng cho cây kém thuận tiện |
| **Đất là TileMapLayer, dữ liệu theo ô, cây là scene hiển thị** | Giữ map hiện tại, tập trung logic, dễ thêm hiệu ứng và save | Cần ánh xạ tọa độ ô sang node cây |

Chọn phương án thứ ba. `FarmLand` là chủ sở hữu dữ liệu; hình tile và scene cây chỉ phản ánh dữ liệu đó. Không đọc màu đất hay sprite để suy luận gameplay.

Không cần state machine riêng cho từng ô, Timer riêng cho từng cây hoặc singleton quản lý nông trại ở bước này. Một `_process(delta)` trên `FarmLand` đủ cho khu đất cố định quy mô hiện tại.

## 3. Tách dữ liệu đất và cây

Một ô có thể chứa cây ở bất kỳ stage nào dù đất đang khô hay ướt. Không ghép thành enum kiểu `WET_STAGE_2`, `DRY_STAGE_3`.

| Dữ liệu | Nơi lưu | Ý nghĩa |
| --- | --- | --- |
| `Vector2i` | Key của dictionary ô | ID ổn định của ô trong FarmLand |
| `wet_remaining` | FarmPlotData | Số giây đất còn ướt; 0 nghĩa là khô |
| `crop` | FarmPlotData | Tham chiếu cấu hình cây; null nghĩa là ô trống |
| `growth_elapsed` | FarmPlotData | Tiến độ tính bằng giây, gồm thời gian tự lớn và bonus tưới |
| Ảnh stage, tổng thời gian, sản lượng | CropDefinition | Cấu hình dùng chung cho một loại cây |

Chỉ lưu `wet_remaining` rồi suy ra trạng thái đất để tránh hai biến `soil_state` và thời gian bị lệch nhau. Tương tự, stage được tính từ tiến độ, không lưu thêm một stage gameplay độc lập.

Resource cây là cấu hình dùng chung: không sửa `total_growth_seconds` khi tưới. Chỉ sửa `growth_elapsed` của đúng ô.

### Mapping 4 stage

Đề xuất chia ba khoảng tăng trưởng đều nhau, stage 4 bắt đầu khi trưởng thành:

| Stage trong asset | Index code | Tỷ lệ tiến độ | Cây 20 phút, chưa có bonus |
| --- | --- | --- | --- |
| `stage_01` | 0 | 0% đến dưới 33,33% | 0 đến dưới 6 phút 40 giây |
| `stage_02` | 1 | 33,33% đến dưới 66,67% | 6 phút 40 giây đến dưới 13 phút 20 giây |
| `stage_03` | 2 | 66,67% đến dưới 100% | 13 phút 20 giây đến dưới 20 phút |
| `stage_04` | 3 | 100% | Thu hoạch được |

Không dùng `floor(progress * 4)` vì công thức đó làm stage 4 xuất hiện từ 75%, trái với lựa chọn stage 4 = trưởng thành. Nếu muốn mỗi stage có thời lượng khác nhau, sau này thêm các ngưỡng vào CropDefinition.

## 4. Cấu trúc node và file

```text
world (Node2D, y_sort_enabled = true, hiện đã có)
├── FarmLand (TileMapLayer, gắn farm_land.gd)
├── Crops (Node2D, y_sort_enabled = true)
│   └── CropVisual (instance cho mỗi ô có cây)
└── Player (CharacterBody2D, player.gd)
    ├── AnimatedSprite2D
    ├── MovementComponent
    ├── AnimationComponent
    ├── PlayerInputController
    └── StateMachine
        ├── IdleState
        ├── WalkState
        └── ToolState

CropVisual.tscn:
CropVisual (Node2D)
└── Sprite2D (position = Vector2(0, -16), centered = true)
```

Đặt root cây ở giữa cạnh dưới ô đất; sprite 16 × 32 nằm phía trên root. Như vậy các ảnh stage giữ cùng gốc và root dùng làm vị trí Y-sort. Không bật Y-sort bên trong CropVisual: cả sprite là một hình cần sort theo root. Kiểm tra Player và Crops có cùng z_index để Y-sort có tác dụng; đặt FarmLand ở z_index thấp hơn, ví dụ -1.

Các file sẽ tạo khi triển khai:

```text
scripts/farming/crop_definition.gd
scripts/farming/farm_plot_data.gd
scripts/farming/farm_land.gd
scenes/crops/crop_visual.tscn
crops/definitions/crop_01.tres
```

`crops/field/crop_01/stage_01.tres` hiện có là **AtlasTexture**, không phải CropDefinition. Tạo resource cấu hình mới và kéo các AtlasTexture sẵn có vào nó.

## 5. Chuẩn bị TileSet trong editor

Trong world hiện tại, FarmLand có offset `(0, 12)` và TileSet có source 2 tham chiếu `FarmLand_Tile_Squared.png`. Hiện source này mới khai báo atlas `(0, 0)`.

1. Chọn FarmLand, mở TileSet editor.
2. Chọn atlas của `FarmLand_Tile_Squared.png`; kiểm tra vùng mỗi tile là 16 × 16.
3. Tạo tile thứ hai tại atlas `(1, 0)` nếu chưa có.
4. Quy ước `(0, 0)` là khô, `(1, 0)` là ướt; đối chiếu hình thực tế trước khi gán.
5. Gán source ID của atlas vào `soil_source_id` trong script mẫu (hiện tại là 2).
6. Chỉ các cell dùng atlas đất vuông này mới là ô trồng. Tile viền của source khác không được đưa vào dictionary gameplay.

Nếu đổi source ID trong editor, cập nhật export trên FarmLand. Hai hình phải có cùng kích thước và gốc; không cần terrain connect vì ô đất trồng cố định và tách từng ô.

## 6. Code mẫu dữ liệu

### `scripts/farming/crop_definition.gd`

```gdscript
class_name CropDefinition
extends Resource

@export var crop_id: StringName
@export var stage_textures: Array[Texture2D] = []
@export_range(1.0, 86400.0, 1.0) var total_growth_seconds: float = 1200.0
@export var harvest_item_id: StringName
@export_range(1, 99, 1) var harvest_amount: int = 1

func is_valid() -> bool:
	if crop_id == &"" or total_growth_seconds <= 0.0:
		return false
	if stage_textures.size() != 4:
		return false
	for texture in stage_textures:
		if texture == null:
			return false
	return harvest_item_id != &"" and harvest_amount > 0
```

Trong FileSystem, Create New → Resource → CropDefinition, lưu thành `crops/definitions/crop_01.tres`. Gán ID tùy quy ước của game, tổng thời gian 1.200 giây và mảng 4 texture theo đúng thứ tự `stage_01` … `stage_04`. ID sản phẩm chưa tự suy ra tên rau từ ảnh; bạn tự định nghĩa.

### `scripts/farming/farm_plot_data.gd`

```gdscript
class_name FarmPlotData
extends RefCounted

var wet_remaining: float = 0.0
var crop: CropDefinition
var growth_elapsed: float = 0.0

func is_wet() -> bool:
	return wet_remaining > 0.0

func is_mature() -> bool:
	return crop != null and growth_elapsed >= crop.total_growth_seconds

func get_stage_index() -> int:
	if crop == null:
		return -1
	if is_mature():
		return 3
	var progress := growth_elapsed / crop.total_growth_seconds
	return mini(int(floor(progress * 3.0)), 2)
```

## 7. Code mẫu quản lý FarmLand

Gắn script sau vào TileMapLayer FarmLand. Tạo CropVisual.tscn theo cây node phía trên, kéo scene đó vào `crop_scene` và kéo node Crops vào `crops_root` trong Inspector.

```gdscript
class_name FarmLand
extends TileMapLayer

@export var crop_scene: PackedScene
@export var crops_root: Node2D
@export var soil_source_id: int = 2
@export var dry_atlas: Vector2i = Vector2i(0, 0)
@export var wet_atlas: Vector2i = Vector2i(1, 0)
@export_range(0.1, 3600.0, 0.1) var wet_duration: float = 300.0
@export_range(0.0, 1.0, 0.01) var watering_bonus_ratio: float = 0.05

var plots: Dictionary[Vector2i, FarmPlotData] = {}
var crop_visuals: Dictionary[Vector2i, Node2D] = {}

func _ready() -> void:
	assert(crop_scene != null and crops_root != null)
	# Chụp danh sách ô hợp lệ một lần; không tạo ô mới khi tưới.
	for cell in get_used_cells_by_id(soil_source_id):
		var atlas := get_cell_atlas_coords(cell)
		if atlas != dry_atlas and atlas != wet_atlas:
			continue
		plots[cell] = FarmPlotData.new()
		# Bản đầu bắt đầu với đất khô. Save/load sẽ khôi phục sau bước này.
		_refresh_soil(cell)

func _process(delta: float) -> void:
	for cell in plots:
		var plot: FarmPlotData = plots[cell]
		var was_wet := plot.is_wet()
		var previous_stage := plot.get_stage_index()
		plot.wet_remaining = maxf(0.0, plot.wet_remaining - delta)
		if plot.crop != null and not plot.is_mature():
			plot.growth_elapsed = minf(
				plot.growth_elapsed + delta,
				plot.crop.total_growth_seconds
			)
		if was_wet != plot.is_wet():
			_refresh_soil(cell)
		if previous_stage != plot.get_stage_index():
			_refresh_crop(cell)

func cell_from_world(world_position: Vector2) -> Vector2i:
	return local_to_map(to_local(world_position))

func plant(cell: Vector2i, definition: CropDefinition) -> bool:
	if not plots.has(cell) or definition == null:
		return false
	if not definition.is_valid():
		return false
	var plot: FarmPlotData = plots[cell]
	if plot.crop != null:
		return false
	plot.crop = definition
	plot.growth_elapsed = 0.0
	# Không cộng bonus chỉ vì đất đã ướt trước lúc trồng.
	_refresh_crop(cell)
	return true

func water(cell: Vector2i) -> bool:
	if not plots.has(cell):
		return false
	var plot: FarmPlotData = plots[cell]
	if plot.is_wet():
		return false
	plot.wet_remaining = wet_duration
	if plot.crop != null and not plot.is_mature():
		plot.growth_elapsed = minf(
			plot.growth_elapsed + plot.crop.total_growth_seconds * watering_bonus_ratio,
			plot.crop.total_growth_seconds
		)
		_refresh_crop(cell)
	_refresh_soil(cell)
	return true

func harvest(cell: Vector2i) -> Dictionary:
	if not plots.has(cell):
		return {}
	var plot: FarmPlotData = plots[cell]
	if not plot.is_mature():
		return {}
	var result := {
		"item_id": plot.crop.harvest_item_id,
		"amount": plot.crop.harvest_amount,
	}
	plot.crop = null
	plot.growth_elapsed = 0.0
	_refresh_crop(cell)
	return result

func _refresh_soil(cell: Vector2i) -> void:
	var plot: FarmPlotData = plots[cell]
	set_cell(cell, soil_source_id, wet_atlas if plot.is_wet() else dry_atlas)

func _refresh_crop(cell: Vector2i) -> void:
	var plot: FarmPlotData = plots[cell]
	if plot.crop == null:
		if crop_visuals.has(cell):
			crop_visuals[cell].queue_free()
			crop_visuals.erase(cell)
		return
	if not crop_visuals.has(cell):
		var visual := crop_scene.instantiate() as Node2D
		assert(visual != null)
		crops_root.add_child(visual)
		var bottom_center := map_to_local(cell) + Vector2(0, tile_set.tile_size.y * 0.5)
		visual.global_position = to_global(bottom_center)
		crop_visuals[cell] = visual
	var sprite := crop_visuals[cell].get_node("Sprite2D") as Sprite2D
	sprite.texture = plot.crop.stage_textures[plot.get_stage_index()]
```

Đổi hình chỉ khi đất đổi trạng thái, stage đổi hoặc có thao tác; không gọi set_cell cho mọi ô mỗi frame. Dictionary chỉ có những ô được vẽ từ đầu. Khi thu hoạch, ô vẫn nằm trong dictionary và tile đất vẫn tồn tại.

Code dùng thời gian `delta` nên không phụ thuộc FPS. Đặt FarmLand ở Process Mode = Inherit và pause bằng `get_tree().paused = true` để tiến độ cũng dừng. Nếu tạm chuyển sang scene khác và hủy world, cần lưu snapshot trước; code mẫu không tự lưu.

## 8. Nối Player và ToolState

Luồng trách nhiệm:

```text
PlayerInputController đọc phím
    → Player.use_tool(action) kiểm tra state và chốt ô/cây được chọn
    → ToolState khóa di chuyển, phát animation
    → frame tác động phát effect_requested đúng một lần
    → Player gọi FarmLand.water / plant / harvest
    → animation kết thúc, ToolState trở về Idle / Walk
```

Input controller hiện có có thể giữ nguyên. Không để controller truy cập FarmLand hoặc node ToolState. Tên action animation vẫn là `"tool"` và `"water"`.

### Thay nội dung `scripts/states/tool_state.gd`

```gdscript
class_name ToolState
extends State

signal effect_requested(action: String)

@export var action: String = "tool"
# Index bắt đầu từ 0; gán theo frame tiếp xúc thực tế của asset.
@export var impact_frame: int = 3
var _effect_applied: bool = false

func enter() -> void:
	_effect_applied = false
	movement_component.stop()
	animation_component.action_finished.connect(_on_action_finished)
	animation_component.animated_sprite.frame_changed.connect(_on_frame_changed)
	animation_component.play(action, true)
	_on_frame_changed()

func physics_update(_delta: float) -> void:
	movement_component.stop()

func _on_frame_changed() -> void:
	if state_machine.current_state != self or _effect_applied:
		return
	if animation_component.animated_sprite.frame < impact_frame:
		return
	_effect_applied = true
	effect_requested.emit(action)

func _on_action_finished(finished_action: String) -> void:
	if state_machine.current_state != self or finished_action != action:
		return
	if actor.has_move_intent():
		state_machine.change_state(&"walk")
	else:
		state_machine.change_to_default()

func exit() -> void:
	animation_component.action_finished.disconnect(_on_action_finished)
	animation_component.animated_sprite.frame_changed.disconnect(_on_frame_changed)
```

Animation tool và water hiện có 6 frame, không loop. Index 3 chỉ là ví dụ: chạy thử và chọn frame đúng thời điểm công cụ tiếp xúc. Nếu hai animation cần thời điểm khác nhau, thay export này bằng hai cấu hình tương ứng.

Đảm bảo đầy đủ animation theo hướng trước khi dùng code: AnimationComponent hiện fallback sang idle khi thiếu animation; idle có loop nên ToolState sẽ không nhận kết thúc. `"tool"` và `"water"` hiện có các hướng down/up/right; left được flip từ right.

### Thay nội dung `scripts/player.gd` cho bản thử cơ chế

```gdscript
class_name Player
extends CharacterBase

@export var farm_land: FarmLand
@export var selected_crop: CropDefinition
@export var tool_reach: float = 16.0

@onready var tool_state: ToolState = $StateMachine/ToolState

var _target_cell: Vector2i
var _pending_crop: CropDefinition

func _ready() -> void:
	super._ready()
	tool_state.effect_requested.connect(_on_tool_effect_requested)

func use_tool(action: String) -> void:
	if farm_land == null or (action != "tool" and action != "water"):
		return
	if not (state_machine.current_state is IdleState or state_machine.current_state is WalkState):
		return
	var target_position := global_position + animation_component.facing_vector * tool_reach
	_target_cell = farm_land.cell_from_world(target_position)
	if not farm_land.plots.has(_target_cell):
		return
	_pending_crop = selected_crop
	tool_state.action = action
	state_machine.change_state(&"tool")

func _on_tool_effect_requested(action: String) -> void:
	if action == "water":
		farm_land.water(_target_cell)
		return
	# Quy ước prototype: Space thu hoạch cây chín, hoặc trồng ở ô trống.
	var plot: FarmPlotData = farm_land.plots[_target_cell]
	if plot.is_mature():
		var result := farm_land.harvest(_target_cell)
		print("Thu hoạch: ", result)
	else:
		farm_land.plant(_target_cell, _pending_crop)
```

Trong scene world, chọn instance Player, kéo FarmLand vào export `farm_land`, và kéo resource CropDefinition vào `selected_crop`. Nếu cần, bật Editable Children để cấu hình impact_frame của ToolState; không gán farm_land vào scene player độc lập vì scene đó không chứa world.

Code chốt mục tiêu và loại cây trước khi chạy animation; không tính lại mục tiêu theo input ở frame tác động. `tool_reach = 16` phù hợp lưới 16 × 16 nhưng vị trí player có thể lệch tâm ô, vì vậy cần kiểm tra cả bốn hướng bằng highlight ô khi thử. Hàm chuyển world → local → cell xử lý offset `(0, 12)` của FarmLand.

Quy ước Space trồng/thu hoạch là cách thử cơ chế, chưa phải hệ thống chọn công cụ hoàn chỉnh. Nếu ô đã có cây chưa chín, plant trả false và không thay cây. Animation có thể vẫn chạy khi tưới ô ướt, nhưng không tạo bonus.

### Nối inventory sau prototype

Code mẫu chưa có inventory: không trừ hạt và kết quả thu hoạch chỉ được print. Khi nối inventory:

- Trồng: kiểm tra hạt trước khi bắt đầu; tại frame tác động kiểm tra lại và chỉ trừ hạt nếu plant thành công. Không trừ ở cả hai thời điểm.
- Thu hoạch: kiểm tra sức chứa túi trước khi xóa cây. Hàm harvest mẫu xóa cây ngay; không gọi hàm này rồi mới phát hiện túi đầy. Thêm thao tác kiểm tra/đặt trước chỗ trong inventory, hoặc tách kiểm tra và commit.
- Nếu bị ngắt animation trước frame tác động, không thay đổi đất/cây. Nếu đã qua frame tác động, tác động giữ nguyên và không được lặp lại.

Không cần ToolComponent ngay. Khi có nhiều công cụ, chuyển phần chọn và thực thi công cụ từ Player sang component, giữ giao diện `Player.use_tool()` cho controller.

## 9. Lưu và tải

Mỗi ô lưu snapshot, ví dụ JSON:

```json
{
  "x": 10,
  "y": 6,
  "wet_remaining": 214.5,
  "crop_id": "crop_01",
  "growth_elapsed": 430.0
}
```

Ô trống dùng crop_id rỗng và growth_elapsed bằng 0. Không serialize Node, Sprite hoặc Resource trực tiếp. Nếu nhiều map, thêm map_id vì tọa độ chỉ duy nhất trong một FarmLand.

Trình tự load:

1. FarmLand khởi tạo danh sách ô hợp lệ từ map.
2. Đọc snapshot, chỉ nhận tọa độ có trong plots.
3. Tra crop_id qua danh mục `crop_id → CropDefinition`, kiểm tra resource hợp lệ.
4. Clamp wet_remaining vào `[0, wet_duration]`, growth_elapsed vào `[0, total_growth_seconds]`. ID không tồn tại thì giữ ô trống và báo cảnh báo.
5. Gọi `_refresh_soil()` và `_refresh_crop()` để dựng lại hình ảnh.

Không cộng thời gian đã thoát game. Nếu sau này muốn tăng trưởng offline, cần thống nhất riêng cách tính bonus và chu kỳ khô trong khoảng đó; không chỉ đổi tất cả sang timestamp mà bỏ qua quy tắc gameplay.

## 10. Thứ tự triển khai và kiểm tra

1. Chuẩn bị hai tile khô/ướt và danh sách ô cố định.
2. Tạo hai script dữ liệu và một resource cây với đủ 4 texture.
3. Tạo CropVisual, gắn FarmLand và gán export trong Inspector.
4. Thử trực tiếp plant/water/harvest, sau đó nối frame tác động với Player.
5. Thử pause, lặp dùng công cụ, chuyển hướng và thu hoạch.
6. Nối inventory rồi save/load.

Dùng `wet_duration = 5` giây và `total_growth_seconds = 30` giây khi thử, thay vì chờ 5 và 20 phút. Giữ bonus 0.05 để mỗi lần tưới hợp lệ cộng 1.5 giây. Sau khi kiểm tra, trả thông số về giá trị gameplay.

| Tình huống | Kết quả cần có |
| --- | --- |
| Trồng ô trống | Một cây stage 1, tiến độ 0 |
| Trồng ô đã có cây | Không thay cây, không reset tiến độ |
| Tưới ô khô có cây | Đất ướt, cộng đúng 5% tổng thời gian |
| Tưới lại ô ướt | Không cộng thêm, không reset đồng hồ khô |
| Tưới ô trống rồi trồng | Cây bắt đầu tiến độ 0 dù đất còn ướt |
| Hết thời gian ướt | Tile khô; tiến độ cây vẫn giữ và tiếp tục tăng |
| Qua các ngưỡng 1/3, 2/3, 100% | Đổi lần lượt stage 2, 3, 4 |
| Bonus vượt thời gian còn lại | Clamp về trưởng thành, không vượt tổng |
| Nhấn giữ phím hoặc bấm liên tục khi đang ToolState | Mỗi lượt hành động có tối đa một tác động |
| Mục tiêu ngoài khu đất | Không tạo thêm ô hoặc cây |
| Thu hoạch cây chưa chín | Không xóa cây |
| Thu hoạch cây chín | Xóa cây, giữ đất, trả item và sản lượng |
| Pause | Đất không khô thêm, cây không lớn thêm |
| Load lại | Khôi phục đúng thời gian còn lại, stage được tính lại |
| Player đứng trước/sau cây ở bốn hướng | Vị trí gốc, ô mục tiêu và Y-sort đúng |

## 11. Tài liệu liên quan

- [Resource ảnh cây đang có](crop_resources.md): 22 bộ hoa màu, mỗi bộ có 4 stage AtlasTexture khung 16 × 32.
- [Godot TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html): lấy danh sách cell, chuyển tọa độ và đổi tile.
- [Godot AnimatedSprite2D](https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html): signal frame_changed và animation_finished; animation loop không phát animation_finished.
- [Godot Node](https://docs.godotengine.org/en/stable/classes/class_node.html): vòng cập nhật, delta và Process Mode khi pause.

Code mẫu được đối chiếu cấu trúc repository và API tài liệu. Chưa được chạy trong Godot ở bước tạo tài liệu này; cần thực hiện các ca kiểm tra trên khi triển khai.
