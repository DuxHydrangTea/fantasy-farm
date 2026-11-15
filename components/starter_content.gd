class_name StarterContent
extends RefCounted
## Điều phối trạng thái nội dung khởi đầu và mở vườn hoa một lần trong runtime.
## Các preview được thiết kế trong editor được giữ riêng khỏi khởi tạo game.

## Thế giới chứa đất, chuồng ao và vườn hoa.
var world: FarmWorld
## Cho biết phần thưởng mở vườn hoa đã được kích hoạt.
var flower_garden_unlocked: bool = false
var _restoring: bool = false

func _init(farm: FarmWorld) -> void:
	world = farm

## Xóa actor preview trong chuồng ao và khóa các vườn trước khi bắt đầu runtime.
func prepare() -> void:
	for child: Node in world.get_children():
		if child is PondPen:
			for actor: Node in child.get_children():
				if actor is AnimalActor:
					actor.free()
		if child is FlowerGarden:
			(child as FlowerGarden).starter_content_locked = true

## Theo dõi thay đổi đất, áp khóa hiện tại và kiểm tra điều kiện mở.
func setup() -> void:
	world.land.state.changed.connect(refresh)
	_apply_lock()
	refresh()

## Mở vườn và khôi phục vật tư khởi đầu một lần sau khi mua thêm đất.
## Cờ mở được ghi trước khi tạo pickup để callback lưu thấy trạng thái nhất quán.
func refresh() -> void:
	if _restoring or flower_garden_unlocked or world.land.state.unlocked_blocks <= world.land.state.starting_blocks:
		return
	# Commit before adding pickups: inventory/save callbacks must see the reward claimed.
	flower_garden_unlocked = true
	_apply_lock()
	for garden: FlowerGarden in _gardens():
		garden.starter_flowers_added = true
		garden.restore_initial_supplies()

## Tạm ngưng kiểm tra tự động và áp trạng thái mở từ dữ liệu lưu.
func begin_restore(unlocked: bool) -> void:
	_restoring = true
	flower_garden_unlocked = unlocked
	_apply_lock()

## Kết thúc khôi phục và kiểm tra lại điều kiện mở.
func finish_restore() -> void:
	_restoring = false
	refresh()

func _apply_lock() -> void:
	for garden: FlowerGarden in _gardens():
		garden.set_starter_content_locked(not flower_garden_unlocked)

func _gardens() -> Array[FlowerGarden]:
	var result: Array[FlowerGarden] = []
	for child: Node in world.get_children():
		if child is FlowerGarden:
			result.append(child as FlowerGarden)
	return result
