class_name TimberTree
extends PerennialTree
var hits: int = 0
var stump: bool = false
var root_hits: int = 0
var regrow_at: float = 0.0
var _busy: bool = false

func initialize(now: float) -> void:
	super.initialize(now)
	growth_started_at = now
	matures_at = now + definition.growth_seconds

func refresh(now: float, fruit_rate: float = 1.0) -> void:
	if stump and maxf(now, last_at) >= regrow_at:
		stump = false
		hits = 0
		root_hits = 0
		growth_started_at = regrow_at
		matures_at = regrow_at + definition.growth_seconds * 0.5
		regrow_at = 0.0
	super.refresh(now, fruit_rate)

func chop(bag: InventoryComponent) -> bool:
	if _busy or removed or stump or not is_mature() or bag == null:
		return false
	_busy = true
	hits += 1
	react()
	_leaves()
	if hits >= definition.chop_hits:
		# Commit gốc trước các signal inventory: không thể nhận gỗ hai lần.
		stump = true
		root_hits = 0
		regrow_at = last_at + definition.stump_seconds
		_fall()
		update_visual()
		var accepted: int = _reward(bag, definition.harvest_item, definition.harvest_amount)
		accepted += _reward(bag, definition.planting_item(), 1)
		if accepted > 0:
			bag.changed.emit()
	_busy = false
	return true

func dig(bag: InventoryComponent) -> bool:
	if not stump:
		return uproot(bag)
	if _busy or removed or bag == null:
		return false
	_busy = true
	root_hits += 1
	react()
	if root_hits >= definition.dig_hits:
		retire()
		if _reward(bag, definition.root_item, 2) > 0:
			bag.changed.emit()
	_busy = false
	return true

func _reward(bag: InventoryComponent, item: ItemDefinition, amount: int) -> int:
	# Đốn cây cho nhiều loại đồ; phần túi không chứa được phải nằm trên đất.
	var accepted: int = bag.add(item, mini(amount, bag.capacity_for(item)), 0, false)
	if accepted < amount and plantation != null:
		plantation.drop_item(item, amount - accepted, global_position + Vector2(12, 8))
	return accepted

func update_visual() -> void:
	if sprite != null and definition != null:
		set_texture(definition.stump_texture if stump else definition.stage_textures[stage])

func _leaves() -> void:
	if not is_inside_tree() or definition.leaf_texture == null:
		return
	var leaves: CPUParticles2D = CPUParticles2D.new()
	leaves.texture = definition.leaf_texture
	leaves.amount = 6
	leaves.lifetime = 0.7
	leaves.one_shot = true
	leaves.direction = Vector2(0, -1)
	leaves.spread = 85.0
	leaves.initial_velocity_min = 12.0
	leaves.initial_velocity_max = 28.0
	leaves.gravity = Vector2(0, 60)
	leaves.position = Vector2(0, -30)
	add_child(leaves)
	leaves.finished.connect(leaves.queue_free)
	leaves.emitting = true

func _fall() -> void:
	if not is_inside_tree():
		return
	var canopy: Sprite2D = Sprite2D.new()
	canopy.texture = definition.canopy_texture
	canopy.offset.y = -canopy.texture.get_height() * 0.5
	add_child(canopy)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(canopy, "rotation", 1.4, 0.4)
	tween.tween_property(canopy, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(canopy.queue_free)

func action_text(_item: ItemDefinition) -> String:
	return tr("Hoe: dig stump (1 hit)") if stump else tr("Axe: chop tree ({hits}/{total})").format({"hits": hits, "total": definition.chop_hits}) if is_mature() else tr("Uproot tree (return sapling)") if _item != null and _item.tool_type == ItemDefinition.ToolType.HOE else tr("{tree} · growing").format({"tree": tr(definition.display_name)})

func capture() -> Dictionary:
	var row: Dictionary = super.capture()
	row.merge({"hits": hits, "stump": stump, "root_hits": root_hits, "regrow_at": regrow_at})
	return row

func restore_state(row: Dictionary) -> void:
	hits = int(row.hits)
	stump = bool(row.stump)
	root_hits = int(row.root_hits)
	regrow_at = float(row.regrow_at)
	super.restore_state(row)

func uproot(bag: InventoryComponent) -> bool:
	if _busy or removed or stump or is_mature() or bag == null:
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
