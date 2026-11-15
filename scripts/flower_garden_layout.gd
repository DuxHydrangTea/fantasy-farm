extends RefCounted
## Hình học bốn khối vườn hoa 5×4 và chuyển tọa độ lưu cũ.
## Bố cục giữ các mã ô lịch sử để tương thích dữ liệu đã lưu.

## Số cột của lưới logic gồm khoảng cách giữa các khối.
const COLUMNS: int = 14
## Số hàng của lưới logic.
const ROWS: int = 8
## Số cột trồng trong mỗi khối.
const BLOCK_COLUMNS: int = 5
## Tổng số chậu trong bốn khối.
const CAPACITY: int = BLOCK_COLUMNS * 4 * 4
## Khoảng cách ngang giữa các chậu trong khối.
const SPACING: int = 32
## Khoảng cách hàng tham chiếu.
const ROW_SPACING: int = 22
## Vị trí dọc của bốn hàng trong mỗi khối.
const ROW_POSITIONS: Array[int] = [40, 62, 83, 106]
## Số cột dùng bởi dữ liệu lưu.
const SAVE_COLUMNS: int = 18
## Số hàng dùng bởi dữ liệu lưu.
const SAVE_ROWS: int = 10
## Giới hạn số ô theo lưới dữ liệu lưu.
const SAVE_CAPACITY: int = SAVE_COLUMNS * SAVE_ROWS

## Tính vị trí hiển thị cục bộ của ô trong bốn khối.
static func position_for(cell: Vector2i) -> Vector2:
	return Vector2(32 + (cell.x % 7) * SPACING + (192 if cell.x >= 7 else 0), ROW_POSITIONS[cell.y % 4] + (128 if cell.y >= 4 else 0))

## Kiểm tra ô nằm trong vùng trồng của một khối, bỏ qua khoảng cách giữa khối.
static func contains_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLUMNS and cell.y >= 0 and cell.y < ROWS and cell.x % 7 < BLOCK_COLUMNS

## Trả hình chữ nhật đất của khối chứa ô.
static func soil_bounds_for(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(16 + (192 if cell.x >= 7 else 0), 16 + (128 if cell.y >= 4 else 0)), Vector2(160, 96))

## Chuyển tọa độ lịch sử; FlowerGarden xử lý hàng đợi cây vượt sức chứa.
static func from_legacy(cell: Vector2i) -> Vector2i:
	# Keep historical save coordinates; surplus plants are queued by FlowerGarden.
	return Vector2i(cell.x * 2 - (1 if cell.x >= 5 else 0), cell.y * 2 - (1 if cell.y >= 3 else 0))
