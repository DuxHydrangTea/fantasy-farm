class_name FruitTree
extends PerennialTree
## Cây ăn quả lâu năm, cần được tưới để bắt đầu lớn và tạo quả theo chu kỳ.
## Hướng ghép đang chờ được áp dụng sau khi thu mẻ hiện tại.

## Các hướng ghép: chưa chọn, tăng sản lượng hoặc quả chất lượng sao.
enum Graft { NONE, YIELD, QUALITY }
## Hướng ghép áp dụng cho mẻ hiện tại.
var active_graft: int = Graft.NONE
## Hướng ghép sẽ áp dụng sau khi thu mẻ hiện tại.
var pending_graft: int = Graft.NONE
## Revision tăng khi lựa chọn hoặc trạng thái ghép thay đổi.
var graft_revision: int = 0
## Công việc tích lũy của chu kỳ quả hiện tại.
var fruit_work: float = 0.0
var _busy: bool = false

## Kiểm tra cây còn tồn tại và chưa bắt đầu sinh trưởng.
func can_water() -> bool:
	return not removed and growth_started_at < 0.0

## Bắt đầu sinh trưởng tại mốc không sớm hơn lần cập nhật gần nhất.
func water(now: float) -> bool:
	if not can_water():
		return false
	growth_started_at = maxf(last_at, now)
	matures_at = growth_started_at + definition.growth_seconds
	refresh(growth_started_at)
	react()
	return true

## Cập nhật sinh trưởng và tích lũy quả chỉ cho phần thời gian sau trưởng thành.
func refresh(now: float, fruit_rate: float = 1.0) -> void:
	var until: float = maxf(last_at, now)
	if growth_started_at >= 0.0:
		# Chỉ tính phần thời gian SAU trưởng thành, không tính lại khoảng đã lưu.
		fruit_work = minf(definition.fruit_cycle_seconds, fruit_work + maxf(0.0, until - maxf(last_at, matures_at)) * fruit_rate)
	super.refresh(until)

## Kiểm tra cây trưởng thành và chu kỳ quả đã hoàn thành.
func has_fruit() -> bool:
	return is_mature() and fruit_work >= definition.fruit_cycle_seconds

## Vật phẩm thu hoạch theo hướng ghép đang hoạt động.
func harvest_item() -> ItemDefinition:
	return definition.star_harvest_item if active_graft == Graft.QUALITY else definition.harvest_item

## Số lượng thu hoạch, gấp đôi khi ghép tăng sản lượng.
func harvest_amount() -> int:
	return definition.harvest_amount * (2 if active_graft == Graft.YIELD else 1)

## Tên hướng ghép đã dịch, giá trị ngoài miền được kẹp.
static func graft_name(value: int) -> String:
	return TranslationServer.translate(["Not specialized", "Yield", "Selection (Star fruit)"][clampi(value, 0, 2)])

## Thu toàn bộ mẻ vào túi nếu đủ chỗ, sau đó áp dụng hướng ghép đang chờ.
## Trả false nếu cây bận, chưa có quả hoặc túi không nhận đủ mẻ.
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

## Nhổ bỏ cây ăn quả mà không hoàn lại cây giống.
func uproot(_bag: InventoryComponent = null) -> bool:
	if _busy or removed:
		return false
	_busy = true
	retire()
	_busy = false
	return true

## Cập nhật ảnh theo giai đoạn hoặc trạng thái có quả.
func update_visual() -> void:
	if sprite != null and definition != null:
		set_texture(definition.ready_texture if has_fruit() else definition.stage_textures[stage])

## Tạo nhãn hành động đã dịch theo tuổi cây và công cụ đang chọn.
func action_text(item: ItemDefinition) -> String:
	if is_mature():
		return tr("Manage fruit tree") + (" · " + tr("Choose a graft direction") if active_graft == Graft.NONE and pending_graft == Graft.NONE else "")
	if item != null and item.item_type == ItemDefinition.ItemType.TOOL and item.tool_type == ItemDefinition.ToolType.HOE:
		return tr("Uproot tree")
	if can_water():
		return tr("Water sapling to start growth")
	return tr("Harvest fruit") if has_fruit() else tr("{tree} · growing").format({"tree": tr(definition.display_name)})

## Thêm tiến độ quả và trạng thái ghép vào dữ liệu lưu cơ sở.
func capture() -> Dictionary:
	var row: Dictionary = super.capture()
	row["fruit_work"] = fruit_work
	row["active_graft"] = active_graft
	row["pending_graft"] = pending_graft
	row["graft_revision"] = graft_revision
	return row

## Khôi phục tiến độ quả và trạng thái ghép từ bản ghi đã kiểm tra.
func restore_state(row: Dictionary) -> void:
	fruit_work = float(row.fruit_work)
	active_graft = int(row.get("active_graft", Graft.NONE))
	pending_graft = int(row.get("pending_graft", Graft.NONE))
	graft_revision = int(row.get("graft_revision", 0))
	super.restore_state(row)
