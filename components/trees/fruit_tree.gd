class_name FruitTree
extends PerennialTree
enum Graft { NONE, YIELD, QUALITY }
var active_graft: int = Graft.NONE
var pending_graft: int = Graft.NONE
var graft_revision: int = 0
var fruit_work: float = 0.0
var _busy: bool = false

func can_water() -> bool:
	return not removed and growth_started_at < 0.0

func water(now: float) -> bool:
	if not can_water():
		return false
	growth_started_at = maxf(last_at, now)
	matures_at = growth_started_at + definition.growth_seconds
	refresh(growth_started_at)
	react()
	return true

func refresh(now: float, fruit_rate: float = 1.0) -> void:
	var until: float = maxf(last_at, now)
	if growth_started_at >= 0.0:
		# Chỉ tính phần thời gian SAU trưởng thành, không tính lại khoảng đã lưu.
		fruit_work = minf(definition.fruit_cycle_seconds, fruit_work + maxf(0.0, until - maxf(last_at, matures_at)) * fruit_rate)
	super.refresh(until)

func has_fruit() -> bool:
	return is_mature() and fruit_work >= definition.fruit_cycle_seconds

func harvest_item() -> ItemDefinition:
	return definition.star_harvest_item if active_graft == Graft.QUALITY else definition.harvest_item

func harvest_amount() -> int:
	return definition.harvest_amount * (2 if active_graft == Graft.YIELD else 1)

static func graft_name(value: int) -> String:
	return TranslationServer.translate(["Not specialized", "Yield", "Selection (Star fruit)"][clampi(value, 0, 2)])

func harvest(bag: InventoryComponent) -> bool:
	if _busy or bag == null or not has_fruit():
		return false
	var item: ItemDefinition = harvest_item()
	var amount: int = harvest_amount()
	if item == null or bag.capacity_for(item) < amount:
		bag.report_capacity_blocked(item, amount)
		return false
	_busy = true
	var height: float = float(visible_bounds(sprite.texture).size.y) * 0.6 if sprite != null else 24.0
	fruit_work = 0.0
	if pending_graft != Graft.NONE:
		active_graft = pending_graft
		pending_graft = Graft.NONE
		graft_revision += 1
	# The old batch and next direction both commit before any inventory observer.
	bag.add(item, amount)
	update_visual()
	react()
	if plantation != null:
		plantation.harvest_yielded.emit(item, amount, global_position - Vector2(0, height), bag, height)
	_busy = false
	return true

func uproot(bag: InventoryComponent) -> bool:
	if _busy or removed or bag == null:
		return false
	var sapling: ItemDefinition = definition.planting_item()
	if bag.capacity_for(sapling) < 1:
		bag.report_capacity_blocked(sapling, 1)
		return false
	_busy = true
	retire()
	bag.add(sapling, 1)
	_busy = false
	return true

func update_visual() -> void:
	if sprite != null and definition != null:
		set_texture(definition.ready_texture if has_fruit() else definition.stage_textures[stage])

func action_text(item: ItemDefinition) -> String:
	if is_mature():
		return tr("Manage fruit tree") + (" · " + tr("Choose a graft direction") if active_graft == Graft.NONE and pending_graft == Graft.NONE else "")
	if item != null and item.item_type == ItemDefinition.ItemType.TOOL and item.tool_type == ItemDefinition.ToolType.HOE:
		return tr("Uproot tree (return sapling)")
	if can_water():
		return tr("Water sapling to start growth")
	return tr("Harvest fruit") if has_fruit() else tr("{tree} · growing").format({"tree": tr(definition.display_name)})

func capture() -> Dictionary:
	var row: Dictionary = super.capture()
	row["fruit_work"] = fruit_work
	row["active_graft"] = active_graft
	row["pending_graft"] = pending_graft
	row["graft_revision"] = graft_revision
	return row

func restore_state(row: Dictionary) -> void:
	fruit_work = float(row.fruit_work)
	active_graft = int(row.get("active_graft", Graft.NONE))
	pending_graft = int(row.get("pending_graft", Graft.NONE))
	graft_revision = int(row.get("graft_revision", 0))
	super.restore_state(row)
