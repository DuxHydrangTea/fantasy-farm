@tool
class_name FlowerPot
extends StaticBody2D
var garden: FlowerGarden
## Timestamp-based growth in a permanent pot. Water starts the growth clock once.
signal changed
@export var empty_frames: SpriteFrames
var reserved: bool = false
var cell: Vector2i
var definition: FlowerDefinition
var planted_at: float = 0.0
var growth_started_at: float = -1.0
var matures_at: float = 0.0
var progress: float = 0.0
var stage: int = 0
var _focused: bool = false
var _status_focused: bool = false
var _harvesting: bool = false
@export var sprite: AnimatedSprite2D
@export var marker: Sprite2D
@export var progress_frame: TextureRect
@export var bar: ProgressBar

func _ready() -> void:
	_update_visual()

func is_mature() -> bool:
	return not is_locked() and definition != null and progress >= 1.0

func is_locked() -> bool:
	return reserved or (garden != null and garden.starter_content_locked)

func can_plant(seed: ItemDefinition) -> bool:
	return not is_locked() and definition == null and seed != null and seed.item_type == ItemDefinition.ItemType.SEED and seed.crop is FlowerDefinition and seed.crop.is_valid()

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

func can_water() -> bool:
	return not is_locked() and definition != null and growth_started_at < 0.0

# Với hoa chậu, lần tưới đầu mới bắt đầu đồng hồ lớn; -1 nghĩa là chưa bắt đầu.
# max(now, planted_at) tránh giờ bắt đầu nằm trước lúc gieo khi đồng hồ bị lùi.
# Nếu tưới lần nào cũng đặt lại mốc, người chơi tưới nhiều có thể vô tình kéo dài thời gian chín.
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
func refresh(now: float) -> void:
	if definition == null or growth_started_at < 0.0:
		return
	progress = maxf(progress, clampf((now - growth_started_at) / (matures_at - growth_started_at), 0.0, 1.0))
	# The fifth stage is the fully mature, harvestable flower.
	stage = mini(4, int(floor(progress * 4.0)))
	_update_visual()

func harvest(bag: InventoryComponent) -> bool:
	if _harvesting or bag == null or not is_mature():
		return false
	if bag.capacity_for(definition.harvest_item) < definition.harvest_amount:
		bag.report_capacity_blocked(definition.harvest_item, definition.harvest_amount)
		return false
	_sync_bees()
	_harvesting = true
	var count: int = bag.add(definition.harvest_item, definition.harvest_amount)
	if count == definition.harvest_amount:
		clear()
	_harvesting = false
	return count > 0

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

func capture(now: float) -> Dictionary:
	refresh(now)
	return {"cell": [cell.x, cell.y], "flower": String(definition.flower_id), "planted_at": planted_at, "growth_started_at": growth_started_at, "matures_at": matures_at, "progress": progress}

func set_focused(value: bool, allowed: bool = true) -> void:
	_refresh_for_focus(value)
	_focused = value
	marker.visible = value
	marker.modulate = Color.WHITE if allowed else Color(1, 0.45, 0.35)
	_update_status_visibility()

func set_status_focused(value: bool) -> void:
	_refresh_for_focus(value)
	_status_focused = value
	_update_status_visibility()

func get_status_sprite() -> Node2D:
	return sprite

func _refresh_for_focus(value: bool) -> void:
	if value and garden != null and garden.time_manager != null:
		refresh(garden.time_manager.now())

func _update_status_visibility() -> void:
	progress_frame.visible = (_focused or _status_focused) and definition != null

func _update_visual() -> void:
	if not is_node_ready() or sprite == null or progress_frame == null or bar == null:
		return
	var frames: SpriteFrames = definition.stage_frames[stage] if definition != null else empty_frames
	# Empty pots and planted composites use the same native-size clay pot.
	sprite.scale = Vector2.ONE
	if sprite.sprite_frames != frames:
		sprite.sprite_frames = frames
		sprite.play(&"grow")
	# Keep empty pots and the lowered plant composites on the same ground baseline.
	var texture: Texture2D = frames.get_frame_texture(&"grow", 0)
	var height: float = texture.get_height() * sprite.scale.y if texture != null else 16.0
	sprite.position.y = -height * 0.5
	progress_frame.position.y = -maxf(26.0, height + 10.0)
	_update_status_visibility()
	bar.value = progress
	bar.modulate = Color(1, 0.85, 0.35) if is_mature() else (Color(0.6, 0.8, 1) if can_water() else Color.WHITE)

func _sync_bees() -> void:
	if garden != null and garden.apiary != null:
		garden.apiary.sync()
