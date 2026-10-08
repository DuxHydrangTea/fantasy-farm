# Thiết kế trồng trọt: mỗi ô đất là một scene riêng

Tài liệu dành cho cấu trúc Godot hiện tại của `fantasy-farm`. Bản thiết kế này chọn **mỗi ô đất là một instance `FarmPlot.tscn`**, tự quản lý trạng thái và hình ảnh của mình. Đây là hướng dẫn và code mẫu; chưa triển khai cơ chế trồng trọt vào game. Các đoạn ghi “thay nội dung” là thay toàn bộ file khi triển khai, tránh nối thêm hàm trùng tên.

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

## 2. Phân chia trách nhiệm

Để hiểu cách tưới một ô, chỉ cần đọc `FarmPlot.water()`. Để hiểu cây lớn thế nào, đọc `FarmPlot._process()`. Hình đất và hình cây cũng nằm ngay trong scene của ô đó.

| Thành phần | Trách nhiệm |
| --- | --- |
| `FarmPlot` — scene một ô đất | Giữ thời gian ướt, cây đang trồng, tiến độ; xử lý trồng/tưới/thu hoạch; đổi hình |
| `CropDefinition` — Resource | Cấu hình dùng chung cho một loại cây: 4 texture, tổng thời gian và sản lượng |
| `FarmLand` — Node2D chứa các ô | Lập danh sách scene ô có sẵn, tìm ô chứa điểm tương tác trước mặt Player |
| `Player` | Chọn và chốt ô mục tiêu, loại cây; gọi thao tác ở frame tác động |
| `ToolState` | Khóa di chuyển, chạy animation và phát tín hiệu tác động đúng một lần |

`FarmLand` chỉ giữ một mảng tham chiếu tới các FarmPlot con. Không cần cell, atlas, dictionary tọa độ, `FarmPlotData` hoặc một vòng lặp trên FarmLand để cập nhật mọi cây. Mỗi ô là object thật có thể chọn, di chuyển và cấu hình trong editor.

Bản đầu dùng một `_process(delta)` trong mỗi ô để đếm thời gian. Ô khô và trống, hoặc khô và có cây trưởng thành, tự tắt cập nhật. Chưa cần thêm Timer, state machine hay manager toàn cục. Nếu sau này cần cây có hành vi phức tạp, có thể tách cây thành scene con trong `FarmPlot`.

Đánh đổi của hướng này là nhiều node hơn TileMap và phải chuyển các tile ô trồng thành scene. Với mục tiêu ô cố định và dễ theo dõi trong editor, chọn cách này trước. Khi mở rộng bản đồ, đo hiệu năng thực tế rồi mới quyết định gom xử lý thời gian hoặc tải ô theo khu vực.

## 3. Dữ liệu của một ô

Một ô có thể chứa cây ở bất kỳ stage nào dù đất đang khô hay ướt. Không ghép thành enum kiểu `WET_STAGE_2`, `DRY_STAGE_3`.

| Dữ liệu | Nơi lưu | Ý nghĩa |
| --- | --- | --- |
| `plot_id: StringName` | Export của FarmPlot | ID ổn định, do bạn đặt cho từng ô; dùng save |
| `wet_remaining` | Biến trong FarmPlot | Số giây đất còn ướt; 0 nghĩa là khô |
| `crop` | Biến trong FarmPlot | CropDefinition đang trồng; null nghĩa là ô trống |
| `growth_elapsed` | Biến trong FarmPlot | Tiến độ bằng giây, gồm tự lớn và bonus tưới |
| Texture, tổng thời gian, sản lượng | CropDefinition | Cấu hình dùng chung, không sửa lúc tưới |

Trạng thái đất được suy ra từ `wet_remaining`; stage được suy ra từ `growth_elapsed`. Sprite chỉ hiển thị dữ liệu, không dùng hình ảnh để suy luận gameplay. Mỗi instance có biến thời gian riêng; chỉ resource cấu hình được dùng chung.

### Mapping 4 stage

Đề xuất chia ba khoảng tăng trưởng đều nhau, stage 4 bắt đầu khi trưởng thành:

| Stage trong asset | Index code | Tỷ lệ tiến độ | Cây 20 phút, chưa có bonus |
| --- | --- | --- | --- |
| `stage_01` | 0 | 0% đến dưới 33,33% | 0 đến dưới 6 phút 40 giây |
| `stage_02` | 1 | 33,33% đến dưới 66,67% | 6 phút 40 giây đến dưới 13 phút 20 giây |
| `stage_03` | 2 | 66,67% đến dưới 100% | 13 phút 20 giây đến dưới 20 phút |
| `stage_04` | 3 | 100% | Thu hoạch được |

Không dùng `floor(progress * 4)` vì công thức đó làm stage 4 xuất hiện từ 75%, trái với lựa chọn stage 4 = trưởng thành. Nếu muốn mỗi stage có thời lượng khác nhau, sau này thêm các ngưỡng vào CropDefinition.

## 4. Cấu trúc scene và file

```text
world (Node2D, y_sort_enabled = true)
├── FarmGround (TileMapLayer: nền/viền đất trang trí)
├── FarmLand (Node2D, farm_land.gd, y_sort_enabled = true)
│   ├── Plot_01 (instance FarmPlot.tscn, plot_id = "plot_01")
│   ├── Plot_02 (instance FarmPlot.tscn, plot_id = "plot_02")
│   └── ... các ô cố định
└── Player (CharacterBody2D, player.gd)
    ├── AnimatedSprite2D
    ├── MovementComponent
    ├── AnimationComponent
    ├── PlayerInputController
    └── StateMachine
        ├── IdleState
        ├── WalkState
        └── ToolState

FarmPlot.tscn:
FarmPlot (Node2D, farm_plot.gd, y_sort_enabled = false, z_index = 0)
├── SoilSprite (Sprite2D, position = (0, -8), z_index = -1)
└── CropSprite (Sprite2D, position = (0, -16), z_index = 0)
```

Root ô nằm giữa cạnh dưới ô 16 × 16. SoilSprite 16 × 16 và CropSprite 16 × 32 đều centered. Khi thu hoạch, chỉ ẩn CropSprite; scene ô và SoilSprite vẫn tồn tại.

Bật Y-sort trên `world` và `FarmLand` để các ô tham gia cùng nhóm sort với Player. Tắt Y-sort trên từng FarmPlot để cây được sort theo gốc ô. FarmLand, FarmPlot và Player dùng z_index = 0; SoilSprite và nền đất dùng z_index = -1, nền cỏ có thể dùng -2. Không hạ z_index của cả FarmPlot vì cây sẽ luôn nằm dưới Player. Cách sort theo cha/con và z_index được mô tả trong [Godot CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-property-y-sort-enabled).

Các file sẽ tạo khi triển khai:

```text
scripts/farming/crop_definition.gd
scripts/farming/farm_plot.gd
scripts/farming/farm_land.gd
scenes/farming/farm_plot.tscn
crops/definitions/wheat.tres
```

Không tạo `farm_plot_data.gd` và `crop_visual.tscn` của thiết kế trước. Chỉ sửa Player và ToolState sau khi thử được một ô độc lập.

## 5. Chuẩn bị trong editor và chuyển map hiện tại

Trong `scenes/world.tscn` hiện có một TileMapLayer tên `FarmLand`, offset `(0, 12)`. Source 2 dùng `FarmLand_Tile_Squared.png`; source này hiện mới khai báo atlas `(0, 0)`. Đây là phần cần chuyển khi triển khai, không đổi ngay chỉ vì cập nhật tài liệu.

1. Tạo scene FarmPlot với hai Sprite2D như trên; gắn `farm_plot.gd` ở mục 7.
2. Tạo hai AtlasTexture 16 × 16 cho đất khô/ướt từ asset phù hợp. Sheet đất vuông hiện có hai vùng ở `(0, 0, 16, 16)` và `(16, 0, 16, 16)`; đối chiếu hình để gán đúng `dry_texture`/`wet_texture`. Nếu hình ướt mong muốn ở sheet khác, dùng sheet đó. Không cần khai báo thêm tile trong TileSet để dùng Sprite2D.
3. Gán hai texture vào export trên scene gốc. Gán texture khô cho SoilSprite để nhìn thấy ô trong editor; đặt CropSprite.visible = false.
4. Đổi tên TileMapLayer FarmLand hiện tại thành `FarmGround`; giữ nền/viền trang trí và offset cũ.
5. Tạo Node2D mới tên `FarmLand`, position `(0, 12)`, gắn `farm_land.gd`. Thêm các instance FarmPlot làm **con trực tiếp**.
6. Đặt các instance vào vị trí mong muốn bằng Move trong editor, gán `plot_id` riêng như `plot_01`, `plot_02`. Xóa đúng tile ô trồng cũ khỏi FarmGround để không vẽ đất hai lần. Không chuyển tile viền thành ô trồng.
7. Đặt các export Y-sort/z_index như mục 4. Bật snap 16 pixel nếu muốn xếp ô đều; snap chỉ giúp bố trí trong editor, code không phụ thuộc lưới.

Root của mỗi ô là giữa cạnh dưới hình đất. Ví dụ muốn hình đất phủ vùng local x = 160..176, y = 96..112 thì đặt root tại `(168, 112)`:

```text
FarmPlot local position (168, 112)
FarmLand position (0, 12) → world position (168, 124)
```

Vị trí node trong editor là vị trí runtime; FarmLand không tự đặt lại position. Bạn có thể xếp các ô bất kỳ, không bắt buộc tạo lưới. Mỗi ô dùng `plot_size = (16, 16)` để xác định vùng nhận tương tác; tránh đặt các vùng này chồng nhau. Bản đầu giữ scale `(1, 1)`, rotation 0 để hình pixel không biến dạng.

Nếu nhiều ô cũ, có thể viết script chuyển đổi chạy một lần trong editor, nhưng không cần cho bản đầu. Bố trí instance thủ công trước để kiểm tra scene. Gameplay không quét TileMap và không cần TileSet cho các ô đất này.

## 6. Cấu hình loại cây

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

Trong FileSystem, Create New → Resource → CropDefinition, lưu thành `crops/definitions/wheat.tres`. Gán ID tùy quy ước của game, tổng thời gian 1.200 giây và mảng 4 texture theo đúng thứ tự `stage_01` … `stage_04`. Resource ảnh trong `crops/field` đã dùng tên loại cây từ catalog; ID sản phẩm gameplay do bạn định nghĩa.

`crops/field/wheat/stage_01.tres` hiện có là **AtlasTexture**, không phải CropDefinition. Kéo các resource ảnh có sẵn vào cấu hình cây mới; không sửa resource cấu hình khi tưới.

## 7. Code mẫu cho một ô: `scripts/farming/farm_plot.gd`

Gắn script này vào root FarmPlot. Một ô tự kiểm tra điều kiện, thay đổi dữ liệu và cập nhật Sprite của chính mình.

```gdscript
class_name FarmPlot
extends Node2D

@export var plot_id: StringName
@export var plot_size: Vector2 = Vector2(16, 16)
@export var dry_texture: Texture2D
@export var wet_texture: Texture2D
@export_range(0.1, 3600.0, 0.1) var wet_duration: float = 300.0
@export_range(0.0, 1.0, 0.01) var watering_bonus_ratio: float = 0.05

@onready var soil_sprite: Sprite2D = $SoilSprite
@onready var crop_sprite: Sprite2D = $CropSprite

var wet_remaining: float = 0.0
var crop: CropDefinition
var growth_elapsed: float = 0.0

func _ready() -> void:
	assert(dry_texture != null and wet_texture != null)
	assert(plot_size.x > 0.0 and plot_size.y > 0.0)
	refresh_visuals()
	_update_processing()

func contains_world_point(world_position: Vector2) -> bool:
	# Root ở giữa cạnh dưới, nên vùng đất nằm phía trên root.
	var bounds := Rect2(Vector2(-plot_size.x * 0.5, -plot_size.y), plot_size)
	return bounds.has_point(to_local(world_position))

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

func plant(definition: CropDefinition) -> bool:
	if crop != null or definition == null:
		return false
	if not definition.is_valid():
		return false
	crop = definition
	growth_elapsed = 0.0
	_refresh_crop()
	_update_processing()
	return true

func water() -> bool:
	if is_wet():
		return false
	wet_remaining = wet_duration
	if crop != null and not is_mature():
		growth_elapsed = minf(
			growth_elapsed + crop.total_growth_seconds * watering_bonus_ratio,
			crop.total_growth_seconds
		)
	refresh_visuals()
	_update_processing()
	return true

func harvest() -> Dictionary:
	if not is_mature():
		return {}
	var result := {
		"item_id": crop.harvest_item_id,
		"amount": crop.harvest_amount,
	}
	crop = null
	growth_elapsed = 0.0
	_refresh_crop()
	_update_processing()
	return result

func _process(delta: float) -> void:
	var was_wet := is_wet()
	var previous_stage := get_stage_index()
	wet_remaining = maxf(0.0, wet_remaining - delta)
	if crop != null and not is_mature():
		growth_elapsed = minf(growth_elapsed + delta, crop.total_growth_seconds)
	if was_wet != is_wet():
		_refresh_soil()
	if previous_stage != get_stage_index():
		_refresh_crop()
	_update_processing()

func refresh_visuals() -> void:
	_refresh_soil()
	_refresh_crop()

func _refresh_soil() -> void:
	soil_sprite.texture = wet_texture if is_wet() else dry_texture

func _refresh_crop() -> void:
	crop_sprite.visible = crop != null
	if crop == null:
		crop_sprite.texture = null
		return
	crop_sprite.texture = crop.stage_textures[get_stage_index()]

func _update_processing() -> void:
	set_process(is_wet() or (crop != null and not is_mature()))
```

API của một ô là `plot.water()`, `plot.plant(definition)`, `plot.harvest()`. Trạng thái runtime chỉ được thay qua các thao tác này hoặc bước load; không để Player tự gán `crop` hay thời gian.

`_process` chỉ đổi hình khi đất khô hoặc cây đổi stage. Trồng, tưới và thu hoạch cập nhật hình ngay, rồi bật/tắt xử lý thời gian theo trạng thái mới. Ô trống vẫn nhận tưới và tự khô; cây trưởng thành vẫn giữ thời gian đất ướt nếu còn.

Đặt world ở Process Mode = Pausable; FarmLand và FarmPlot ở Inherit. Khi pause bằng `get_tree().paused = true`, tiến độ dừng. Chỉ ẩn world không dừng xử lý; nếu giữ world trong cây node khi chuyển màn, cần đặt Process Mode = Disabled trong lúc world không hoạt động. Nếu hủy world, lưu snapshot trước.

## 8. Code mẫu cho khu đất: `scripts/farming/farm_land.gd`

FarmLand đăng ký các scene ô đã có, không tạo ô mới khi dùng công cụ và không giữ dữ liệu tăng trưởng.

```gdscript
class_name FarmLand
extends Node2D

var _plots: Array[FarmPlot] = []

func _ready() -> void:
	for child in get_children():
		if not child is FarmPlot:
			continue
		var plot := child as FarmPlot
		assert(plot.plot_id != &"", "FarmLand: ô chưa có plot_id")
		assert(get_plot_by_id(plot.plot_id) == null, "FarmLand: hai ô trùng plot_id")
		_plots.append(plot)

func get_plot_at_world(world_position: Vector2) -> FarmPlot:
	for plot in _plots:
		if plot.contains_world_point(world_position):
			return plot
	return null

func get_plot_by_id(plot_id: StringName) -> FarmPlot:
	for plot in _plots:
		if plot.plot_id == plot_id:
			return plot
	return null
```

`get_plot_at_world()` hỏi từng object: điểm mục tiêu có nằm trong vùng đất của bạn không? Ô tự chuyển điểm world về local rồi kiểm tra Rect2. Offset của FarmLand và vị trí riêng của ô được xử lý bởi `to_local()`. Điểm không nằm trong scene ô nào trả null, dù bên dưới có tile trang trí. Chỉ duyệt khi dùng công cụ, không duyệt để tìm ô mỗi frame.

Chưa cần Area2D/CollisionShape2D: vùng chữ nhật đủ cho ô đất 16 × 16 và không cần cấu hình collision layer. Nếu sau này dùng hệ thống tương tác vật lý chung, có thể thay cách tìm mục tiêu bằng Area2D hoặc truy vấn physics; API `water()/plant()/harvest()` của ô vẫn giữ nguyên. Vùng kiểm tra phải khớp hình SoilSprite; nếu đổi kích thước hình, cập nhật plot_size.

Danh sách được lập một lần vì các ô cố định. Khi triển khai thêm tạo/xóa ô runtime, bổ sung đăng ký/hủy đăng ký. Player chỉ dùng `get_plot_at_world()`, không đọc `_plots`.

## 9. Nối Player và ToolState

```text
PlayerInputController đọc phím
    → Player.use_tool(action) tìm và chốt FarmPlot mục tiêu + loại cây
    → ToolState khóa di chuyển, phát animation
    → frame tác động phát effect_requested đúng một lần
    → Player gọi thao tác trên FarmPlot đã chốt
    → FarmPlot đổi dữ liệu và hình của chính mình
    → animation kết thúc, ToolState trở về Idle / Walk
```

Giữ giao diện `Player.use_tool()` mà input controller hiện đang gọi. Controller không cần biết FarmLand hoặc FarmPlot. Tên action animation vẫn là `"tool"` và `"water"`.

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
	animation_component.play(action, true)
	animation_component.animated_sprite.frame_changed.connect(_on_frame_changed)
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

Kết nối `frame_changed` sau khi gọi `play()` để bỏ qua thay đổi frame khi reset animation cũ, rồi kiểm tra frame ban đầu bằng `_on_frame_changed()`.

### Thay nội dung `scripts/player.gd` cho bản thử cơ chế

```gdscript
class_name Player
extends CharacterBase

@export var farm_land: FarmLand
@export var selected_crop: CropDefinition
@export var tool_reach: float = 16.0

@onready var tool_state: ToolState = $StateMachine/ToolState

var _target_plot: FarmPlot
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
	_target_plot = farm_land.get_plot_at_world(target_position)
	if _target_plot == null:
		return
	_pending_crop = selected_crop
	tool_state.action = action
	state_machine.change_state(&"tool")

func _on_tool_effect_requested(action: String) -> void:
	if not is_instance_valid(_target_plot):
		return
	if action == "water":
		_target_plot.water()
		return
	# Prototype: Space thu hoạch cây chín, hoặc trồng ở ô trống.
	if _target_plot.is_mature():
		var result := _target_plot.harvest()
		print("Thu hoạch: ", result)
	else:
		_target_plot.plant(_pending_crop)
```

Trong world, chọn instance Player, kéo **Node2D FarmLand mới** vào export `farm_land`, và kéo CropDefinition vào `selected_crop`. Không gán vào scene player độc lập vì scene đó không chứa world. Nếu cần, bật Editable Children để cấu hình impact_frame của ToolState.

Mục tiêu là tham chiếu tới đúng scene ô, được chốt trước animation. Đổi hướng hoặc chọn loại cây khác giữa animation không đổi mục tiêu đã chốt. Kiểm tra `is_instance_valid()` trước frame tác động để xử lý trường hợp ô đã bị hủy.

`tool_reach = 16` là thông số thử theo kích thước ô; vị trí Player có thể lệch tâm ô. Kiểm tra bốn hướng với highlight ô mục tiêu trước khi chốt khoảng cách. Space trồng/thu hoạch là quy ước prototype, chưa phải hệ thống chọn công cụ hoàn chỉnh. Trồng vào ô có cây chưa chín trả false; tưới ô ướt có thể vẫn chạy animation nhưng không cộng bonus.

### Nối inventory sau prototype

Code mẫu chưa có inventory: không trừ hạt và kết quả thu hoạch chỉ được print. Khi nối inventory:

- Trồng: kiểm tra hạt trước khi bắt đầu; tại frame tác động kiểm tra lại và chỉ trừ hạt nếu plant thành công. Không trừ ở cả hai thời điểm.
- Thu hoạch: kiểm tra sức chứa túi trước khi xóa cây. Hàm harvest mẫu xóa cây ngay; không gọi hàm này rồi mới phát hiện túi đầy. Thêm thao tác kiểm tra/đặt trước chỗ trong inventory, hoặc tách kiểm tra và commit.
- Nếu bị ngắt animation trước frame tác động, không thay đổi đất/cây. Nếu đã qua frame tác động, tác động giữ nguyên và không được lặp lại.

Không cần ToolComponent ngay. Khi có nhiều công cụ, chuyển phần chọn và thực thi công cụ từ Player sang component, giữ giao diện `Player.use_tool()` cho controller.

## 10. Lưu và tải

Lưu dữ liệu của từng FarmPlot bằng snapshot, ví dụ JSON:

```json
{
  "plot_id": "plot_01",
  "wet_remaining": 214.5,
  "crop_id": "wheat",
  "growth_elapsed": 430.0
}
```

Ô trống dùng crop_id rỗng và growth_elapsed bằng 0. Không serialize Node, Sprite hoặc Resource trực tiếp. Nếu nhiều map, thêm map_id vì plot_id chỉ duy nhất trong một FarmLand. ID do bạn gán trong Inspector phải giữ ổn định; đổi tên hoặc di chuyển node không làm đổi ID và không làm mất save.

Trình tự load khi triển khai:

1. World và các scene FarmPlot vào cây node; chờ FarmLand hoàn tất `_ready()` và đăng ký ô.
2. Đọc snapshot, dùng `FarmLand.get_plot_by_id(StringName(snapshot["plot_id"]))`. Bỏ qua ID không có scene, không tạo thêm ô từ save.
3. Trong một hàm `FarmPlot.restore_snapshot()` sẽ bổ sung lúc làm save/load, tra crop_id qua danh mục CropDefinition, kiểm tra resource hợp lệ. ID không tồn tại thì giữ ô trống và báo cảnh báo.
4. Clamp wet_remaining vào `[0, wet_duration]`, growth_elapsed vào `[0, total_growth_seconds]`; ô trống có tiến độ 0.
5. Trong hàm restore của ô, gọi `refresh_visuals()` và `_update_processing()`. Bật lại xử lý là cần thiết vì ô khô/trống đã tắt `_process` ở `_ready()`.

Code mẫu trên chưa có bộ ghi/đọc save. Khi bổ sung, để bước khôi phục trạng thái bên trong FarmPlot; FarmLand chỉ định tuyến snapshot đến đúng ô. Không cộng thời gian đã thoát game. Nếu sau này muốn tăng trưởng offline, cần thống nhất riêng cách tính bonus và chu kỳ khô.

## 11. Thứ tự triển khai và kiểm tra

1. Tạo CropDefinition và một resource cây với đủ 4 texture.
2. Tạo FarmPlot.tscn với hai sprite và hai texture đất; thử một ô độc lập.
3. Thử `plant()`, `water()`, `harvest()` trực tiếp trước khi nối Player.
4. Bố trí các instance dưới Node2D FarmLand; kiểm tra plot_id, vùng tương tác, offset và Y-sort.
5. Nối ToolState và Player; thử pause, lặp dùng công cụ và bốn hướng.
6. Nối inventory rồi save/load.

Dùng wet_duration = 5 giây và total_growth_seconds = 30 giây khi thử, thay vì chờ 5 và 20 phút. Giữ bonus 0.05 để mỗi lần tưới hợp lệ cộng 1.5 giây. Sau khi kiểm tra, trả thông số về giá trị gameplay.

| Tình huống | Kết quả cần có |
| --- | --- |
| Trồng ô trống | Một cây stage 1, tiến độ 0 |
| Trồng ô đã có cây | Không thay cây, không reset tiến độ |
| Tưới ô khô có cây | Đất ướt, cộng đúng 5% tổng thời gian |
| Tưới lại ô ướt | Không cộng thêm, không reset đồng hồ khô |
| Tưới ô trống rồi trồng | Cây bắt đầu tiến độ 0 dù đất còn ướt |
| Hết thời gian ướt | Sprite đất khô; tiến độ cây vẫn giữ và tiếp tục tăng |
| Qua các ngưỡng 1/3, 2/3, 100% | Đổi lần lượt stage 2, 3, 4 |
| Bonus vượt thời gian còn lại | Clamp về trưởng thành, không vượt tổng |
| Nhấn giữ phím hoặc bấm liên tục khi đang ToolState | Mỗi lượt hành động có tối đa một tác động |
| Mục tiêu ngoài khu đất | Không tạo thêm ô hoặc cây |
| Thu hoạch cây chưa chín | Không xóa cây |
| Thu hoạch cây chín | Làm trống ô, ẩn CropSprite, giữ đất, trả item và sản lượng |
| Pause | Đất không khô thêm, cây không lớn thêm |
| Load lại | Khôi phục đúng thời gian còn lại, stage được tính lại |
| Player đứng trước/sau cây ở bốn hướng | Vị trí gốc, ô mục tiêu và Y-sort đúng |
| Hai ô trồng cùng loại cây | Tưới một ô không thay thời gian hoặc hình của ô còn lại |
| Ô khô/trống hoặc khô/cây chín | Tắt xử lý; trồng/tưới bật lại khi cần |
| Hai instance trùng plot_id | Phát hiện lỗi khi FarmLand đăng ký |
| Di chuyển ô trong editor hoặc world có offset | Tìm đúng scene ô; ngoài vùng trả null |
| Đổi tên/di chuyển node rồi load | Tìm đúng ô qua plot_id ổn định |
| Chuyển từ tile sang scene | Mỗi ô chỉ có một hình đất; tile viền vẫn giữ |
| Load cây đang lớn vào ô ban đầu trống | Cập nhật sprite và bật lại xử lý thời gian |

## 12. Tài liệu liên quan và trạng thái kiểm chứng

- [Resource ảnh cây đang có](crop_resources.md): 22 bộ hoa màu, mỗi bộ có 4 stage AtlasTexture khung 16 × 32.
- [Godot Node2D](https://docs.godotengine.org/en/stable/classes/class_node2d.html): tọa độ local/global.
- [Godot Rect2](https://docs.godotengine.org/en/stable/classes/class_rect2.html): kiểm tra điểm nằm trong vùng chữ nhật của ô.
- [Godot CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html): Y-sort và z_index.
- [Godot AnimatedSprite2D](https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html): signal frame_changed và animation_finished; animation loop không phát animation_finished.
- [Godot Node](https://docs.godotengine.org/en/stable/classes/class_node.html): delta, set_process và Process Mode khi pause.

Thiết kế được đối chiếu source hiện tại của world, Player, ToolState, AnimationComponent và tài liệu API Godot. Code mẫu chưa được chạy trong Godot; môi trường kiểm tra tài liệu hiện không có lệnh `godot` trong PATH. Cần thực hiện các ca kiểm tra trên khi triển khai scene và script thật.
