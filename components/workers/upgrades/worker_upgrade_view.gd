class_name WorkerUpgradeView
extends VBoxContainer
## Container-based view; all writes go through the team's purchase command.
const CAPTIONS: Dictionary = {"speed": "Work speed", "hoe": "Worker hoe", "sowing": "Worker sowing", "watering": "Worker watering", "harvest": "Worker harvesting"}
var shop: WorkerUpgradeService
var buttons: Dictionary = {}
var details: Dictionary = {}
var reasons: Dictionary = {}
var offers: Dictionary = {}
var message: Label

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var hint: Label = Label.new()
	hint.text = tr("Upgrades apply to the whole team and remain after rehiring. New jobs use the new level.")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	for track: String in WorkerUpgradeState.TRACKS:
		var card: PanelContainer = PanelContainer.new()
		card.theme_type_variation = &"DetailCard"
		add_child(card)
		var column: VBoxContainer = VBoxContainer.new()
		card.add_child(column)
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
		details[track] = label
		var button: Button = Button.new()
		button.custom_minimum_size.y = 48
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_purchase.bind(track))
		column.add_child(button)
		buttons[track] = button
		var reason: Label = Label.new()
		reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(reason)
		reasons[track] = reason
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message)

func refresh(service: WorkerUpgradeService) -> void:
	shop = service
	for track: String in WorkerUpgradeState.TRACKS:
		var offer: Dictionary = shop.quote(track)
		offers[track] = offer
		var current: int = int(offer.current)
		var full: bool = current >= WorkerUpgradeState.maximum(track)
		var effect: String
		if track == "speed":
			var base: float = (WorkerService.DEFINITIONS["crop"] as WorkerDefinition).work_seconds
			effect = tr("{seconds}s per action").format({"seconds": "%.2f" % shop.workers.upgrades.duration(base, "harvest")})
			if not full:
				effect += " → %.2fs" % (base * pow(0.9, current + 1))
		else:
			effect = "%d×%d" % [current, current]
			if not full:
				effect += " → %d×%d" % [current + 1, current + 1]
		(details[track] as Label).text = "%s · %d/%d\n%s" % [tr(String(CAPTIONS[track])), current, WorkerUpgradeState.maximum(track), effect]
		var button: Button = buttons[track] as Button
		button.disabled = not offer.ok
		button.text = tr("Fully upgraded.") if full else tr("Upgrade · {coins} coins").format({"coins": GameText.grouped_integer(int(offer.price))})
		button.tooltip_text = tr(String(offer.get("error", "")))
		var reason: Label = reasons[track] as Label
		reason.text = button.tooltip_text
		reason.visible = not offer.ok

func _purchase(track: String) -> void:
	var offer: Dictionary = offers[track]
	var result: Dictionary = shop.purchase(track, int(offer.current), int(offer.price))
	message.text = tr("Team upgrade purchased.") if result.ok else tr(String(result.error))
	refresh(shop)
