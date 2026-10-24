class_name TutorialProgress
extends RefCounted
## Presentation preferences only. Gameplay completion belongs to ObjectiveProgress.
signal changed
var _data: Dictionary = TutorialSaveSchema.fresh()
var _busy: bool = false

func capture() -> Dictionary:
	return _data.duplicate(true)

func restore(data: Dictionary) -> bool:
	if _busy or not TutorialSaveSchema.valid(data):
		return false
	_busy = true
	_data = data.duplicate(true)
	changed.emit()
	_busy = false
	return true

func set_enabled(value: bool) -> void:
	if _busy:
		return
	_data.enabled = value
	if value:
		_data.skipped = false
	changed.emit()

func skip() -> void:
	if _busy:
		return
	_data.enabled = false
	_data.skipped = true
	changed.emit()

func seen(id: String) -> bool:
	return _data.seen.has(id)

func mark_seen(id: String) -> void:
	if _busy or seen(id) or not TutorialSaveSchema.known(id):
		return
	_data.seen.append(id)
	changed.emit()

func grant_support(bag: InventoryComponent, seed_item: ItemDefinition) -> bool:
	if _busy or _data.support_used or bag.capacity_for(seed_item) < 1:
		return false
	_busy = true
	_data.support_used = true
	var accepted: int = bag.add(seed_item, 1)
	if accepted != 1:
		_data.support_used = false
	changed.emit()
	_busy = false
	return accepted == 1
