class_name AnimalActor
extends CharacterBody2D
signal died
@export var collision: CollisionShape2D
@export var needs_display: Node2D
@export var satiety_bar: ProgressBar
@export var hydration_bar: ProgressBar
@export var persistent_id: StringName

@export var definition: AnimalDefinition
@export var pen: AnimalPen
@export var skin_frames: SpriteFrames
@export var show_needs: bool = true
@export_range(0.0, 31536000.0) var initial_age_seconds: float = 0.0
@export var sprite: AnimatedSprite2D
@export var movement: MovementComponent
@export var animation: AnimationComponent
@export var needs: AnimalNeedsComponent
@export var wander: AnimalWanderComponent
@export var behaviour: AnimalBehaviourComponent
@export var foraging: AnimalForagingComponent
@export var growth: AnimalGrowthComponent
@export var production: AnimalProductionComponent
var _product_pickup: ItemPickup
var _stage_visual_pending: bool = false
var waterfowl: WaterfowlComponent
var _dead: bool = false
var _retired: bool = false

func _ready() -> void:
	if persistent_id.is_empty():
		persistent_id = StringName("entity_" + Crypto.new().generate_random_bytes(16).hex_encode())
	needs_display.hide()
	add_to_group(&"animal_status_targets")
	if pen == null:
		pen = get_parent() as AnimalPen
	if definition == null or not definition.is_valid():
		wander.set_physics_process(false)
		return
	movement.speed = definition.move_speed
	animation.single_direction_faces_left = definition.faces_left
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = definition.footprint
	collision.shape = shape
	needs.weather = pen.weather if pen != null else null
	needs.pen = pen
	needs.configure(definition.satiety_depletion_seconds, definition.hydration_depletion_seconds)
	needs.changed.connect(_update_needs_display)
	_update_needs_display(needs.satiety, needs.hydration)
	wander.pen = pen
	wander.idle_seconds = definition.idle_seconds
	wander.margin = maxf(definition.pen_margin, definition.footprint.length() * 0.5)
	growth.configure(definition.maturity_seconds, initial_age_seconds, definition.lifespan_seconds)
	production.configure(definition.production)
	growth.matured.connect(_on_matured)
	production.produced.connect(_on_produced)
	needs.time_advanced.connect(_advance_lifecycle)
	_apply_stage_visuals()
	animation.play("idle")
	foraging.configure(definition, needs, wander)
	behaviour.configure(definition)
	if pen is PondPen and definition.eggs_on_land:
		waterfowl = WaterfowlComponent.new()
		waterfowl.name = "WaterfowlComponent"
		add_child(waterfowl)
		waterfowl.configure(self, pen as PondPen)
	if growth.is_dead():
		_die()

func _physics_process(_delta: float) -> void:
	if waterfowl != null:
		waterfowl.refresh_visual()
	# Swap real juvenile art only while upright and idle, preserving rest/meal chains.
	if _stage_visual_pending and behaviour.current_state == AnimalBehaviourComponent.State.IDLE:
		_apply_stage_visuals()
		behaviour.configure(definition)

func _apply_stage_visuals() -> void:
	_stage_visual_pending = false
	var frames: SpriteFrames = definition.get_frames_for_stage(growth.is_adult())
	if frames == definition.adult_frames and definition.has_movement_frames(skin_frames):
		frames = skin_frames
	sprite.sprite_frames = frames
	var texture: Texture2D = frames.get_frame_texture(&"idle_down", 0)
	if texture != null:
		var visible_rect: Rect2i = texture.get_image().get_used_rect()
		sprite.position.y = texture.get_height() * 0.5 - visible_rect.end.y
		needs_display.position.y = sprite.position.y - texture.get_height() * 0.5 + visible_rect.position.y - 18.0

func _on_matured() -> void:
	var frames: SpriteFrames = definition.get_frames_for_stage(true)
	if definition.has_movement_frames(skin_frames):
		frames = skin_frames
	_stage_visual_pending = frames != sprite.sprite_frames

func _advance_lifecycle(timestamp: float, elapsed: float, supplied_seconds: float) -> void:
	if _retired or is_queued_for_deletion():
		return
	# Intersect the supplied prefix with the adult, still-alive interval.
	# A single offline jump may cross BOTH maturity and death. Credit only that
	# overlap, deliver completed output, then retire the actor exactly once.
	var juvenile_seconds: float = growth.seconds_until_adult()
	var alive_seconds: float = growth.seconds_until_death()
	growth.advance(elapsed)
	var rate: float = 1.0
	if pen is PondPen and definition.eggs_on_land and needs.weather != null and needs.weather.weather_at(timestamp - elapsed) == WeatherSchedule.Weather.RAIN:
		rate = 1.1
	production.advance(maxf(0.0, minf(supplied_seconds, alive_seconds) - juvenile_seconds) * rate)
	if growth.is_dead():
		_die()

func is_dead() -> bool:
	return _dead

func _die() -> void:
	if _retired:
		return
	_dead = true
	_retire()
	died.emit()

## Trading retires the living actor without reporting a death.
func retire_for_sale() -> bool:
	if _retired or is_queued_for_deletion():
		return false
	_retire()
	return true

func _retire() -> void:
	_retired = true
	needs.deactivate()
	foraging.cancel()
	wander.set_physics_process(false)
	behaviour.set_physics_process(false)
	set_physics_process(false)
	movement.cancel_target()
	movement.stop()
	remove_from_group(&"animal_status_targets")
	needs_display.hide()
	hide()
	queue_free()
	# Completed stock remains collectible, including direct collection and
	# eggs awaiting shore delivery. Partial production progress expires.
	_drop_stored_output()

func _on_produced(_amount: int) -> void:
	if _retired or production.definition.collection_mode != AnimalProductionDefinition.CollectionMode.WORLD_DROP or not is_inside_tree():
		return
	if definition.eggs_on_land and pen is PondPen and (pen as PondPen).is_water(global_position):
		return # Keep the completed eggs in production stock until physically on shore.
	_drop_stored_output()

func _drop_stored_output() -> void:
	if production.definition == null or production.stored_amount <= 0 or not is_inside_tree():
		return
	# Mỗi con giữ liên kết với đống sản phẩm của mình: các lô sau cộng vào cùng đống còn sống.
	# queue_free chưa xóa Node ngay, nên phải kiểm tra cả is_queued_for_deletion, không chỉ is_instance_valid.
	# Nếu cộng vào đống đã xếp lịch xóa do vừa nhặt hết, lô mới có thể biến mất cuối frame.
	if not is_instance_valid(_product_pickup) or _product_pickup.is_queued_for_deletion():
		_product_pickup = ItemPickup.create()
		_product_pickup.item = production.definition.production_item
		_product_pickup.amount = production.take_output(production.stored_amount)
		var spawn_point: Vector2 = global_position + Vector2(0, 10)
		if is_instance_valid(pen):
			spawn_point = pen.clamp_world(spawn_point, wander.margin)
			if definition.eggs_on_land and pen is PondPen:
				spawn_point = (pen as PondPen).closest_land(global_position)
		get_parent().add_child(_product_pickup)
		_product_pickup.global_position = spawn_point
	else:
		_product_pickup.add_amount(production.take_output(production.stored_amount))

func collect_produce(inventory: InventoryComponent) -> int:
	if needs.time_manager != null:
		needs.update_at(needs.time_manager.now())
	if _retired or production.definition == null or production.definition.collection_mode != AnimalProductionDefinition.CollectionMode.DIRECT_COLLECTION:
		return 0
	return production.collect(inventory)

func product_pickup() -> ItemPickup:
	return _product_pickup if is_instance_valid(_product_pickup) and not _product_pickup.is_queued_for_deletion() else null

## The persistence adapter validates the DTO before rebuilding this actor.
func restore_lifecycle(data: Dictionary, saved_at: float, now: float, pile: ItemPickup) -> void:
	foraging.cancel()
	wander.movement.cancel_target()
	wander.movement.stop()
	growth.configure(definition.maturity_seconds, float(data.age), definition.lifespan_seconds, bool(data.get("juvenile_tonic_used", false)))
	production.restore_state(float(data.production_progress), int(data.production_stock), bool(data.get("tonic_pending", false)))
	needs.restore_state(float(data.satiety), float(data.hydration), saved_at)
	_product_pickup = pile
	if production.definition != null and production.definition.collection_mode == AnimalProductionDefinition.CollectionMode.WORLD_DROP and production.stored_amount > 0:
		_on_produced(0)
	needs.update_at(now)
	if growth.is_dead():
		_die()
		return
	_apply_stage_visuals()
	behaviour.configure(definition)

func _update_needs_display(food: float, water: float) -> void:
	satiety_bar.value = food
	hydration_bar.value = water

func set_status_focused(_value: bool) -> void:
	# Legacy callers cannot expose world bars or stop behaviour.
	needs_display.hide()

func get_status_sprite() -> Node2D:
	return sprite

func tonic_error() -> String:
	if _retired or is_queued_for_deletion() or definition == null or growth.is_dead():
		return "Animal unavailable"
	if not growth.is_adult():
		return "This juvenile already received a tonic." if growth.juvenile_tonic_used else ""
	if production.definition == null or not production.definition.is_valid():
		return "No produce configured"
	return "A tonic is already active for the next cycle." if production.tonic_pending else ""

func apply_tonic() -> bool:
	if needs.time_manager != null:
		needs.update_at(needs.time_manager.now())
	if not tonic_error().is_empty():
		return false
	return production.apply_tonic() if growth.is_adult() else growth.apply_juvenile_tonic()
