class_name ObjectiveDefinition
extends Resource
## Cấu hình mục tiêu có mã ổn định và chuỗi nguồn để bản địa hóa.

## Mã nhận diện mục tiêu.
@export var objective_id: StringName
## Chuỗi nguồn của tiêu đề.
@export var title: String
## Chuỗi nguồn mô tả mục tiêu.
@export var description: String
## Mã điều kiện được hệ thống mục tiêu theo dõi.
@export var condition: StringName
## Mức tiến độ cần đạt.
@export var required: int = 1
## Số xu thưởng.
@export var reward_coins: int = 25
## Cho biết điều kiện dựa trên trạng thái thay vì số lần xảy ra sự kiện.
@export var state_condition: bool = false
