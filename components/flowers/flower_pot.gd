@tool
class_name FlowerPot
extends StaticBody2D
## Chậu hoa cố định lưu trạng thái gieo, tưới, lớn và thu hoạch.
## Đồng hồ sinh trưởng bắt đầu từ lần tưới đầu tiên. Chậu có chế độ xem trước
## trong editor và đồng bộ đàn ong trước các thay đổi ảnh hưởng nguồn hoa.

## Vườn chứa chậu.
var garden: FlowerGarden
## Phát khi nội dung hoặc trạng thái chậu thay đổi.
signal changed
## Phát vật phẩm thực thu, số lượng, vị trí và túi nhận.
signal harvest_yielded(item: ItemDefinition, amount: int, at: Vector2, inventory: InventoryComponent)
## Cấu hình hình ảnh chậu.
@export var pot_definition: PotDefinition = preload("res://resources/pots/clay_pot.tres"):
	set(value):
		pot_definition = value
		_update_visual()
## Bộ trình bày hình chậu và cây.
@export var visual: FlowerPotVisual
## Loài hoa xem trước trong editor.
@export var preview_flower: FlowerDefinition:
	set(value):
		preview_flower = value
		if Engine.is_editor_hint():
			apply_editor_preview()
## Giai đoạn xem trước trong editor.
@export_range(0, 4) var preview_stage: int = 4:
	set(value):
		preview_stage = value
		if Engine.is_editor_hint():
			apply_editor_preview()
## Ô được dành riêng và không nhận thao tác trồng, tưới hoặc thu.
var reserved: bool = false
## Tọa độ ô ổn định của chậu trong vườn.
@export var cell: Vector2i:
	set(value):
		cell = value
		if Engine.is_editor_hint() and is_instance_valid(garden):
			garden.update_configuration_warnings()
## Định nghĩa hoa đang trồng, null nếu chậu trống.
var definition: FlowerDefinition
## Timestamp gieo.
var planted_at: float = 0.0
## Timestamp tưới lần đầu, -1 khi chưa bắt đầu lớn.
var growth_started_at: float = -1.0
## Timestamp chín dự kiến.
var matures_at: float = 0.0
## Tiến độ từ 0 đến 1.
var progress: float = 0.0
## Chỉ số ảnh trong năm giai đoạn.
var stage: int = 0
var _focused: bool = false
var _status_focused: bool = false
var _harvesting: bool = false
## Sprite cây dự phòng.
@export var sprite: Sprite2D
## Hiệu ứng chuyển động hình ảnh.
@export var motion: VisualMotionComponent
## Dấu chỉ vị trí đang được nhắm.
@export var marker: Sprite2D
## Khung thanh tiến độ.
@export var progress_frame: TextureRect
## Thanh tiến độ sinh trưởng.
@export var bar: ProgressBar

func _ready() -> void:
	if Engine.is_editor_hint():
		apply_editor_preview()
	else:
		_update_visual()

## Kiểm tra chậu mở khóa, có hoa và tiến độ đã đạt 1.
func is_mature() -> bool:
	return not is_locked() and definition != null and progress >= 1.0

## Kiểm tra chậu được dành riêng hoặc nội dung khởi đầu của vườn còn khóa.
func is_locked() -> bool:
	return reserved or (garden != null and garden.starter_content_locked)

## Kiểm tra chậu trống, mở khóa và hạt giống có định nghĩa hoa hợp lệ.
func can_plant(seed: ItemDefinition) -> bool:
	return not is_locked() and definition == null and seed != null and seed.item_type == ItemDefinition.ItemType.SEED and seed.crop is FlowerDefinition and seed.crop.is_valid()

## Gieo một hạt từ ô túi sau khi đồng bộ ong và kiểm tra điều kiện.
## Thiết lập trạng thái trước khi trừ hạt và phát signal.
func plant(bag: InventoryComponent, index: int, now: float) -> bool:
	if bag == null:
		return false
	var stack: Dictionary = bag.slot(index)
	var seed: ItemDefinition = stack.item as ItemDefinition
	if not can_plant(seed) or stack.count < 1:
		return false
	_sync_bees()
	# Establish state before inventory signals can re-enter the interaction.
	definition = seed.crop as FlowerDefinition
	planted_at = now
	growth_started_at = -1.0
	matures_at = 0.0
	progress = 0.0
	stage = 0
	bag.remove_from_slot(index, 1)
	_update_visual()
	changed.emit()
	return true

## Kiểm tra hoa đã gieo và chưa được tưới bắt đầu sinh trưởng.
func can_water() -> bool:
	return not is_locked() and definition != null and growth_started_at < 0.0

# Với hoa chậu, lần tưới đầu mới bắt đầu đồng hồ lớn; -1 nghĩa là chưa bắt đầu.
# max(now, planted_at) tránh giờ bắt đầu nằm trước lúc gieo khi đồng hồ bị lùi.
# Nếu tưới lần nào cũng đặt lại mốc, người chơi tưới nhiều có thể vô tình kéo dài thời gian chín.
## Bắt đầu đồng hồ sinh trưởng một lần, không sớm hơn thời điểm gieo.
func water(now: float) -> bool:
	if not can_water():
		return false
	_sync_bees()
	growth_started_at = maxf(now, planted_at)
	matures_at = growth_started_at + definition.growth_seconds
	_update_visual()
	changed.emit()
	return true

# Hoa chậu có 5 stage (0..4), khác cây farmland có 4 stage (0..3).
# Vì vậy nhân tiến độ với 4 ở đây, còn farmland nhân 3; không đổi hai nơi thành cùng một số.
# Nếu nhầm số stage, hình hoa chín và thời điểm cho thu hoạch sẽ không khớp nhau.
## Cập nhật tiến độ không lùi và ảnh trong năm giai đoạn đến thời điểm now.
func refresh(now: float) -> void:
	if definition == null or growth_started_at < 0.0:
		return
	progress = maxf(progress, clampf((now - growth_started_at) / (matures_at - growth_started_at), 0.0, 1.0))
	# The fifth stage is the fully mature, harvestable flower.
	stage = mini(4, int(floor(progress * 4.0)))
	_update_visual()

## Thu hoa chín nếu túi chứa đủ mẻ, phát số thực nhận và xóa hoa khỏi chậu.
func harvest(bag: InventoryComponent) -> bool:
	if _harvesting or bag == null or not is_mature():
		return false
	if bag.capacity_for(definition.harvest_item) < definition.harvest_amount:
		bag.report_capacity_blocked(definition.harvest_item, definition.harvest_amount)
		return false
	_sync_bees()
	_harvesting = true
	var item: ItemDefinition = definition.harvest_item
	var count: int = bag.add(item, definition.harvest_amount)
	if count == definition.harvest_amount:
		clear()
	if count > 0:
		harvest_yielded.emit(item, count, global_position, bag)
	_harvesting = false
	return count > 0

## Đồng bộ ong rồi xóa hoa và đặt lại trạng thái chậu.
func clear() -> void:
	_sync_bees()
	definition = null
	planted_at = 0.0
	growth_started_at = -1.0
	matures_at = 0.0
	progress = 0.0
	stage = 0
	_update_visual()
	changed.emit()

## Khôi phục trạng thái đã kiểm tra và cập nhật tiến độ đến now.
func restore_state(data: Dictionary, flower: FlowerDefinition, now: float) -> void:
	definition = flower
	planted_at = float(data.planted_at)
	growth_started_at = float(data.growth_started_at)
	matures_at = float(data.matures_at)
	progress = float(data.progress)
	stage = mini(4, int(floor(progress * 4.0)))
	refresh(now)
	_update_visual()
	changed.emit()

## Cập nhật đến now rồi tạo bản ghi lưu của hoa đang trồng.
func capture(now: float) -> Dictionary:
	refresh(now)
	return {"cell": [cell.x, cell.y], "flower": String(definition.flower_id), "planted_at": planted_at, "growth_started_at": growth_started_at, "matures_at": matures_at, "progress": progress}

## Cập nhật dấu nhắm và màu cho biết thao tác có được phép.
func set_focused(value: bool, allowed: bool = true) -> void:
	_refresh_for_focus(value)
	_focused = value
	marker.visible = value
	marker.modulate = Color.WHITE if allowed else Color(1, 0.45, 0.35)
	_update_status_visibility()

## Cập nhật trạng thái xem thông tin và hiệu ứng hình ảnh.
func set_status_focused(value: bool) -> void:
	_refresh_for_focus(value)
	_status_focused = value
	if is_instance_valid(motion):
		motion.set_focused(value and definition != null)
	_update_status_visibility()

## Trả sprite dùng neo thông tin trạng thái.
func get_status_sprite() -> Node2D:
	return visual.status_sprite() if visual != null else sprite

## Trả biên hình chậu và cây trong tọa độ chậu.
func get_visual_rect() -> Rect2:
	return visual.bounds_in(self) if visual != null else Rect2()

## Áp hình chậu và giai đoạn hoa xem trước trong editor.
func apply_editor_preview() -> void:
	if visual == null:
		return
	visual.apply_definition(pot_definition)
	# Resource scripts may be editor placeholders; preview reads exported data only.
	var texture: Texture2D
	if preview_flower != null and preview_stage < preview_flower.stage_textures.size():
		texture = preview_flower.stage_textures[preview_stage]
	visual.show_plant(texture)

func _refresh_for_focus(value: bool) -> void:
	if value and garden != null and garden.time_manager != null:
		refresh(garden.time_manager.now())

func _update_status_visibility() -> void:
	progress_frame.visible = (_focused or _status_focused) and definition != null

func _update_visual() -> void:
	if not is_node_ready() or visual == null or progress_frame == null or bar == null:
		return
	visual.apply_definition(pot_definition)
	visual.show_plant(definition.stage_textures[stage] if definition != null else null)
	if is_instance_valid(motion):
		motion.set_focused(_status_focused and definition != null)
	_update_status_visibility()
	bar.value = progress
	bar.modulate = Color(1, 0.85, 0.35) if is_mature() else (Color(0.6, 0.8, 1) if can_water() else Color.WHITE)

func _sync_bees() -> void:
	if garden != null and garden.apiary != null:
		garden.apiary.sync()
