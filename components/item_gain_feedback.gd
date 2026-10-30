class_name ItemGainFeedback
extends Node2D
## Presentation subscriber: purchases/loads never masquerade as harvested items.
var player: FarmPlayer
var collector: ItemCollector
var _popups: Array[ItemGainPopup] = []
var _recent: Dictionary[StringName, WeakRef] = {}
var _lane: int = 0
var _bursts: Array[HarvestBurst] = []
var _last_capacity_notice: int = -1500

func _ready() -> void:
	collector.item_acquired.connect(_on_pickup)
	player.selection.inventory.capacity_blocked.connect(_on_capacity_blocked)
	if player.state.flower_interaction != null:
		player.state.flower_interaction.harvest_yielded.connect(_on_flower_harvest)
	var farming: FarmingController = player.farming_actions.get_farming_controller()
	if farming != null:
		farming.quality_harvest_yielded.connect(_on_quality_harvest)
		farming.harvest_yielded.connect(_on_legacy_harvest)
	var world: FarmWorld = player.get_parent() as FarmWorld
	if world != null and world.trees != null:
		world.trees.harvest_yielded.connect(_on_harvest)

# Nhiều đống đồ có thể báo đầy trong cùng một frame. Dùng đồng hồ đếm mili giây của phiên,
# không dùng Unix/timestamp lớn cây, để giới hạn thông báo mỗi 1,5 giây không bị chỉnh giờ ảnh hưởng.
# Bỏ giới hạn vẫn giữ đúng đồ nhưng có thể phủ kín màn hình bằng cùng một cảnh báo.
func _on_capacity_blocked(item: ItemDefinition, _requested: int, available: int) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_capacity_notice < 1500:
		return
	_last_capacity_notice = now
	var text: String = "Inventory full" if available == 0 else "Not enough inventory space"
	_spawn(item, 0, self, Vector2(0, -64), text)

# Chỉ nghe sự kiện nhận đồ thực, không nghe mọi inventory.changed: mua hàng/load cũng đổi túi.
# Nếu dùng changed để tạo +N, mua hoặc tải save có thể hiện thưởng nhặt giả.
# Gộp cùng item trong 0,15 giây chỉ gộp thông báo, không gộp/thực hiện lại giao dịch inventory.
# WeakRef tránh giữ một popup đã hết vòng đời; cửa sổ gộp và giới hạn popup chỉ là lựa chọn UI.
func _on_pickup(item: ItemDefinition, amount: int) -> void:
	if item == null or amount <= 0:
		return
	var reference: WeakRef = _recent.get(item.item_id) as WeakRef
	var existing: ItemGainPopup = reference.get_ref() as ItemGainPopup if reference != null else null
	if is_instance_valid(existing) and not existing.is_queued_for_deletion() and existing.age < 0.15:
		existing.add_amount(amount)
		return
	var popup: ItemGainPopup = _spawn(item, amount, self, Vector2((_lane % 3 - 1) * 8, -34 - (_lane % 3) * 9))
	_recent[item.item_id] = weakref(popup)
	_lane += 1

func _on_flower_harvest(item: ItemDefinition, amount: int, at: Vector2, inventory: InventoryComponent, host: Node2D) -> void:
	if inventory != player.selection.inventory or item == null or amount <= 0 or not is_instance_valid(host):
		return
	var popup: ItemGainPopup = _spawn(item, amount, host, Vector2.ZERO)
	popup.place_world(at)

func _on_harvest(item: ItemDefinition, amount: int, at: Vector2, inventory: InventoryComponent, drop_height: float = 0.0, tier: int = 0) -> void:
	if inventory != player.selection.inventory or item == null or amount <= 0:
		return
	# Harvesting while picking up eggs must not stack two rewards on one line.
	for previous: ItemGainPopup in _popups:
		if is_instance_valid(previous) and previous.get_parent() == self and absf(previous.global_position.x - at.x) < 64.0 and absf(previous.global_position.y - at.y) < 28.0:
			previous.shift_up(maxf(0.0, previous.global_position.y - at.y + 28.0))
	var host: Node = player.farming_actions.farming.get_parent()
	var popup: ItemGainPopup = _spawn(item, amount, host, Vector2.ZERO)
	popup.modulate = ItemQuality.color(tier)
	popup.place_world(at)
	# Let the produce leave the soil before drawing text over the same pixels.
	popup.start_after(0.3)
	var active: Array[HarvestBurst] = []
	for previous: HarvestBurst in _bursts:
		if is_instance_valid(previous) and not previous.is_queued_for_deletion():
			active.append(previous)
	_bursts = active
	if _bursts.size() >= 8:
		_bursts.pop_front().queue_free()
	var burst: HarvestBurst = HarvestBurst.new()
	burst.tier = tier
	burst.item = item
	burst.amount = amount
	burst.drop_height = drop_height
	burst.target = weakref(player)
	host.add_child(burst)
	burst.global_position = at
	burst.global_scale = Vector2.ONE
	_bursts.append(burst)

func _spawn(item: ItemDefinition, amount: int, host: Node, at: Vector2, message: String = "") -> ItemGainPopup:
	var active: Array[ItemGainPopup] = []
	for previous: ItemGainPopup in _popups:
		if is_instance_valid(previous) and not previous.is_queued_for_deletion():
			active.append(previous)
	_popups = active
	if _popups.size() >= 12:
		_popups.pop_front().queue_free()
	var popup: ItemGainPopup = ItemGainPopup.new()
	popup.item = item
	popup.amount = amount
	popup.message = message
	popup.position = at
	host.add_child(popup)
	_popups.append(popup)
	return popup

func clear() -> void:
	for burst: HarvestBurst in _bursts:
		if is_instance_valid(burst):
			burst.queue_free()
	_bursts.clear()
	for popup: ItemGainPopup in _popups:
		if is_instance_valid(popup):
			popup.queue_free()
	_popups.clear()
	_recent.clear()
	_last_capacity_notice = -1500

func _on_quality_harvest(item: ItemDefinition, amount: int, at: Vector2, inventory: InventoryComponent, tier: int) -> void:
	_on_harvest(item, amount, at, inventory, 0.0, tier)

func _on_legacy_harvest(item: ItemDefinition, amount: int, at: Vector2, inventory: InventoryComponent) -> void:
	# Crops have their dedicated event; honey still uses the original event.
	if item.resource_path.begins_with("res://items/honey/"):
		_on_harvest(item, amount, at, inventory)
