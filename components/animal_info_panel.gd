class_name AnimalInfoPanel
extends CanvasLayer
## One screen-space inspector. Mouse-over animal takes priority over facing focus.
@export var root: Control
@export var title: Label
@export var maturity_label: Label
@export var lifetime_label: Label
@export var produce_label: Label
@export var progress: ProgressBar
@export var state_label: Label
var animal: AnimalActor
var _text: AnimalStatusText = AnimalStatusText.new()
var _elapsed: float = 0.0
var production_row: VisualValueRow

func _ready() -> void:
	production_row = VisualValueRow.before(produce_label)
	UIScaleComponent.attach(self, root)
	root.resized.connect(_fit_layout)
	_fit_layout()
	root.hide()

func _fit_layout() -> void:
	var touch: bool = MobileLayout.is_touch(get_viewport())
	var panel: PanelContainer = title.get_parent().get_parent() as PanelContainer
	# Leave the top-right wallet and settings controls visible above the inspector.
	(panel.get_parent() as MarginContainer).add_theme_constant_override("margin_top", 76)
	panel.custom_minimum_size.x = 320 if touch else 340
	title.add_theme_font_size_override("font_size", 20 if touch else 24)
	for caption: Label in [maturity_label, lifetime_label, produce_label, state_label]:
		caption.add_theme_font_size_override("font_size", 18 if touch else 20)

func inspect(target: AnimalActor) -> void:
	animal = target
	refresh()

func refresh() -> void:
	if not is_instance_valid(animal) or not _text.is_available(animal):
		animal = null
		root.hide()
		return
	title.text = tr("{animal} · #{id}").format({"animal": tr(animal.definition.display_name), "id": String(animal.persistent_id).right(6)}) if not animal.persistent_id.is_empty() else tr(animal.definition.display_name)
	maturity_label.text = _text.maturity(animal)
	maturity_label.tooltip_text = tr("Early maturity") if animal.growth.juvenile_tonic_used else ""
	lifetime_label.text = _text.lifetime(animal)
	var definition: AnimalProductionDefinition = animal.production.definition
	production_row.show_production(definition, _text.remaining(definition.production_seconds) if definition != null else "")
	produce_label.text = "%d%%" % floori(animal.production.progress_ratio() * 100.0)
	var ready_amount: int = animal.production.stored_amount
	if animal.product_pickup() != null:
		ready_amount += animal.product_pickup().amount
	if ready_amount > 0:
		produce_label.text += " · " + tr("Ready to collect: {amount}").format({"amount": GameText.grouped_integer(ready_amount)})
	produce_label.tooltip_text = tr("Tonic active") if animal.production.tonic_pending else ""
	progress.value = clampf(animal.production.progress_ratio() * 100.0, 0.0, 100.0)
	state_label.text = _text.production_state(animal)
	root.show()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()
