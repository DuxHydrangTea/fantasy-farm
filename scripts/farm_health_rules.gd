extends Resource
## Các thông số cân bằng sức khỏe dùng chung cho cây trồng và vật nuôi.
## Trạng thái riêng của từng cây hoặc con vật được quản lý ở nơi khác.

## Xác suất phát sinh sâu bệnh ở cây trồng.
@export_range(0, 1) var pest_chance: float = 0.15
## Xác suất phát sinh cỏ dại.
@export_range(0, 1) var weed_chance: float = 0.15
## Hệ số năng suất khi bị sâu bệnh.
@export_range(0, 1) var pest_yield: float = 0.8
## Hệ số năng suất khi bị cỏ dại.
@export_range(0, 1) var weed_yield: float = 0.85
## Hệ số tốc độ sản xuất khi vật nuôi bị bệnh.
@export_range(0.01, 1) var sick_production_rate: float = 0.5
## Xác suất bệnh trong mỗi lần kiểm tra.
@export_range(0.001, 0.99) var disease_chance: float = 0.05
## Khoảng thời gian giữa các lần kiểm tra bệnh, tính bằng giây.
@export_range(1, 86400) var disease_check_seconds: float = 600.0
## Thời gian bảo vệ sau xử lý, tính bằng giây.
@export_range(0, 86400) var protection_seconds: float = 300.0
