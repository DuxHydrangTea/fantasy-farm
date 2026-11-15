extends RefCounted
## Bộ đệm sản phẩm dùng chung với sức chứa hữu hạn.
## Hệ thống sản xuất xử lý lượng vượt sức chứa. Lấy hàng thất bại giữ hàng lại.

## Phát khi nội dung bộ đệm thay đổi.
signal changed
## Sức chứa mặc định tính theo tổng số đơn vị sản phẩm.
const DEFAULT_CAPACITY: int = 3000
## Tổng số đơn vị có thể chứa.
var capacity: int = DEFAULT_CAPACITY
## Ánh xạ mã vật phẩm sang bản ghi gồm resource item và số lượng amount.
var products: Dictionary = {}
var _collecting: bool = false

## Tính tổng số đơn vị của tất cả các loại sản phẩm.
func count() -> int:
	var total: int = 0
	for row: Dictionary in products.values():
		total += int(row.amount)
	return total

## Số chỗ trống còn lại, tối thiểu bằng 0.
func free_space() -> int:
	return maxi(0, capacity - count())

## Gửi tối đa số lượng yêu cầu vào chỗ trống và trả về số thực nhận.
## Phát [signal changed] khi có sản phẩm được nhận.
func deposit(item: ItemDefinition, amount: int) -> int:
	if item == null or amount <= 0:
		return 0
	var accepted: int = mini(amount, free_space())
	if accepted <= 0:
		return 0
	var key: String = String(item.item_id)
	if not products.has(key):
		products[key] = {"item": item, "amount": 0}
	products[key].amount += accepted
	changed.emit()
	return accepted

## Chuyển sản phẩm sang inventory, tùy chọn lọc theo mã vật phẩm.
## Trả về số đơn vị chuyển được. Sản phẩm không vừa được giữ lại và các
## signal chỉ phát sau khi cả hai phía đã được cập nhật.
func collect(inventory: InventoryComponent, item_id: StringName = &"") -> int:
	if inventory == null or _collecting:
		return 0
	_collecting = true
	var moved: int = 0
	for key: String in products.keys():
		if not item_id.is_empty() and key != String(item_id):
			continue
		var row: Dictionary = products[key]
		# Commit both inventories before any save/UI/worker callback runs.
		var accepted: int = inventory.add(row.item, int(row.amount), 0, false)
		row.amount -= accepted
		moved += accepted
		if int(row.amount) == 0:
			products.erase(key)
	if moved > 0:
		inventory.changed.emit()
		changed.emit()
	_collecting = false
	return moved

## Tạo danh sách dữ liệu lưu gồm mã vật phẩm và số lượng, sắp xếp theo mã.
func capture() -> Array:
	var result: Array = []
	var keys: Array = products.keys()
	keys.sort()
	for key: String in keys:
		result.append({"item": key, "amount": int(products[key].amount)})
	return result

## Thay nội dung bằng các bản ghi đã kiểm tra và tra resource trong [param items].
## Phát [signal changed] sau khi hoàn tất.
func restore(rows: Array, items: Dictionary) -> void:
	products.clear()
	for row: Dictionary in rows:
		products[String(row.item)] = {"item": items[row.item], "amount": int(row.amount)}
	changed.emit()
