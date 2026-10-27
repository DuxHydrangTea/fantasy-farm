class_name WorkerMenu
extends TradeMenu
## Role-specific view over WorkerService; portraits and controls never mutate actors.
var role: String = "orchard"
var world: FarmWorld
@onready var panel: PanelContainer = %Panel
@onready var info: Label = %Info
@onready var status: Label = %Status
@onready var hire_button: Button = %Hire
@onready var dismiss_button: Button = %Dismiss
@onready var collect_button: Button = %Collect
@onready var deposit_button: Button = %Deposit
@onready var withdraw_button: Button = %Withdraw
@onready var auto_plant_button: Button = %AutoPlant
@onready var auto_fertilize_button: Button = %AutoFertilize
@onready var pause_crop_button: Button = %PauseCrop
@onready var zones: OptionButton = %Zones
@onready var preview: AnimatedSprite2D = %Preview
@onready var portrait: Control = %Portrait
@onready var confirmation: VBoxContainer = %Confirmation
@onready var confirm_button: Button = %ConfirmDismiss
@onready var cancel_button: Button = %CancelDismiss
var _confirm: bool = false
var _dismiss_id: String = ""
var _elapsed: float = 0.0
var _compact: bool = false
const TITLES: Dictionary = {"crop": "Crop worker", "orchard": "Orchard worker", "ranch": "Ranch worker"}
const DESCRIPTIONS: Dictionary = {"crop": "Waters, harvests and tends crops.", "orchard": "Waters and harvests fruit trees.", "ranch": "Feeds and waters animals; collected products go to the warehouse."}
const TASKS: Dictionary = {"till": "Tilling soil", "plant": "Planting crops", "fertilize": "Fertilizing crops", "water": "Watering", "feed": "Refilling feed", "harvest": "Harvesting", "pickup": "Collecting produce", "patrol": "Patrolling the work area"}

func _ready() -> void:
	root = %Root
	close_button = %Close
	super._ready()
	visit_started.connect(_visit)
	models_changed.connect(_refresh)
	root.resized.connect(_fit)
	portrait.resized.connect(_place_portrait)
	hire_button.pressed.connect(_hire)
	dismiss_button.pressed.connect(_dismiss)
	confirm_button.pressed.connect(_dismiss)
	cancel_button.pressed.connect(_cancel_dismiss)
	auto_plant_button.pressed.connect(_toggle_auto_plant)
	auto_fertilize_button.pressed.connect(_toggle_auto_fertilize)
	pause_crop_button.pressed.connect(_toggle_crop_pause)
	collect_button.pressed.connect(_collect)
	withdraw_button.pressed.connect(_withdraw)
	deposit_button.pressed.connect(_deposit)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		zones.add_theme_stylebox_override(state, root.theme.get_stylebox(state, "Button"))
	zones.add_theme_color_override("font_color", Color("401c0f"))
	(%SeedIcon as TextureRect).texture = preload("res://items/seeds/carrot_seed.tres").icon
	(%FertilizerIcon as TextureRect).texture = preload("res://items/boosters/crop_fertilizer.tres").icon
	_set_portrait()
	_fit()

func _set_portrait() -> void:
	var definition: WorkerDefinition = WorkerService.DEFINITIONS[role] as WorkerDefinition
	if preview.sprite_frames != definition.frames:
		preview.sprite_frames = definition.frames
		preview.play(&"idle_down")
	_place_portrait()

func _place_portrait() -> void:
	if preview.sprite_frames == null or preview.animation.is_empty():
		return
	var texture: Texture2D = preview.sprite_frames.get_frame_texture(preview.animation, 0)
	if texture == null:
		return
	var bounds: Rect2 = Rect2(texture.get_image().get_used_rect())
	var factor: float = minf(5, minf(portrait.size.x / maxf(bounds.size.x, 1), portrait.size.y / maxf(bounds.size.y, 1)))
	preview.position = portrait.size * 0.5
	preview.scale = Vector2.ONE * factor
	preview.offset = texture.get_size() * 0.5 - bounds.get_center()

func _fit() -> void:
	var compact: bool = root.size.x < 900 or root.size.y < 500 or MobileLayout.is_touch(get_viewport())
	if compact != _compact:
		_compact = compact
		(%SupplyPanel as PanelContainer).reparent(%WorkContent if compact else %Main)
		(%SupplyContent as VBoxContainer).reparent(%SupplyPanel if compact else %SupplyScroll)
		(%SupplyScroll as ScrollContainer).visible = not compact
	panel.custom_minimum_size = Vector2(minf(1120, maxf(0, root.size.x - 24)), minf(620, maxf(0, root.size.y - 16)))
	(%Shell as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 12)
	(%Page as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 8)
	(%Main as HBoxContainer).add_theme_constant_override("separation", 8 if _compact else 12)
	(%OverviewPanel as PanelContainer).custom_minimum_size.x = 176 if _compact else 240
	(%SupplyPanel as PanelContainer).custom_minimum_size.x = 0 if _compact else 270
	(%Heading as Label).add_theme_font_size_override("font_size", 20 if _compact else 26)
	(%Balance as Label).add_theme_font_size_override("font_size", 14 if _compact else 18)
	(%WorkerName as Label).add_theme_font_size_override("font_size", 16 if _compact else 20)
	(%Wage as Label).add_theme_font_size_override("font_size", 20 if _compact else 26)
	portrait.custom_minimum_size.y = 64 if _compact else 180
	(%TrialNote as Label).visible = not _compact
	(%OverviewContent as VBoxContainer).add_theme_constant_override("separation", 4 if _compact else 12)
	for button: Button in [hire_button, dismiss_button, pause_crop_button, confirm_button, cancel_button]:
		button.add_theme_font_size_override("font_size", 14 if _compact else 18)
	_place_portrait()

func _visit() -> void:
	world = customer.get_parent() as FarmWorld
	status.text = ""
	_cancel_dismiss()
	zones.clear()
	for pen: AnimalPen in world.workers.bridge.pens():
		zones.add_item(PenStatus.title(pen))
		zones.set_item_metadata(zones.item_count - 1, String(pen.persistent_id))
	if not world.workers.changed.is_connected(_refresh):
		world.workers.changed.connect(_refresh)
	if not world.storages.changed.is_connected(_storage_changed):
		world.storages.changed.connect(_storage_changed)
	(%WorkScroll as ScrollContainer).scroll_vertical = 0
	(%OverviewScroll as ScrollContainer).scroll_vertical = 0
	_set_portrait()
	_refresh()
	close_button.grab_focus()

func _storage_changed(_id: String) -> void:
	_refresh()

func _money(value: int) -> String:
	return tr("{coins} coins").format({"coins": GameText.grouped_integer(value)})

func _refresh() -> void:
	if not is_open or world == null:
		return
	var service: WorkerService = world.workers
	var row: Dictionary = service.record(role)
	var employed: bool = not row.is_empty() and bool(row.employed)
	var available: bool = service.available() and not service.busy
	var wage: int = int(WorkerRole.WAGES[role])
	var cost: int = wage if role in service.trial_used else 0
	var title: String = tr(str(TITLES[role]))
	(%Heading as Label).text = title
	(%WorkerName as Label).text = title
	(%Balance as Label).text = _money(customer.wallet.balance)
	(%Wage as Label).text = _money(wage)
	(%HireCost as Label).text = tr("Today's hiring cost: {coins}").format({"coins": _money(cost)}) if not employed else ""
	(%HireCost as Label).visible = not employed
	var paused: bool = role == "crop" and service.crop_automation.paused
	var employment: String = "Not hired" if not employed else ("Resting" if not bool(row.active) else ("Paused" if paused else "Working"))
	(%Employment as Label).text = tr(employment)
	(%Employment as Label).add_theme_color_override("font_color", Color("49663a") if employed and bool(row.active) and not paused else Color("91602b"))
	(%CropOptions as VBoxContainer).visible = role == "crop"
	(%ZoneBox as VBoxContainer).visible = role == "ranch"
	zones.disabled = employed or not available
	if role == "ranch" and employed:
		for index: int in range(zones.item_count):
			if String(zones.get_item_metadata(index)) == row.zone:
				zones.select(index)
	(%RoleDescription as Label).text = tr(str(DESCRIPTIONS[role]))
	var state: CropAutomationState = service.crop_automation
	auto_plant_button.set_pressed_no_signal(state.auto_plant)
	auto_fertilize_button.set_pressed_no_signal(state.auto_fertilize)
	auto_plant_button.text = tr("On" if state.auto_plant else "Off")
	auto_fertilize_button.text = tr("On" if state.auto_fertilize else "Off")
	for button: Button in [auto_plant_button, auto_fertilize_button]:
		button.disabled = not employed or not available
	pause_crop_button.visible = role == "crop" and employed
	pause_crop_button.disabled = not employed or not available
	pause_crop_button.text = tr("Resume work") if paused else tr("Pause work")
	(%PauseNote as Label).visible = role == "crop" and employed
	(%PauseNote as Label).text = tr("Crop work is manually paused. Wages still apply.") if paused else tr("Pausing work does not stop wages.")
	var task: String = _task_text(service, row, employed, paused)
	(%Task as Label).text = task
	var unlock: String = service.unlock_error(role) if not employed else ""
	(%Unlock as Label).text = tr(unlock) if service.available() else tr("Load your farm before hiring workers.")
	(%Unlock as Label).visible = not (%Unlock as Label).text.is_empty()
	hire_button.disabled = employed or not available or not unlock.is_empty() or customer.wallet.balance < cost
	hire_button.text = tr("Already hired") if employed else tr("Hire worker")
	dismiss_button.visible = employed
	dismiss_button.disabled = not available
	_refresh_supplies(service)
	_refresh_legacy(service)
	info.text = "\n".join([title, tr("Daily wage: %d coins · paid at dawn") % wage, tr("First shift is free once per role. Rehiring costs today's wage."), tr("Harvested products go directly to the produce warehouse."), task, (%Supplies as Label).text])
	status.visible = not status.text.is_empty()
	if _confirm:
		confirm_button.disabled = not available or not employed or str(row.get("id", "")) != _dismiss_id
		(%ConfirmationText as Label).text = tr("Dismiss {worker}? The old basket is kept. Rehiring costs today's wage.").format({"worker": title}) + "\n\n" + tr("Today's hiring cost: {coins}").format({"coins": _money(wage)})

func _task_text(service: WorkerService, row: Dictionary, employed: bool, paused: bool) -> String:
	if not employed:
		return tr("Hire a worker to begin.")
	if not bool(row.active):
		return tr("Awaiting wage payment at dawn.")
	if paused:
		return tr("Crop work is manually paused. Wages still apply.")
	if bool(service.bridge.storage_waiting.get(role, false)):
		return tr("Not enough warehouse space for harvest.")
	var task: Dictionary = row.get("task", {})
	if role == "crop" and (task.is_empty() or task.get("kind", "") == "patrol"):
		return tr(service.crop_policy.waiting) if not service.crop_policy.waiting.is_empty() else tr("Waiting for crop work.")
	return tr(str(TASKS.get(task.get("kind", ""), "Working")))

func _refresh_supplies(service: WorkerService) -> void:
	var source: InventoryComponent = world.storages.inventory("farm_supply_storage")
	var seeds: int = 0
	var fertilizer: int = 0
	var feed: Dictionary = {}
	for index: int in range(source.slot_count):
		var stack: Dictionary = source.slot(index)
		var item: ItemDefinition = stack.item as ItemDefinition
		if item == null:
			continue
		if item.item_type == ItemDefinition.ItemType.SEED:
			seeds += int(stack.count)
		elif item.item_type == ItemDefinition.ItemType.BOOSTER and item.booster_kind == ItemDefinition.BoosterKind.FERTILIZER:
			fertilizer += int(stack.count)
		elif item.item_type == ItemDefinition.ItemType.FEED:
			var caption: String = tr(item.display_name)
			feed[caption] = int(feed.get(caption, 0)) + int(stack.count)
	(%SupplyHeading as Label).text = tr("Supply storage") if role != "orchard" else tr("Harvest destination")
	var lines: PackedStringArray = []
	if role == "crop":
		lines.append(tr("Crop seeds: {count}").format({"count": GameText.grouped_integer(seeds)}))
		lines.append(tr("Fertilizer: {count}").format({"count": GameText.grouped_integer(fertilizer)}))
	elif role == "ranch":
		for caption: String in feed:
			lines.append("%s × %d" % [caption, feed[caption]])
		if lines.is_empty():
			lines.append(tr("Empty"))
	(%Supplies as Label).text = "\n".join(lines)
	(%Supplies as Label).visible = role != "crop" and not lines.is_empty()
	(%CropSupplyRows as VBoxContainer).visible = role == "crop"
	(%SeedCount as Label).text = GameText.grouped_integer(seeds)
	(%FertilizerCount as Label).text = GameText.grouped_integer(fertilizer)
	(%SupplyHint as Label).text = tr("Automatically uses any crop seed in supply storage. One seed per successful plot.") if role == "crop" else tr("Feed comes from farm supply storage. Deposit feed at that building.") if role == "ranch" else ""
	(%SupplyHint as Label).visible = not (%SupplyHint as Label).text.is_empty()
	(%Destination as Label).text = tr("Harvested products go directly to the produce warehouse.")
	if bool(service.bridge.storage_waiting.get(role, false)):
		(%Destination as Label).text += "\n" + tr("Not enough warehouse space for harvest.")

func _refresh_legacy(service: WorkerService) -> void:
	var products: int = 0
	var feed: int = 0
	var lines: PackedStringArray = []
	var bag: InventoryComponent = service.bag_for(role)
	if bag != null:
		for index: int in range(bag.slot_count):
			var stack: Dictionary = bag.slot(index)
			if stack.item == null:
				continue
			var item: ItemDefinition = stack.item as ItemDefinition
			if item.item_type == ItemDefinition.ItemType.PRODUCE:
				products += int(stack.count)
			elif item.item_type == ItemDefinition.ItemType.FEED:
				feed += int(stack.count)
			lines.append("%s × %d" % [tr(item.display_name), int(stack.count)])
	collect_button.visible = products > 0
	withdraw_button.visible = feed > 0 and role == "ranch"
	collect_button.disabled = products == 0 or not service.available() or service.busy
	withdraw_button.disabled = feed == 0 or not service.available() or service.busy
	(%LegacyBox as VBoxContainer).visible = collect_button.visible or withdraw_button.visible
	(%LegacyContents as Label).text = "\n".join(lines)

func _hire() -> void:
	if world == null:
		return
	var zone: String = String(zones.get_item_metadata(zones.selected)) if role == "ranch" and zones.selected >= 0 else ""
	var error: String = world.workers.hire(role, zone)
	status.text = tr(error) if not error.is_empty() else tr("Worker hired.")
	_refresh()
	_save.call_deferred()

func _toggle_auto_plant() -> void:
	var state: CropAutomationState = world.workers.crop_automation
	_configure_crop(not state.auto_plant, state.auto_fertilize, state.paused)

func _toggle_auto_fertilize() -> void:
	var state: CropAutomationState = world.workers.crop_automation
	_configure_crop(state.auto_plant, not state.auto_fertilize, state.paused)

func _toggle_crop_pause() -> void:
	var state: CropAutomationState = world.workers.crop_automation
	_configure_crop(state.auto_plant, state.auto_fertilize, not state.paused)

func _configure_crop(plant: bool, fertilizer: bool, pause: bool) -> void:
	if role != "crop" or not world.workers.record(role).get("employed", false) or not world.workers.available():
		return
	status.text = tr(world.workers.configure_crop(plant, fertilizer, pause))
	_refresh()
	_save.call_deferred()

func _dismiss() -> void:
	if not is_open or world == null:
		return
	var row: Dictionary = world.workers.record(role)
	if not _confirm:
		if not row.get("employed", false):
			return
		_confirm = true
		_dismiss_id = str(row.id)
		confirmation.show()
		(%Page as VBoxContainer).hide()
		_refresh()
		cancel_button.grab_focus()
		return
	if not row.get("employed", false) or str(row.get("id", "")) != _dismiss_id:
		return
	status.text = tr(world.workers.dismiss(role))
	_cancel_dismiss()
	_refresh()
	_save.call_deferred()

func _cancel_dismiss() -> void:
	_confirm = false
	_dismiss_id = ""
	confirmation.hide()
	(%Page as VBoxContainer).show()

func close(show_thanks: bool = true) -> void:
	if is_node_ready():
		_cancel_dismiss()
	super.close(show_thanks)

func _deposit() -> void:
	_transfer(true, true)

func _withdraw() -> void:
	_transfer(false, true)

func _collect() -> void:
	_transfer(false, false)

func _transfer(deposit: bool, supplies: bool) -> void:
	var moved: int = world.workers.transfer(role, customer.selection.inventory, deposit, supplies)
	status.text = tr("Transferred: %d units. Anything that does not fit stays in the source basket.") % moved
	_refresh()
	_save.call_deferred()

func _save() -> void:
	var manager: GameSaveManager = get_node_or_null("/root/SaveManager") as GameSaveManager
	if manager != null and manager.adapter != null and manager.adapter.world == world and manager.writes_enabled and not manager.busy:
		await manager.save_game()

func _process(delta: float) -> void:
	if is_open:
		_elapsed += delta
		if _elapsed >= 0.5:
			_elapsed = 0.0
			_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		status.text = ""
		_refresh()
