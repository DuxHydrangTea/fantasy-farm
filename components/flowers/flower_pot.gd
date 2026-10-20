@tool
extends StaticBody2D
## Timestamp-based growth in a permanent pot. Water starts the growth clock once.
const Definition = preload("res://scripts/flower_definition.gd")
const Item = preload("res://scripts/item_definition.gd")
const Inventory = preload("res://components/inventory_component.gd")
signal changed
@export var empty_frames: SpriteFrames
var cell: Vector2i
var definition: Definition
var planted_at: float = 0.0
var growth_started_at: float = -1.0
var matures_at: float = 0.0
var progress: float = 0.0
var stage: int = 0
var _focused: bool = false
var _status_focused: bool = false
var _harvesting: bool = false
@onready var sprite: AnimatedSprite2D = $Flower
@onready var marker: Sprite2D = $Focus
@onready var progress_frame: TextureRect = $Progress
@onready var bar: ProgressBar = $Progress/Bar

func _ready() -> void:
	_update_visual()

func is_mature() -> bool:
	return definition != null and progress >= 1.0

func can_plant(seed: Item) -> bool:
	return definition == null and seed != null and seed.item_type == Item.ItemType.SEED and seed.crop is Definition and seed.crop.is_valid()

func plant(bag: Inventory, index: int, now: float) -> bool:
	if bag == null:
		return false
	var stack: Dictionary = bag.slot(index)
	var seed: Item = stack.item as Item
	if not can_plant(seed) or stack.count < 1:
		return false
	# Establish state before inventory signals can re-enter the interaction.
	definition = seed.crop as Definition
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
	return definition != null and growth_started_at < 0.0

func water(now: float) -> bool:
	if not can_water():
		return false
	growth_started_at = maxf(now, planted_at)
	matures_at = growth_started_at + definition.growth_seconds
	_update_visual()
	changed.emit()
	return true

func refresh(now: float) -> void:
	if definition == null or growth_started_at < 0.0:
		return
	progress = maxf(progress, clampf((now - growth_started_at) / (matures_at - growth_started_at), 0.0, 1.0))
	# The fifth stage is the fully mature, harvestable flower.
	stage = mini(4, int(floor(progress * 4.0)))
	_update_visual()

func harvest(bag: Inventory) -> bool:
	if _harvesting or bag == null or not is_mature() or bag.capacity_for(definition.harvest_item) < definition.harvest_amount:
		return false
	_harvesting = true
	var count: int = bag.add(definition.harvest_item, definition.harvest_amount)
	if count == definition.harvest_amount:
		clear()
	_harvesting = false
	return count > 0

func clear() -> void:
	definition = null
	planted_at = 0.0
	growth_started_at = -1.0
	matures_at = 0.0
	progress = 0.0
	stage = 0
	_update_visual()
	changed.emit()

func restore_state(data: Dictionary, flower: Definition, now: float) -> void:
	definition = flower
	planted_at = float(data.planted_at)
	growth_started_at = float(data.growth_started_at)
	matures_at = float(data.matures_at)
	progress = float(data.progress)
	stage = mini(4, int(floor(progress * 4.0)))
	refresh(now)
	_update_visual()

func capture(now: float) -> Dictionary:
	refresh(now)
	return {"cell": [cell.x, cell.y], "flower": String(definition.flower_id), "planted_at": planted_at, "growth_started_at": growth_started_at, "matures_at": matures_at, "progress": progress}

func set_focused(value: bool, allowed: bool = true) -> void:
	_focused = value
	marker.visible = value
	marker.modulate = Color.WHITE if allowed else Color(1, 0.45, 0.35)
	_update_status_visibility()

func set_status_focused(value: bool) -> void:
	_status_focused = value
	_update_status_visibility()

func get_status_sprite() -> Node2D:
	return sprite

func _update_status_visibility() -> void:
	progress_frame.visible = (_focused or _status_focused) and definition != null

func _update_visual() -> void:
	if not is_node_ready():
		return
	var frames: SpriteFrames = definition.stage_frames[stage] if definition != null else empty_frames
	# House-decor empty pots are twice the size of the pots baked into flower art.
	# Half scale keeps integer pixel steps and the same ground-level anchor.
	sprite.scale = Vector2(0.5, 0.5) if definition == null else Vector2.ONE
	sprite.position.y = -4.0 if definition == null else -8.0
	if sprite.sprite_frames != frames:
		sprite.sprite_frames = frames
		sprite.play(&"grow")
	_update_status_visibility()
	bar.value = progress
	bar.modulate = Color(1, 0.85, 0.35) if is_mature() else (Color(0.6, 0.8, 1) if can_water() else Color.WHITE)
