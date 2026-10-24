class_name ObjectiveProgress
extends RefCounted
## Sequential objective state and atomic coin claims, independent of scenes/UI.
signal changed
signal restored
const DEFAULT_CATALOG: ObjectiveCatalog = preload("res://resources/objectives/onboarding.tres")
var catalog: ObjectiveCatalog
var wallet: WalletComponent
var state_query: Callable
var suspended: bool = false
var tracked_id: String = ""
var hud_collapsed: bool = false
var _rows: Array = []
var _busy: bool = false

func _init(purse: WalletComponent, query: Callable = Callable(), definitions: ObjectiveCatalog = DEFAULT_CATALOG) -> void:
	assert(definitions != null and definitions.is_valid(), "Invalid objective catalog")
	wallet = purse
	state_query = query
	catalog = definitions
	_rows = ObjectiveSaveSchema.fresh(catalog).steps

func active_index() -> int:
	for index: int in range(_rows.size()):
		if not _rows[index].claimed:
			return index
	return -1

func active() -> ObjectiveDefinition:
	var index: int = active_index()
	return catalog.steps[index] if index >= 0 else null

func progress() -> int:
	var index: int = active_index()
	return int(_rows[index].progress) if index >= 0 else 0

func ready_to_claim() -> bool:
	var step: ObjectiveDefinition = active()
	return step != null and progress() == step.required

func record(condition: StringName, amount: int = 1) -> void:
	var step: ObjectiveDefinition = active()
	if suspended or _busy or step == null or step.state_condition or step.condition != condition or amount <= 0 or ready_to_claim():
		return
	_rows[active_index()].progress = progress() + mini(amount, step.required - progress())
	changed.emit()

func _refresh_active() -> bool:
	var step: ObjectiveDefinition = active()
	if step == null or not step.state_condition or not state_query.is_valid():
		return false
	var value: int = clampi(int(state_query.call(step.condition)), 0, step.required)
	if value <= progress():
		return false
	_rows[active_index()].progress = value
	return true

func refresh_state() -> void:
	if not suspended and not _busy and _refresh_active():
		changed.emit()

func claim(id: StringName) -> Dictionary:
	var step: ObjectiveDefinition = active()
	if suspended or _busy or step == null or step.objective_id != id or not ready_to_claim():
		return {"ok": false, "error": "This objective is not ready to claim."}
	if not is_instance_valid(wallet) or step.reward_coins > WalletComponent.MAX_COINS - wallet.balance:
		return {"ok": false, "error": "Your wallet has reached its coin limit."}
	_busy = true
	# Observers/saves must see the credited wallet and claimed flag together.
	wallet.set_balance(wallet.balance + step.reward_coins, false)
	_rows[active_index()].claimed = true
	if tracked_id == String(id):
		tracked_id = ""
	_refresh_active()
	wallet.changed.emit(wallet.balance)
	changed.emit()
	_busy = false
	return {"ok": true, "coins": step.reward_coins}

func capture() -> Dictionary:
	return {"steps": _rows.duplicate(true), "tracked_id": tracked_id, "hud_collapsed": hud_collapsed}

func track(id: String) -> void:
	if suspended or _busy:
		return
	for definition: ObjectiveDefinition in catalog.steps:
		if String(definition.objective_id) == id:
			tracked_id = id
			changed.emit()
			return

func set_collapsed(value: bool) -> void:
	if suspended or _busy or hud_collapsed == value:
		return
	hud_collapsed = value
	changed.emit()

func tracked_index() -> int:
	for index: int in range(catalog.steps.size()):
		if String(catalog.steps[index].objective_id) == tracked_id:
			return index
	return active_index()

func restore(data: Dictionary) -> bool:
	if _busy or not ObjectiveSaveSchema.valid(data, catalog):
		return false
	_rows = data.steps.duplicate(true)
	tracked_id = data.tracked_id
	hud_collapsed = data.hud_collapsed
	for row: Dictionary in _rows:
		row.progress = int(row.progress)
	_refresh_active()
	if not suspended:
		restored.emit()
		changed.emit()
	return true
