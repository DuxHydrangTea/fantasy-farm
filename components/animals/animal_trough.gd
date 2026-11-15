class_name AnimalTrough
extends StaticBody2D
## Máng thức ăn hoặc nước có sức chứa hữu hạn và các vị trí phục vụ có giữ chỗ.
## Đồng bộ thời gian chuồng trước khi thay đổi tồn kho để mô phỏng offline
## không dùng nguồn cung mới cho khoảng thời gian trước đó.

## Sprite thể hiện máng đầy hoặc rỗng.
@export var sprite: Sprite2D
## Mã ổn định trong dữ liệu lưu.
@export var persistent_id: StringName
## Loại nguồn cung của máng.
enum Kind { FOOD, WATER }
## Phát số lượng tồn nguyên khi thay đổi.
signal stock_changed(amount: int)
## Phần lẻ của đơn vị tồn cuối đã tiêu bởi mô phỏng offline.
var consumed_fraction: float = 0.0
## Loại máng hiện tại.
@export var kind: Kind = Kind.WATER
## Chuồng sở hữu máng.
@export var pen: AnimalPen
## Sức chứa tối đa theo đơn vị nguồn cung.
@export_range(1, 32000) var capacity: int = 120
## Số đơn vị nguyên hiển thị, được kẹp trong sức chứa.
@export_range(0, 32000) var stock: int = 120:
	set(value):
		stock = clampi(value, 0, capacity)
		if stock == 0:
			consumed_fraction = 0.0
		stock_changed.emit(stock)
		if is_node_ready():
			_update_visual()
## Lượng nhu cầu phục hồi từ một đơn vị.
@export_range(1.0, 100.0) var restoration_per_unit: float = 40.0
## Thời gian dùng một khẩu phần tính bằng giây.
@export_range(0.05, 10.0) var serving_seconds: float = 1.5
## Các loài được phép dùng; mảng rỗng cho phép mọi loài.
@export var allowed_species: Array[int] = []
## Các vị trí tiếp cận tương đối với máng.
@export var access_offsets: Array[Vector2] = [Vector2(-9, 12), Vector2(9, 12), Vector2(-9, -12), Vector2(9, -12), Vector2(-24, 0), Vector2(24, 0)]
## Ảnh máng có nguồn cung.
@export var full_texture: Texture2D
## Ảnh máng trống.
@export var empty_texture: Texture2D
@export_group("Player Refilling")
## Vật phẩm thức ăn dùng để nạp máng.
@export var feed_item: ItemDefinition
## Số đơn vị nước thêm mỗi lần dùng.
@export_range(1, 32000) var water_per_use: int = 30
var _occupants: Dictionary[int, WeakRef] = {}
var _refilling: bool = false
## Thức ăn dư từ gói đã mở, dùng cho lần nạp sau.
var feed_reserve: int = 0

## Số gói nguyên có thể nạp vừa vào chỗ trống và hiện có trong inventory.
func feed_items_needed(inventory: InventoryComponent) -> int:
	if kind != Kind.FOOD or inventory == null or feed_item == null or feed_item.item_type != ItemDefinition.ItemType.FEED:
		return 0
	var units: int = maxi(1, feed_item.food_units_per_item)
	return mini(floori(float(maxi(0, capacity - stock)) / units), inventory.count_item(feed_item.item_id))

## Đồng bộ chuồng rồi nạp các gói nguyên vừa chỗ, trả số đơn vị thêm.
func refill_from_inventory(inventory: InventoryComponent) -> int:
	_sync_pen()
	if _refilling:
		return 0
	var packages: int = feed_items_needed(inventory)
	if packages <= 0:
		return 0
	_refilling = true
	var removed: int = inventory.remove(feed_item.item_id, packages)
	var added: int = refill(removed * maxi(1, feed_item.food_units_per_item))
	_refilling = false
	return added

func _ready() -> void:
	if pen == null:
		pen = get_parent() as AnimalPen
	stock = stock
	add_to_group(&"animal_troughs")
	_update_visual()

## Số đơn vị một khẩu phần theo loài và loại máng, tối thiểu 1.
func portion_size(data: AnimalDefinition) -> int:
	return maxi(1, data.food_per_meal if kind == Kind.FOOD else data.water_per_drink)

## Kiểm tra nguồn cung, khẩu phần và loài được phép.
func can_supply(data: AnimalDefinition) -> bool:
	return data != null and restoration_per_unit > 0.0 and available_units() >= portion_size(data) and (allowed_species.is_empty() or int(data.species) in allowed_species)

## Tồn khả dụng thực tế sau khi trừ phần lẻ đã tiêu offline.
func available_units() -> float:
	return maxf(0.0, float(stock) - consumed_fraction)

## Khôi phục số đơn vị có thể lẻ bằng tồn nguyên và phần đã tiêu.
func restore_offline_stock(units: float) -> void:
	units = clampf(units, 0.0, float(capacity))
	var whole: int = ceili(units)
	stock = whole
	consumed_fraction = maxf(0.0, float(whole) - units)

func _sync_pen() -> void:
	if pen == null:
		return
	for child: Node in pen.get_children():
		if child is AnimalActor and not child.is_queued_for_deletion():
			var clock: FarmClock = (child as AnimalActor).needs.time_manager
			if clock != null:
				pen.sync_before_change(clock.now())
				return

## Vị trí tiếp cận toàn cục của slot hợp lệ.
func access_position(slot: int) -> Vector2:
	return to_global(access_offsets[slot])

## Kiểm tra slot trống hoặc đã thuộc chính con vật, dọn tham chiếu hết hiệu lực.
func slot_available(slot: int, animal: Node2D = null) -> bool:
	if slot < 0 or slot >= access_offsets.size():
		return false
	var reference: WeakRef = _occupants.get(slot)
	var occupant: Object = reference.get_ref() if reference != null else null
	if not is_instance_valid(occupant) or (occupant is Node and not (occupant as Node).is_inside_tree()):
		_occupants.erase(slot)
		return true
	return occupant == animal

# Đặt chỗ ở máng để hai con không cùng chọn một vị trí phục vụ. Chưa trừ thức ăn ở bước này.
# Tham chiếu yếu cho phép dọn chỗ khi con vật bị xóa; cancel/exit cũng phải trả chỗ.
# Bỏ đặt chỗ làm nhiều con chồng vào nhau; bỏ trả chỗ làm một vị trí bị giữ mãi dù con vật đã đi.
## Giữ một slot cho con vật còn hợp lệ nếu máng còn phục vụ được.
## Chưa trừ nguồn cung tại bước này.
func claim(animal: Node2D, slot: int, data: AnimalDefinition) -> bool:
	if not is_instance_valid(animal) or not animal.is_inside_tree() or not can_supply(data) or not slot_available(slot, animal):
		return false
	_occupants[slot] = weakref(animal)
	return true

## Kiểm tra con vật đang giữ slot.
func owns_slot(animal: Node2D, slot: int) -> bool:
	var reference: WeakRef = _occupants.get(slot)
	return reference != null and reference.get_ref() == animal

## Nhả mọi slot của con vật và các tham chiếu đã hết hiệu lực.
func release(animal: Node2D) -> void:
	for slot: int in _occupants.keys():
		var reference: WeakRef = _occupants[slot]
		if reference.get_ref() == null or reference.get_ref() == animal:
			_occupants.erase(slot)

## Phục vụ con vật đã giữ slot và đến gần điểm tiếp cận.
## Chỉ trừ khẩu phần nếu độ no hoặc nước thực sự tăng; trả mức tăng thực tế.
# Chỉ phục vụ khi còn phần ăn đúng loài, con vật sở hữu chỗ và đã đến gần điểm phục vụ.
# Chỉ trừ kho nếu no/nước thực sự tăng. Không được trừ ngay lúc bắt đầu đi tới máng:
# con vật có thể bị chắn, máng có thể bị dời/xóa hoặc con vật bị hủy giữa đường.
# Nếu bỏ kiểm tra khoảng cách/quyền chỗ, vật nuôi có thể ăn từ xa hoặc tranh cùng phần cuối.
## Phục vụ vật nuôi tại vị trí hợp lệ và trả lượng đã cấp sau khi đồng bộ chuồng.
func serve(animal: Node2D, needs: AnimalNeedsComponent, data: AnimalDefinition, slot: int) -> float:
	_sync_pen()
	if not is_instance_valid(animal) or not is_instance_valid(needs) or not can_supply(data) or not owns_slot(animal, slot):
		return 0.0
	if slot < 0 or slot >= access_offsets.size() or animal.global_position.distance_to(access_position(slot)) > 3.0:
		return 0.0
	var units: int = portion_size(data)
	var amount: float = restoration_per_unit * units
	var restored: float = needs.feed(amount) if kind == Kind.FOOD else needs.drink(amount)
	if restored > 0.0:
		stock -= units
	return restored

## Đồng bộ chuồng rồi thêm số đơn vị không âm trong sức chứa, trả số thực thêm.
func refill(units: int) -> int:
	_sync_pen()
	var before: int = stock
	stock += maxi(0, units)
	return stock - before

func _update_visual() -> void:
	if sprite != null:
		sprite.texture = full_texture if stock > 0 else empty_texture

## Kiểm tra máng thức ăn còn chỗ và có gói hoặc thức ăn dư để nạp.
func can_refill_to_full(inventory: InventoryComponent) -> bool:
	if _refilling or kind != Kind.FOOD or inventory == null or feed_item == null or feed_item.item_type != ItemDefinition.ItemType.FEED or stock >= capacity:
		return false
	return feed_reserve > 0 or inventory.count_item(feed_item.item_id) > 0

## Nạp tối đa đến đầy, giữ phần dư từ gói trong feed_reserve và trả số đã thêm.
func refill_to_full(inventory: InventoryComponent) -> int:
	_sync_pen()
	if not can_refill_to_full(inventory):
		return 0
	var units: int = maxi(1, feed_item.food_units_per_item)
	var needed: int = ceili(float(maxi(0, capacity - stock - feed_reserve)) / units)
	var packages: int = mini(needed, inventory.count_item(feed_item.item_id))
	if packages == 0 and feed_reserve == 0:
		return 0
	_refilling = true
	# Silence the bag until stock and the retained remainder are also committed.
	var removed: int = inventory.remove(feed_item.item_id, packages, false)
	var available: int = feed_reserve + removed * units
	var added: int = mini(capacity - stock, available)
	feed_reserve = available - added
	stock += added
	if removed > 0:
		inventory.changed.emit()
	_refilling = false
	return added
