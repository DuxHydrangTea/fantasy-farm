class_name FertileSoil
extends RefCounted
## Xác định ô đất màu mỡ từ tọa độ bằng bố cục xác định theo phiên bản.
##
## Bố cục phiên bản 1 đã cố định để kết quả nhất quán với dữ liệu đã lưu.
## Bố cục mới cần nhánh phiên bản riêng và phương án chuyển dữ liệu.

## Phiên bản bố cục dùng cho dữ liệu mới.
const CURRENT_VERSION: int = 1
## Phiên bản bố cục hiện áp dụng khi tính ô màu mỡ.
var layout_version: int = CURRENT_VERSION

## Kiểm tra giá trị phiên bản là số nguyên hoặc số thực bằng 1.
static func valid_version(value: Variant) -> bool:
	return (value is int or value is float) and value == 1

## Kiểm tra ô nằm trong vùng đất và thuộc tập ô màu mỡ của bố cục hiện tại.
## Phiên bản 1 băm tọa độ và chọn các giá trị có phần dư nhỏ hơn 18 trên 100.
func is_fertile(cell: Vector2i) -> bool:
	if not LandExpansionState.REGION.has_point(cell):
		return false
	match layout_version:
		1:
			var value: int = (cell.x * 73856093 ^ cell.y * 19349663 ^ 83492791) & 0x7fffffff
			value = ((value ^ (value >> 13)) * 1103515245 + 12345) & 0x7fffffff
			return value % 100 < 18
	return false

## Tính sản lượng từ [param base]. Ô màu mỡ cho ít nhất thêm một đơn vị
## và thông thường bằng 1,5 lần sản lượng cơ sở sau khi làm tròn.
func amount(cell: Vector2i, base: int) -> int:
	return maxi(base+1,roundi(base*1.5)) if is_fertile(cell) else base
