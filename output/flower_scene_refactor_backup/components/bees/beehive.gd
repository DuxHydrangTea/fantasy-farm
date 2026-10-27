class_name Beehive
extends StaticBody2D
## Small scene shell; components are composed by type and retain independent ownership.
var persistent_id: StringName
var apiary: ApiarySystem
var definition: BeehiveDefinition
var production: BeehiveProductionComponent = BeehiveProductionComponent.new()
var pollination: PollinationComponent = PollinationComponent.new()
var garden_id: String = ""
var garden_slot: int = -1
var repaired: bool = true
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
		sprite.modulate = Color.WHITE if repaired else Color(0.42,0.32,0.25)
		sprite.texture = definition.full_texture if production.ready_item != null else definition.idle_texture

func collect(bag: InventoryComponent) -> bool:
	apiary.sync()
	var amount: int = production.batch_amount()
	var item: ItemDefinition = production.collect(bag)
	refresh_visual()
	if item != null:
		apiary.farming.harvest_yielded.emit(item,amount,global_position,bag)
	return item != null

func action_text() -> String:
	if garden_slot >= 0:
		return tr("Bee journal") + "\n" + (tr("Repair: 15 wood + 500 coins") if not repaired else tr("Honey: {percent}%").format({"percent":floori(production.work / definition.cycle_seconds * 100)}))
	var legacy_notice: String = "\n" + tr("Legacy batch · Next batch: {amount} jars").format({"amount": definition.batch_amount}) if production.legacy_batch else ""
	if production.ready_item != null:
		return tr("Collect {item} ×{amount}").format({"item":tr(production.ready_item.display_name), "amount": production.batch_amount()}) + legacy_notice
	var rate: float = definition.honey_rate(pollination.source_id, production.legacy_batch)
	var remaining: String = AnimalStatusText.new().remaining((definition.cycle_seconds-production.work)/rate)
	var headline: String = tr("Honey: {percent}% · {time} · {amount} jars/batch").format({"percent":floori(production.work/definition.cycle_seconds*100),"time":remaining,"amount": production.batch_amount()})
	var source: String = tr("{flower} · Honey +{honey}% · Crops +{crops}%").format({"flower":tr(pollination.source_name),"honey":roundi((rate-1.0)*100),"crops":roundi(definition.crop_bonus*100)}) if pollination.active() else tr("No blooming flowers · Wild Honey")
	if pollination.active() and rate == 1.0:
		source += "\n" + tr("Common flowers · Wild Honey")
	if apiary != null and apiary.raining(apiary.last_at):
		source = tr("Rain: bees sheltering · Wild Honey")
	elif apiary != null and apiary.effective_radius(apiary.last_at) > definition.radius:
		source += "\n" + tr("Wind: pollination radius +50%")
	return headline + "\n" + source + legacy_notice

func capture() -> Dictionary:
	var result: Dictionary = production.capture()
	# New DTO keys must remain Strings for the async repository boundary.
	result["id"] = String(persistent_id)
	result["garden_id"] = garden_id
	result["garden_slot"] = garden_slot
	result["repaired"] = repaired
	result["position"] = [position.x,position.y]
	return result
