class_name ToolUpgradeOffer
extends Resource
## Cấu hình một cấp nâng cấp công cụ và điều kiện mua tương ứng.

## Mã công cụ được nâng cấp.
@export var tool: StringName
## Cấp nhận được sau khi mua.
@export_range(2, 6) var target_level: int = 2
## Chi phí bằng xu.
@export_range(1, 1000000000) var price: int = 30000
## Số cột đất đã mua cần đạt trước khi nâng cấp.
@export_range(0, 47) var required_purchased_columns: int = 1

## Số gỗ cần thêm để mua nâng cấp.
@export_range(0, 30) var wood_cost: int = 0
