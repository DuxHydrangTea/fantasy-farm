class_name Beehive
extends StaticBody2D
## Small scene shell; components are composed by type and retain independent ownership.
var persistent_id: StringName
var apiary: ApiarySystem
var definition: BeehiveDefinition
var production: BeehiveProductionComponent = BeehiveProductionComponent.new()
var pollination: PollinationComponent = PollinationComponent.new()
var sprite: Sprite2D
var range_display: BeehiveRangeDisplay
var bees: BeeVisualComponent

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	production.definition = definition
	sprite = Sprite2D.new()
	sprite.position.y = -8
	add_child(sprite)
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(12,10)
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.shape = shape
	collider.position.y = -2
	add_child(collider)
	range_display = BeehiveRangeDisplay.new()
	range_display.radius = definition.radius
	range_display.z_index = -1
	range_display.hide()
	add_child(range_display)
	bees = BeeVisualComponent.new()
	bees.hive = self
	add_child(bees)
	add_to_group(&"beehives")
	refresh_visual()

func refresh_visual() -> void:
	if sprite != null:
		sprite.texture = definition.full_texture if production.ready_item != null else definition.idle_texture

func collect(bag: InventoryComponent) -> bool:
	apiary.sync()
	var item: ItemDefinition = production.collect(bag)
	refresh_visual()
	if item != null:
		apiary.farming.harvest_yielded.emit(item,1,global_position,bag)
	return item != null

func action_text() -> String:
	if production.ready_item != null:
		return tr("Collect {item}").format({"item":tr(production.ready_item.display_name)})
	var rate: float = definition.pollen_speed if pollination.active() else 1.0
	var remaining: String = AnimalStatusText.new().remaining((definition.cycle_seconds-production.work)/rate)
	var headline: String = tr("Honey: {percent}% · {time}").format({"percent":floori(production.work/definition.cycle_seconds*100),"time":remaining})
	var source: String = tr("{flower} · Honey +{honey}% · Crops +{crops}%").format({"flower":tr(pollination.source_name),"honey":roundi((definition.pollen_speed-1.0)*100),"crops":roundi(definition.crop_bonus*100)}) if pollination.active() else tr("No blooming flowers · Wild Honey")
	if apiary != null and apiary.raining(apiary.last_at):
		source = tr("Rain: bees sheltering · Wild Honey")
	elif apiary != null and apiary.effective_radius(apiary.last_at) > definition.radius:
		source += "\n" + tr("Wind: pollination radius +50%")
	return headline + "\n" + source

func capture() -> Dictionary:
	var result: Dictionary = production.capture()
	# New DTO keys must remain Strings for the async repository boundary.
	result["id"] = String(persistent_id)
	result["position"] = [position.x,position.y]
	return result
